# CI integration

luau-shield is a single static binary with predictable exit codes, so it runs
in any CI system. On GitHub, the luau-shield action also publishes the
findings to code scanning, where they show up in the Security tab and on pull
requests.

- [GitHub Actions](#github-actions)
- [Other CI systems](#other-ci-systems)
- [Installing luau-shield](#installing-luau-shield)

## GitHub Actions

### Quick start

Add `.github/workflows/luau-shield.yml`:

```yaml
name: luau-shield

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  security-events: write   # upload the results to code scanning
  actions: read            # needed by the upload in private repositories

jobs:
  luau-shield:
    name: Luau security scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run luau-shield
        uses: Topogamer0/luau-shield@v0.1.0   # use the latest release tag
        with:
          path: src
          fail-on: high
```

Replace `v0.1.0` with the [latest release](https://github.com/Topogamer0/luau-shield/releases).
When `version` is empty, the action installs the luau-shield release of the
tag it is used from, so pinning the action also pins the analyzer. With a
major-version tag such as `@v1`, the newest stable `1.x` release is installed.

The action:

1. installs the prebuilt `luau-shield` binary of the release (or builds it
   from source when `build-from-source: true`);
2. runs `luau-shield check` and writes a SARIF report;
3. uploads the report to GitHub code scanning;
4. runs `luau-shield check` again with text output and fails the job if a
   finding at or above `fail-on` is reported.

Because the upload comes before the failing step, the alerts are always
visible, even when the job is red.

### Inputs

| Input | Default | Description |
| --- | --- | --- |
| `path` | `.` | File or directory to check, relative to the workspace. Several paths can be given, one per line. |
| `version` | `""` | Release to install: `1.2.0`, `v1.2.0` or `latest`. Empty: the action's own ref if it is a version tag (`v*`), otherwise the latest release. Ignored with `build-from-source: true`. |
| `build-from-source` | `"false"` | `"true"` compiles luau-shield from the action's source with `cargo build --release --locked`. The runner needs a Rust toolchain (GitHub-hosted runners have one; `dtolnay/rust-toolchain` installs a specific one). |
| `config` | `""` | Configuration file (`--config`). Empty: `luau-shield.toml` is looked up in the checked directory and its parents. See [Configuration](configuration.md). |
| `project` | `""` | Rojo project file (`--project`). Empty: the `project` key of the configuration, or `default.project.json`. |
| `min-severity` | `low` | Lowest severity that is reported: `low`, `medium`, `high`, `critical`. |
| `fail-on` | `high` | Fail the job when a reported finding has at least this severity: `low`, `medium`, `high`, `critical`, `never`. |
| `args` | `""` | Extra arguments for both runs, separated by whitespace, for example `--disable luau-shield007`. Do not pass `--format`, `--output` or `--fail-on`. |
| `sarif-file` | `luau-shield.sarif` | Where the SARIF report is written, relative to the workspace. |
| `upload-sarif` | `"true"` | Upload the report to code scanning. |
| `category` | `luau-shield` | Code scanning category. Use one value per run when a workflow checks several projects. |

The action passes `min-severity` and `fail-on` on the command line, so they
take precedence over the same keys in `luau-shield.toml`. Everything else
(`[rules]`, `ignore`, sanitizers, sinks, sources) comes from the
configuration file.

Prebuilt binaries are available for Linux x64, macOS arm64 and x64, and
Windows x64 runners. On any other runner use `build-from-source: true`.

### Outputs

| Output | Description |
| --- | --- |
| `sarif-file` | Path of the SARIF report, relative to the workspace. |

### Permissions

The workflow (or the job) that uses the action needs:

| Permission | Why |
| --- | --- |
| `contents: read` | check out the code |
| `security-events: write` | upload the SARIF report to code scanning |
| `actions: read` | required by the upload in private repositories |

The binary is downloaded with the workflow's own `GITHUB_TOKEN`; no secret is
needed.

Code scanning is available for public repositories, and for private
repositories with GitHub Code Security (formerly GitHub Advanced Security).
Without it, set `upload-sarif: false` (see
[Private repositories without code scanning](#private-repositories-without-code-scanning)).

### Results in the Security tab

Open **Security > Code scanning** in the repository. Every finding is an
alert with its rule (`luau-shield001` ... `luau-shield008`), its severity, the file and line,
and the rule's explanation. Filter with `tool:luau-shield` to see only
luau-shield alerts.

Alerts follow the code: an alert is closed automatically when a later scan
of the same branch no longer reports it. You can also dismiss an alert in the
GitHub UI (false positive, won't fix, used in tests). A dismissal only exists
on GitHub; an [inline suppression](configuration.md#suppressing-findings)
lives in the code, is reviewed with it and also applies to local runs and to
other CI systems.

### Pull requests

On pull requests, GitHub adds a code scanning check to the pull request and
annotates the changed lines where new alerts appear, directly in
**Files changed**. Alerts that already existed on the base branch are not
repeated on the pull request.

To block merging on luau-shield, make the job a required status check in the
branch protection rules (or rulesets) of the default branch. `fail-on`
decides which severities turn the check red.

### Recipes

**Several places in one repository.** Run the action once per place, with
its own project, report file and category:

```yaml
jobs:
  luau-shield:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        place: [lobby, match]
    steps:
      - uses: actions/checkout@v4
      - uses: Topogamer0/luau-shield@v0.1.0
        with:
          path: places/${{ matrix.place }}
          project: places/${{ matrix.place }}/default.project.json
          sarif-file: luau-shield-${{ matrix.place }}.sarif
          category: luau-shield-${{ matrix.place }}
```

**Pin the analyzer independently of the action.** When the action is used
from a branch or a commit, `version` chooses the release binary (`latest` by
default):

```yaml
      - uses: Topogamer0/luau-shield@main
        with:
          version: 0.1.0
```

**Use a CI-only configuration and skip a rule.**

```yaml
      - uses: Topogamer0/luau-shield@v0.1.0
        with:
          path: src
          config: luau-shield.ci.toml
          fail-on: low
          args: --disable luau-shield006
```

**Build from a fork or a branch of luau-shield.**

```yaml
      - uses: dtolnay/rust-toolchain@stable
      - uses: your-name/luau-shield@my-branch
        with:
          build-from-source: true
```

**Pull requests from forks.** Pull requests opened from forks run with a
read-only token. If the SARIF upload is rejected for them, skip the upload
for forks and keep the check:

```yaml
      - uses: Topogamer0/luau-shield@v0.1.0
        with:
          upload-sarif: ${{ github.event.pull_request.head.repo.fork != true }}
```

#### Private repositories without code scanning

Turn the upload off and keep the report as a workflow artifact instead. The
text output of the last step is in the job log.

```yaml
permissions:
  contents: read

jobs:
  luau-shield:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Topogamer0/luau-shield@v0.1.0
        with:
          path: src
          upload-sarif: false
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: luau-shield-report
          path: luau-shield.sarif
          if-no-files-found: ignore
```

## Other CI systems

Everywhere else, run the CLI directly.

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | No reported finding at or above `--fail-on`. |
| `1` | At least one reported finding at or above `--fail-on`. |
| `2` | Usage, configuration or I/O error (bad flag, invalid `luau-shield.toml`, unreadable path, ...), or files that could not be read or parsed (unless `--allow-parse-errors`). |

Treat `2` differently from `1` in scripts: it means the scan did not run
correctly, not that the code is vulnerable.

### Choosing what fails the build

`--min-severity` (`-s`) decides what is **reported**; `--fail-on` decides
which reported findings **fail** the run. The default `--fail-on low` fails on
any reported finding.

| Command | Reported | Exit code `1` when |
| --- | --- | --- |
| `luau-shield check src` | everything | any finding |
| `luau-shield check src --fail-on high` | everything | a high or critical finding |
| `luau-shield check src -s medium` | medium and above | any reported finding |
| `luau-shield check src -s high --fail-on critical` | high and critical | a critical finding |
| `luau-shield check src --fail-on never` | everything | never |
| `luau-shield check src --only luau-shield004,luau-shield008` | code execution and secrets only | any of them |

Flags override [`luau-shield.toml`](configuration.md).

### Generic shell

```sh
#!/bin/sh
set -u

# Machine-readable report for later steps, never fails on findings.
luau-shield check src --format sarif --output luau-shield.sarif --fail-on never || exit 2

# Human-readable output in the log; this run decides the result.
luau-shield check src --fail-on high
status=$?

case "$status" in
  0) echo "luau-shield: no finding at or above high" ;;
  1) echo "luau-shield: blocking findings, see above" ;;
  *) echo "luau-shield: the scan failed (usage, configuration or I/O error)" ;;
esac
exit "$status"
```

### GitLab CI

This job installs the release binary, fails the pipeline on high and critical
findings, and converts the SARIF report to a
[Code Quality](https://docs.gitlab.com/ci/testing/code_quality/) report so the
findings appear in merge requests.

```yaml
luau-shield:
  stage: test
  image: ubuntu:24.04
  variables:
    LUAU_SHIELD_VERSION: "0.1.0"
  before_script:
    - apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip jq
    - ASSET="luau-shield-${LUAU_SHIELD_VERSION}-linux-x86_64.zip"
    - BASE="https://github.com/Topogamer0/luau-shield/releases/download/v${LUAU_SHIELD_VERSION}"
    - curl -fsSLO "${BASE}/${ASSET}"
    - curl -fsSLO "${BASE}/${ASSET}.sha256"
    - sha256sum -c "${ASSET}.sha256"
    - unzip -o "${ASSET}" -d /usr/local/bin
  script:
    - luau-shield check src --format sarif --output luau-shield.sarif --fail-on never
    - >
      jq '[.runs[].results[] | {
        description: "\(.ruleId): \(.message.text)",
        check_name: .ruleId,
        fingerprint: "\(.ruleId):\(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine)",
        severity: ({"error": "critical", "warning": "major", "note": "minor"}[.level // "warning"] // "major"),
        location: {
          path: .locations[0].physicalLocation.artifactLocation.uri,
          lines: { begin: .locations[0].physicalLocation.region.startLine }
        }
      }]' luau-shield.sarif > gl-code-quality-report.json
    - luau-shield check src --fail-on high
  artifacts:
    when: always
    paths:
      - luau-shield.sarif
    reports:
      codequality: gl-code-quality-report.json
```

### Reading the results with jq

The SARIF report follows the standard SARIF 2.1.0 schema, which makes it the
most convenient input for scripts (`--format json` writes luau-shield's own
JSON report instead). Each finding is an entry of `.runs[].results[]` with
`ruleId`, `message.text` and a location.

```sh
luau-shield check src --format sarif --output luau-shield.sarif --fail-on never

# One line per finding: file:line rule message
jq -r '.runs[].results[]
  | (.locations[0].physicalLocation) as $loc
  | "\($loc.artifactLocation.uri):\($loc.region.startLine) \(.ruleId) \(.message.text)"' luau-shield.sarif

# Number of findings per rule
jq -r '[.runs[].results[].ruleId] | group_by(.) | map("\(.[0]) \(length)") | .[]' luau-shield.sarif

# Total number of findings
jq '[.runs[].results[]] | length' luau-shield.sarif

# Exit with 1 if a secret (luau-shield008) was found
jq -e '[.runs[].results[] | select(.ruleId == "luau-shield008")] | length == 0' luau-shield.sarif > /dev/null
```

## Installing luau-shield

Each [release](https://github.com/Topogamer0/luau-shield/releases) contains
one ZIP per platform with the `luau-shield` executable at the root of the
archive, plus a `.sha256` checksum file for each ZIP:

| Platform | Asset |
| --- | --- |
| Windows x64 | `luau-shield-<version>-windows-x86_64.zip` |
| macOS Apple Silicon | `luau-shield-<version>-macos-aarch64.zip` |
| macOS Intel | `luau-shield-<version>-macos-x86_64.zip` |
| Linux x64 (static, any distribution) | `luau-shield-<version>-linux-x86_64.zip` |

`<version>` is the tag without the leading `v` (`0.1.0` for `v0.1.0`). The
Windows binary needs no Visual C++ runtime and the Linux binary has no
dependency at all.

### Rokit

[Rokit](https://github.com/rojo-rbx/rokit) is the recommended toolchain
manager for Roblox projects:

```sh
rokit add Topogamer0/luau-shield
```

This installs the latest release and records it in the project's
`rokit.toml`, so everyone on the team gets the same version with
`rokit install`:

```toml
[tools]
luau-shield = "Topogamer0/luau-shield@0.1.0"
```

In CI, install Rokit, then the tools of the project. `--no-trust-check`
skips the interactive trust prompt; authenticating avoids GitHub API rate
limits on shared runners:

```sh
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
export PATH="$HOME/.rokit/bin:$PATH"
rokit authenticate github --token "$GITHUB_TOKEN"
rokit install --no-trust-check
luau-shield check src --fail-on high
```

### Aftman

```sh
aftman add Topogamer0/luau-shield
```

`aftman.toml`:

```toml
[tools]
luau-shield = "Topogamer0/luau-shield@0.1.0"
```

### Foreman

`foreman.toml` (`version` is a semver requirement; `=0.1.0` pins an exact
release):

```toml
[tools]
luau-shield = { github = "Topogamer0/luau-shield", version = "0.1.0" }
```

Then run `foreman install`.

### From source

With a Rust toolchain:

```sh
# Latest commit of the default branch
cargo install --git https://github.com/Topogamer0/luau-shield --locked

# A specific release
cargo install --git https://github.com/Topogamer0/luau-shield --tag v0.1.0 --locked
```

This is also the way to run luau-shield on platforms without a prebuilt
binary (Linux on ARM, for example).
