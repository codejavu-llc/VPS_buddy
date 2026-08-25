# Advanced command guide

The default installation needs no configuration:

```bash
vpsbuddy setup
```

VPS Buddy automatically recommends `essential`, `bug-hunter`, or `advanced` according to the machine's CPU, memory, and free disk space.

## Setup controls

```text
-p, --profile NAME       essential, bug-hunter, advanced, or auto
-y, --yes                Confirm the displayed plan
    --dry-run            Show changes without making them
    --no-wordlists       Skip wordlists and resolver data
    --wordlists          Re-enable wordlists and resolver data
    --no-system-packages Do not invoke the OS package manager
-t, --tools-dir DIR      Select the source-tool directory
-w, --wordlists-dir DIR  Select the content directory
-b, --bin-dir DIR        Select the managed binary directory
    --non-interactive    Never prompt; requires `--yes`
```

Example unattended setup:

```bash
./install.sh -- --profile bug-hunter --non-interactive --yes
```

Example read-only preview:

```bash
vpsbuddy setup --profile advanced --dry-run --yes
```

## Tool management

```bash
vpsbuddy tools list
vpsbuddy tools list --installed
vpsbuddy tools list --profile essential
vpsbuddy tools list --details
vpsbuddy tools install nuclei
vpsbuddy tools update nuclei
vpsbuddy tools remove nuclei
vpsbuddy repair
```

VPS Buddy does not overwrite an externally managed executable during normal setup. Failed updates retain the last working managed binary.

## Updates and status

```bash
vpsbuddy update
vpsbuddy update nuclei
vpsbuddy update --dry-run
vpsbuddy self-update
vpsbuddy status
vpsbuddy status --json
vpsbuddy doctor --json
vpsbuddy config
```

## Workspaces

The short command:

```bash
vpsbuddy new example
```

is equivalent to:

```bash
vpsbuddy workspace new example
```

It creates scope, raw output, normalized data, screenshots, findings, notes, and log directories. The workspace starts with `authorization_confirmed: false` and does not execute a scan.

## Local AI helpers

```bash
vpsbuddy ai status
vpsbuddy ai redact response.txt response.redacted.txt
vpsbuddy ai brief example > analysis-brief.md
```

These commands do not call a model provider. Redaction covers common authorization headers, cookies, API keys, passwords, secrets, and tokens, but its output must still be reviewed before sharing.

## Default locations

| Data | Location |
|---|---|
| CLI and managed binaries | `~/.local/bin/` |
| Configuration | `~/.config/vpsbuddy/` |
| Private state and logs | `~/.local/state/vpsbuddy/` |
| Runtime and application data | `~/.local/share/vpsbuddy/` |
| Source checkouts | `~/tools/` |
| Wordlists | `~/wordlists/` |
| Workspaces | `~/engagements/` |
