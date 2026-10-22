//! luau-shield006: the server calling `RemoteFunction:InvokeClient`, or assigning
//! `OnClientInvoke` in server code.

use crate::analysis::{compact, span_of, token_name};
use crate::finding::Loc;
use full_moon::ast::{
    AnonymousFunction, Assignment, Call, Expression, FunctionArgs, FunctionCall,
    FunctionDeclaration, Index, LocalFunction, Prefix, Suffix, Var, VarExpression,
};
use full_moon::visitors::Visitor;
use std::collections::HashSet;

pub struct InvokeHit {
    pub loc: Loc,
    pub message: String,
}

struct InvokeVisitor {
    file: usize,
    check_assignments: bool,
    /// Depth of calls that start a new thread (`task.spawn(...)`).
    spawn_calls: Vec<bool>,
    /// Depth of functions defined inside such calls.
    detached_functions: usize,
    function_stack: Vec<bool>,
    named_stack: Vec<bool>,
    /// Named functions that only ever run in a detached thread.
    detached_names: HashSet<String>,
    hits: Vec<InvokeHit>,
}

fn is_spawn_call(call: &FunctionCall) -> bool {
    spawn_kind(call).is_some()
}

/// `Some(index of the function argument)` for calls that start a new thread.
fn spawn_kind(call: &FunctionCall) -> Option<usize> {
    let mut path = match call.prefix() {
        Prefix::Name(token) => vec![token_name(token)],
        _ => return None,
    };
    // `task.spawn(f)`, `coroutine.wrap(f)()`: the path up to the first call.
    let mut called = false;
    for suffix in call.suffixes() {
        match suffix {
            Suffix::Index(Index::Dot { name, .. }) => path.push(token_name(name)),
            Suffix::Call(Call::AnonymousCall(_)) => {
                called = true;
                break;
            }
            _ => return None,
        }
    }
    if !called {
        return None;
    }
    let path: Vec<&str> = path.iter().map(String::as_str).collect();
    match path.as_slice() {
        ["task", "delay"] | ["delay"] => Some(1),
        ["task", "spawn" | "defer"] | ["coroutine", "wrap" | "create"] | ["spawn"] => Some(0),
        _ => None,
    }
}

/// The arguments of the first call of a call chain, and the callee path
/// before it (`M.collect` for `M.collect(p)`).
fn first_call(call: &FunctionCall) -> Option<(String, Vec<&Expression>)> {
    let mut path = match call.prefix() {
        Prefix::Name(token) => token_name(token),
        _ => return None,
    };
    for suffix in call.suffixes() {
        match suffix {
            Suffix::Index(Index::Dot { name, .. }) => {
                path.push('.');
                path.push_str(&token_name(name));
            }
            Suffix::Call(Call::AnonymousCall(args)) => {
                return match &**args {
                    FunctionArgs::Parentheses { arguments, .. } => {
                        Some((path, arguments.iter().collect()))
                    }
                    _ => None,
                };
            }
            _ => return None,
        }
    }
    None
}

/// Functions passed by name to `task.spawn` & co, and functions called directly.
#[derive(Default)]
struct SpawnedNames {
    spawned: HashSet<String>,
    called: HashSet<String>,
}

impl Visitor for SpawnedNames {
    fn visit_function_call(&mut self, call: &FunctionCall) {
        let Some((path, args)) = first_call(call) else {
            return;
        };
        match spawn_kind(call) {
            Some(index) => {
                if let Some(Expression::Var(var)) = args.get(index) {
                    self.spawned.insert(compact(var));
                }
            }
            None => {
                self.called.insert(path);
            }
        }
    }
}

impl InvokeVisitor {
    fn enter_named(&mut self, detached: bool) {
        if detached {
            self.detached_functions += 1;
        }
        self.named_stack.push(detached);
    }

    fn leave_named(&mut self) {
        if self.named_stack.pop() == Some(true) {
            self.detached_functions -= 1;
        }
    }

    fn check_suffixes<'s>(&mut self, prefix: &Prefix, suffixes: impl Iterator<Item = &'s Suffix>) {
        let mut shown = compact(prefix);
        for suffix in suffixes {
            let name = match suffix {
                Suffix::Call(Call::MethodCall(method)) => Some(method.name()),
                Suffix::Index(Index::Dot { name, .. }) => Some(name),
                _ => None,
            };
            if let Some(name) = name {
                if token_name(name) == "InvokeClient" && self.detached_functions == 0 {
                    self.hits.push(InvokeHit {
                        loc: Loc {
                            file: self.file,
                            span: span_of(name),
                        },
                        message: format!(
                            "`{shown}:InvokeClient()` makes the server wait for an answer from a client, which may never come"
                        ),
                    });
                }
            }
            shown.push_str(&compact(suffix));
        }
    }
}

