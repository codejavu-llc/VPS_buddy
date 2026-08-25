# Contributing to VPS Buddy

Thank you for helping improve VPS Buddy. Changes should preserve its core contract: the simple path stays simple, advanced behavior is explicit, and failures are reported honestly.

## Before opening a change

1. Search existing issues and pull requests.
2. For large features or new profiles, open a proposal before implementation.
3. Never add a tool solely because it is popular. Document its maintained upstream, purpose, supported architecture, installation method, and verification command.
4. Do not add automatic scanning or exploitation to setup commands.

## Local checks

```bash
make check
```

The test suite must not install packages, compile tools, contact targets, or require root. Integration installation tests belong in disposable CI containers.

## Pull requests

- Keep changes focused and update documentation.
- Add tests for parsing, platform behavior, state transitions, or safety checks.
- Explain security-relevant decisions and destructive filesystem behavior.
- Preserve compatibility through `VPS_buddy.sh` when practical.
- Update `CHANGELOG.md` under `Unreleased`.
- Confirm that all testing is limited to systems you own or are authorized to assess.

## Tool manifest

Entries in `manifests/tools.tsv` use seven pipe-separated fields:

```text
name|description|profiles|installer|source|version|estimated MB
```

Descriptions must not contain the pipe character. Profiles are comma-separated. The manifest is executable supply-chain configuration and receives the same review care as shell code.

## Style

- Bash code targets Bash 4.4 or newer.
- Use `printf` for predictable output.
- Quote expansions unless intentional splitting is documented.
- Use the shared `run` wrapper for commands that dry-run mode must intercept.
- Do not hide required failures with unconditional `|| true`.
- Prefer temporary files and atomic moves for managed artifacts.
