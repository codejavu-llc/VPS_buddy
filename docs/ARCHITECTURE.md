# Architecture

VPS Buddy uses a thin CLI over small Bash modules. The architecture keeps the user interface stable while allowing installation and platform logic to evolve independently.

```text
install.sh
    │ installs a versioned application directory and CLI symlink
    ▼
vpsbuddy
    ├── platform and hardware detection
    ├── configuration and private state
    ├── package/runtime provisioning
    ├── manifest-selected tool installers
    ├── content synchronization
    ├── workspace management
    └── local AI safety helpers
```

## Filesystem ownership

Default locations follow the XDG base-directory convention where appropriate:

| Data | Default |
|---|---|
| CLI | `~/.local/bin/vpsbuddy` |
| Application releases | `~/.local/share/vpsbuddy/releases/` |
| Configuration | `~/.config/vpsbuddy/config` |
| State and logs | `~/.local/state/vpsbuddy/` |
| Cache and build staging | `~/.cache/vpsbuddy/` |
| Managed binaries | `~/.local/bin/` |
| Source tools | `~/tools/` |
| Wordlists | `~/wordlists/` |
| Engagements | `~/engagements/` |

VPS Buddy only treats entries recorded in its state as managed. A command already available during normal setup is left untouched and recorded as externally managed.

## Trust boundaries

1. The release installer downloads a release archive and its SHA-256 file before installation.
2. The Go runtime comes from `go.dev` and is verified against the checksum in its official release metadata.
3. Go source dependencies are authenticated by the standard Go module checksum mechanism unless a user has overridden that environment.
4. Official tool release binaries are selected for the detected architecture and checked against the publisher's SHA-256 manifest.
5. Tool versions resolved from a mutable channel are recorded in `versions.lock` for auditability.
6. Python applications use a dedicated `pipx` home and do not modify system Python packages.
7. Downloads and builds stage outside the final binary path.
8. GitHub Actions dependencies are pinned to full commit hashes and maintained by Dependabot.

SHA-256 detects corruption or release-asset mismatch but is not publisher identity verification by itself. Future releases may add Sigstore attestations.

## Failure model

Each tool receives an independent state record. Setup continues after an individual tool failure, presents the total at the end, writes a non-zero process status, and directs the user to `vpsbuddy repair`. Mandatory platform and runtime failures stop setup immediately.

## Compatibility

`VPS_buddy.sh` delegates to `vpsbuddy setup`, preserving the familiar entry point and legacy directory flags while the main implementation moves forward.