impl Visitor for InvokeVisitor {
    fn visit_local_function(&mut self, function: &LocalFunction) {
        let detached = self.detached_names.contains(&token_name(function.name()));
        self.enter_named(detached);
    }

    fn visit_local_function_end(&mut self, _function: &LocalFunction) {
        self.leave_named();
    }

    fn visit_function_declaration(&mut self, function: &FunctionDeclaration) {
        let name = function
            .name()
            .names()
            .iter()
            .map(token_name)
            .collect::<Vec<_>>()
            .join(".");
        let detached =
            function.name().method_name().is_none() && self.detached_names.contains(&name);
        self.enter_named(detached);
    }

    fn visit_function_declaration_end(&mut self, _function: &FunctionDeclaration) {
        self.leave_named();
    }

    fn visit_function_call(&mut self, call: &FunctionCall) {
        self.spawn_calls.push(is_spawn_call(call));
        self.check_suffixes(call.prefix(), call.suffixes());
    }

    fn visit_function_call_end(&mut self, _call: &FunctionCall) {
        self.spawn_calls.pop();
    }

    fn visit_var_expression(&mut self, var: &VarExpression) {
        self.check_suffixes(var.prefix(), var.suffixes());
    }

    fn visit_anonymous_function(&mut self, _function: &AnonymousFunction) {
        let detached = self.spawn_calls.last().copied().unwrap_or(false);
        if detached {
            self.detached_functions += 1;
        }
        self.function_stack.push(detached);
    }

    fn visit_anonymous_function_end(&mut self, _function: &AnonymousFunction) {
        if self.function_stack.pop() == Some(true) {
            self.detached_functions -= 1;
        }
    }

    fn visit_assignment(&mut self, assignment: &Assignment) {
        if !self.check_assignments {
            return;
        }
        for var in assignment.variables() {
            if let Var::Expression(expr) = var {
                if let Some(Suffix::Index(Index::Dot { name, .. })) = expr.suffixes().last() {
                    if token_name(name) == "OnClientInvoke" {
                        self.hits.push(InvokeHit {
                            loc: Loc {
                                file: self.file,
                                span: span_of(name),
                            },
                            message: format!(
                                "`{}` is assigned in server code: OnClientInvoke only runs on clients, so the server is relying on a client callback",
                                compact(var)
                            ),
                        });
                    }
                }
            }
        }
    }
}

/// Finds `InvokeClient` calls (and server-side `OnClientInvoke`) in a file.
/// `server_script` enables the `OnClientInvoke` check.
pub fn find_invoke_client(
    file: usize,
    ast: &full_moon::ast::Ast,
    server_script: bool,
) -> Vec<InvokeHit> {
    let mut names = SpawnedNames::default();
    names.visit_ast(ast);
    let detached_names = names
        .spawned
        .into_iter()
        .filter(|name| !names.called.contains(name))
        .collect();
    let mut visitor = InvokeVisitor {
        file,
        check_assignments: server_script,
        spawn_calls: Vec::new(),
        detached_functions: 0,
        function_stack: Vec::new(),
        named_stack: Vec::new(),
        detached_names,
        hits: Vec::new(),
    };
    visitor.visit_ast(ast);
    // A method call is visited both as a call and as a var expression.
    visitor
        .hits
        .sort_by_key(|h| (h.loc.span.line, h.loc.span.column));
    visitor
        .hits
        .dedup_by_key(|h| (h.loc.span.line, h.loc.span.column));
    visitor.hits
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lines(code: &str, server: bool) -> Vec<usize> {
        let ast = full_moon::parse_fallible(code, full_moon::LuaVersion::luau()).into_ast();
        find_invoke_client(0, &ast, server)
            .into_iter()
            .map(|h| h.loc.span.line)
            .collect()
    }

    #[test]
    fn direct_calls() {
        assert_eq!(lines("local r = remote:InvokeClient(player)", true), [1]);
        assert_eq!(
            lines(
                "local ok, r = pcall(remote.InvokeClient, remote, player)",
                true
            ),
            [1]
        );
        assert_eq!(lines("remote.OnClientInvoke = function() end", true), [1]);
        assert!(lines("remote.OnClientInvoke = function() end", false).is_empty());
    }

    #[test]
    fn detached_threads() {
        assert!(
            lines(
                "task.spawn(function()\n local r = remote:InvokeClient(p)\nend)",
                true
            )
            .is_empty()
        );
        assert!(
            lines(
                "coroutine.wrap(function() remote:InvokeClient(p) end)()",
                true
            )
            .is_empty()
        );
        assert_eq!(
            lines("pcall(function()\n remote:InvokeClient(p)\nend)", true),
            [2]
        );
    }
}
