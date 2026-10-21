//! What each sink considers "checked enough", and how to explain what is
//! missing.

use crate::analysis::value::{Flow, check};

/// The kind of sensitive place untrusted data reaches.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SinkKind {
    /// Currency, stats, saved data, DataStore/MemoryStore (LS001).
    Economy,
    /// Numeric / vector / boolean Instance properties (LS002).
    Property,
    /// Instance-valued properties: Parent, Team, PrimaryPart... (LS002).
    InstanceProperty,
    /// Text shown to other players (LS002).
    Text,
    /// Using an Instance chosen by the client (LS003).
    InstanceUse,
    /// loadstring / require (LS004).
    Code,
    /// URL of an HTTP request (LS005).
    HttpUrl,
    /// Body or headers of an HTTP request (LS005).
    HttpBody,
}

fn trusted(flow: &Flow) -> bool {
    flow.any(check::TRUSTED)
}

/// `None` when the flow is checked enough for this sink, otherwise a
/// sentence explaining what is missing.
pub fn missing(kind: SinkKind, flow: &Flow) -> Option<String> {
    if trusted(flow) {
        return None;
    }
    match kind {
        SinkKind::Economy => {
            if flow.has(check::TYPE_BOOLEAN)
                || flow.has(check::LOWER | check::UPPER | check::NAN_SAFE)
                || (flow.has(check::TYPE_STRING) && flow.any(check::LENGTH | check::PATTERN))
            {
                return None;
            }
            if flow.has(check::BOUNDS) {
                return Some(
                    "The range check does not reject NaN: every comparison with NaN is false, so `if x <= 0 or x > max then return end` lets NaN through (and math.clamp/min/max return NaN for NaN). Add `if x ~= x then return end`."
                        .to_string(),
                );
            }
            let mut missing = Vec::new();
            if !flow.any(check::TYPE_NUMBER | check::TYPE_STRING | check::BOUNDS) {
                missing.push("a type check");
            }
            if !flow.has(check::LOWER) {
                missing.push("a lower bound");
            }
            if !flow.has(check::UPPER) {
                missing.push("an upper bound");
            }
            if !flow.has(check::NAN_SAFE) {
                missing.push("NaN rejection");
            }
            Some(format!("Missing: {}.", join_list(&missing)))
        }
        SinkKind::Property => {
            if flow.has(check::TYPE_BOOLEAN) || flow.has(check::BOUNDS) {
                return None;
            }
            let mut missing = Vec::new();
            if !flow.has(check::LOWER) {
                missing.push("a lower bound");
            }
            if !flow.has(check::UPPER) {
                missing.push("an upper bound (or a distance check against the character)");
            }
            Some(format!("Missing: {}.", join_list(&missing)))
        }
        SinkKind::InstanceProperty | SinkKind::InstanceUse => {
            if flow.any(check::OWNERSHIP) {
                return None;
            }
            if flow.any(check::TYPE_INSTANCE) {
                Some("A type check such as `IsA` only proves what kind of object it is, not that the player owns it or may use it.".to_string())
            } else {
                Some("The Instance is never checked to belong to the player or to be where it should be.".to_string())
            }
        }
        SinkKind::Text => {
            if flow.any(check::FILTERED) {
                return None;
            }
            Some(
                "The text is not filtered with TextService before other players can see it."
                    .to_string(),
            )
        }
        SinkKind::Code => Some("Only an allow-list can make code execution safe.".to_string()),
        SinkKind::HttpUrl => {
            if flow.any(check::PATTERN | check::ENCODED | check::TYPE_NUMBER | check::TYPE_BOOLEAN)
            {
                return None;
            }
            Some("The value is not allow-listed, matched against a strict pattern, converted with tonumber or encoded with HttpService:UrlEncode.".to_string())
        }
        SinkKind::HttpBody => {
            if flow.any(
                check::PATTERN
                    | check::ENCODED
                    | check::TYPE_NUMBER
                    | check::TYPE_BOOLEAN
                    | check::FILTERED,
            ) || (flow.has(check::TYPE_STRING) && flow.any(check::LENGTH))
            {
                return None;
            }
            Some(
                "The value is not type-checked and length-limited, filtered or allow-listed."
                    .to_string(),
            )
        }
    }
}

fn join_list(items: &[&str]) -> String {
    match items {
        [] => String::new(),
        [one] => (*one).to_string(),
        [init @ .., last] => format!("{} and {last}", init.join(", ")),
    }
}

