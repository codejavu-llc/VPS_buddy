# Changelog

VPS Buddy follows [Semantic Versioning](https://semver.org/). Dates use ISO 8601.

## Unreleased

## 3.0.0 - 2026-08-25

### Added

- Adaptive `essential`, `bug-hunter`, and `advanced` profiles.
- Hardware, architecture, distribution, and package-manager detection.
- Manifest-driven Go, isolated Python, source-build, and verified release-artifact installers.
- Checksum-verified, per-user Go runtime installation.
- Tool state, resolved-version locks, private logs, repair, and JSON status.
- Atomic binary installation and dry-run support.
- Wordlist and DNS resolver management.
- Authorized engagement workspaces.
- Local AI provider status, redaction, and analysis-brief helpers.
- Checksummed release installer and compatibility entry point.
- Static analysis, unit-test, cross-distribution smoke-test, upstream toolchain, and release workflows.

### Changed

- Replaced the VPS Buddy 2.x monolithic installer with a modular CLI.
- Changed the default binary location to `~/.local/bin` to minimize privileged writes.

### Removed

- Silent suppression of mandatory installation failures.
- Unverified replacement of `/usr/local/go`.
- Automatic modification of SSH, firewall, VPN, and unrelated system services.
