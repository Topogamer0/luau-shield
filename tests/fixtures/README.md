# Test corpus

Every rule has a directory with two sub-directories:

```
tests/fixtures/luau-shield001/
├── vulnerable/   # every entry MUST produce the findings marked in it
└── safe/         # every entry MUST produce no finding at all
```

An entry is either a single `.luau` file or a directory containing a small
Rojo project (`default.project.json` + sources) when the case needs several
files (`require`, client/server split, replicated modules).

## Expectation markers

A finding is expected on a line when that line ends with an `expect` comment:

```lua
coins.Value += amount -- expect: luau-shield001
part:Destroy()        -- expect: luau-shield003, luau-shield002
```

The corpus test (`cargo test --test corpus`) runs luau-shield on each entry and
compares the set of `(file, line, rule)` findings with the set of markers:

- a finding without a marker is a **false positive**;
- a marker without a finding is a **false negative**.

`safe/` entries must not contain any marker. Entries in `vulnerable/` must
contain at least one marker for the rule of the directory, and must also mark
any other finding they legitimately produce (for example a handler that writes
to a DataStore without a rate limit is also a `luau-shield007`).

Where findings are reported:

| Rule | Line of the finding |
| --- | --- |
| luau-shield001, luau-shield002, luau-shield005 | the sink: the assignment target or the method call |
| luau-shield003 | the first statement that uses the unverified Instance (one finding per untrusted parameter per handler) |
| luau-shield004 | the `loadstring` / `require` / dynamic lookup call |
| luau-shield006 | the `:InvokeClient(` call or the `OnClientInvoke =` assignment |
| luau-shield007 | the line containing `OnServerEvent` / `OnServerInvoke` of the handler |
| luau-shield008 | the line of the string literal |

## Known limitations

`tests/fixtures/limitations/` contains cases that luau-shield is known to get
wrong (dynamic code, aliasing, ...). Their markers describe the **ideal**
result; the corpus test reports them separately and does not fail on them, so
the documentation of the limits stays honest. If the analyzer improves and a
limitation case starts passing, move it into the rule directory.