/// Instance properties whose value must not come from the client (LS002).
pub fn property_sink(name: &str) -> Option<SinkKind> {
    match name {
        "Position"
        | "CFrame"
        | "Orientation"
        | "Rotation"
        | "Size"
        | "Velocity"
        | "AssemblyLinearVelocity"
        | "AssemblyAngularVelocity"
        | "Health"
        | "MaxHealth"
        | "WalkSpeed"
        | "JumpPower"
        | "JumpHeight"
        | "HipHeight"
        | "Anchored"
        | "CanCollide"
        | "Neutral"
        | "TeamColor" => Some(SinkKind::Property),
        "Parent" | "Team" | "RespawnLocation" | "PrimaryPart" => Some(SinkKind::InstanceProperty),
        "Text" => Some(SinkKind::Text),
        _ => None,
    }
}

/// Instance methods whose first argument must not come from the client (LS002).
pub fn method_sink(name: &str) -> bool {
    matches!(
        name,
        "PivotTo"
            | "SetPrimaryPartCFrame"
            | "MoveTo"
            | "TranslateBy"
            | "TakeDamage"
            | "ApplyImpulse"
            | "ApplyAngularImpulse"
            | "ScaleTo"
    )
}

/// Methods that only read an Instance (using them is not an LS003).
pub fn is_query_method(name: &str) -> bool {
    matches!(
        name,
        "IsA"
            | "IsDescendantOf"
            | "IsAncestorOf"
            | "FindFirstChild"
            | "FindFirstChildOfClass"
            | "FindFirstChildWhichIsA"
            | "FindFirstAncestor"
            | "FindFirstAncestorOfClass"
            | "FindFirstAncestorWhichIsA"
            | "FindFirstDescendant"
            | "WaitForChild"
            | "GetAttribute"
            | "GetAttributes"
            | "GetChildren"
            | "GetDescendants"
            | "GetFullName"
            | "GetPivot"
            | "GetBoundingBox"
            | "GetExtentsSize"
            | "GetMass"
            | "HasTag"
            | "GetTags"
            | "GetPropertyChangedSignal"
            | "GetAttributeChangedSignal"
            | "GetPlayerFromCharacter"
            | "GetNetworkOwner"
            | "GetRootPart"
            | "GetConnectedParts"
            | "GetTouchingParts"
            | "IsGrounded"
            | "GetState"
            | "GetPlayingAnimationTracks"
            | "GetScale"
            | "GetStyled"
    )
}

/// Methods of the string library, callable with `s:method()`.
pub fn is_string_method(name: &str) -> bool {
    matches!(
        name,
        "sub"
            | "lower"
            | "upper"
            | "match"
            | "find"
            | "gsub"
            | "gmatch"
            | "len"
            | "rep"
            | "reverse"
            | "split"
            | "byte"
            | "format"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::analysis::value::{Source, SourceKind};
    use crate::finding::{Loc, Span};
    use std::rc::Rc;

    fn flow(checks: u32) -> Flow {
        let mut f = Flow::new(Rc::new(Source {
            id: 1,
            kind: SourceKind::RemoteParameter,
            name: "x".into(),
            description: String::new(),
            loc: Loc {
                file: 0,
                span: Span::default(),
            },
            annotation: None,
        }));
        f.checks = checks;
        f
    }

    #[test]
    fn economy_requires_nan_rejection() {
        assert!(
            missing(SinkKind::Economy, &flow(check::BOUNDS))
                .unwrap()
                .contains("NaN")
        );
        assert!(missing(SinkKind::Economy, &flow(check::BOUNDS | check::NAN_SAFE)).is_none());
        assert!(missing(SinkKind::Economy, &flow(check::ALLOWLIST)).is_none());
        assert!(missing(SinkKind::Economy, &flow(check::TYPE_BOOLEAN)).is_none());
        let none = missing(SinkKind::Economy, &flow(0)).unwrap();
        assert!(none.contains("type check") && none.contains("upper bound"));
    }

    #[test]
    fn property_needs_bounds_only() {
        assert!(missing(SinkKind::Property, &flow(check::BOUNDS)).is_none());
        assert!(missing(SinkKind::Property, &flow(check::LOWER)).is_some());
    }

    #[test]
    fn ownership() {
        assert!(
            missing(SinkKind::InstanceUse, &flow(check::TYPE_INSTANCE))
                .unwrap()
                .contains("IsA")
        );
        assert!(missing(SinkKind::InstanceUse, &flow(check::OWNERSHIP)).is_none());
    }
}
