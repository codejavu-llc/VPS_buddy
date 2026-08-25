<div align="center">

# VPS Buddy

### Turn a fresh VPS into a complete bug-hunting machine.

Built by [CodeJavu](https://github.com/codejavu-llc) for authorized security research.

[![CI](https://github.com/codejavu-llc/VPS_buddy/actions/workflows/ci.yml/badge.svg)](https://github.com/codejavu-llc/VPS_buddy/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/codejavu-llc/VPS_buddy)](https://github.com/codejavu-llc/VPS_buddy/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-0b7285.svg)](LICENSE)

</div>

## Install

Copy, paste, and follow the single confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/codejavu-llc/VPS_buddy/main/install.sh | bash
```

That is it. VPS Buddy detects your Linux distribution, CPU architecture, memory, CPU count, and available disk space. It then chooses the right setup and installs it.

After installation, reconnect to SSH or run:

```bash
source ~/.profile
```

## Use it

You only need three commands:

```bash
vpsbuddy doctor          # Check that everything works
vpsbuddy update          # Update your tools and wordlists
vpsbuddy tools           # See the tool catalog
```

## What you get

- A hardware-aware setup for small, normal, and powerful VPS instances
- Up to 41 maintained reconnaissance, web, DNS, JavaScript, code, and cloud-security tools
- SecLists, payload collections, GF patterns, and fresh DNS resolvers
- ProjectDiscovery, Tomnomnom, modern Go tools, and isolated Python applications
- Automatic architecture selection for AMD64 and ARM64
- Verified downloads, safe updates, repair support, and private installation logs
- Optional organized workspaces for scope, evidence, screenshots, notes, and findings
- Local AI helpers that redact common secrets and never upload your data

VPS Buddy installs tools—it never starts scanning targets automatically.

## Need more control?

Most people can stop reading here. For custom profiles, paths, automation, individual tool management, JSON output, and dry runs, see the [advanced command guide](docs/CLI.md).

The [tool catalog](docs/TOOLS.md) and [architecture guide](docs/ARCHITECTURE.md) contain the technical details.

## Supported systems

- Ubuntu, Debian, and Kali
- Fedora and Arch Linux
- Alpine and openSUSE on a best-effort basis
- AMD64 and ARM64

## Safety

Only test systems you own or are explicitly authorized to assess. Respect program scope, rate limits, provider policies, and local law.

Report VPS Buddy vulnerabilities privately using [SECURITY.md](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and run `make check` before opening a pull request. VPS Buddy is MIT licensed and credits its original creator in [AUTHORS.md](AUTHORS.md).
