# Known limitations

Each entry is a case luau-shield gets wrong today. The `-- expect:` markers
describe the **ideal** result, so these files are counted as false positives
or false negatives by `cargo test --test corpus` (they never fail the test).
They document, with real code, the limits listed in the README.

| Entry | Mistake | Why |
| --- | --- | --- |
| `bindable-relay.server.luau` | false negative | data relayed through a `BindableEvent` is not followed |
| `table-alias.server.luau` | false negative | tables are tracked by value: a write through an alias is not seen by the other name |
| `value-object-relay.server.luau` | false negative | data stored in an `IntValue`/attribute and read back later is not followed |
| `alias-validation.server.luau` | false positive | a check on a copy of a variable does not protect the original variable |
| `pcall-validation.server.luau` | false positive | `assert`s inside a function run with `pcall` are not used as guards |
| `dynamic-module/` | false negative | a module chosen at runtime (`require(Shops[mode])`) cannot be resolved |
| `pattern-checked-inventory-key.server.luau` | false negative | an anchored pattern is accepted for keys, but it only checks the format, not that the item exists |
| `check-in-earlier-loop.server.luau` | false positive | facts about the elements checked in one loop do not carry over to a second loop over the same table |
| `upvalue-validator.server.luau` | false positive | a validator that checks captured variables instead of its parameters does not protect them |
