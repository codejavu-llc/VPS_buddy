# Tool catalog

The source of truth is [`manifests/tools.tsv`](../manifests/tools.tsv). `vpsbuddy tools list` shows the catalog on any installed system.

## Essential

- `nuclei` — template-driven vulnerability scanner
- `httpx` — HTTP probing and metadata
- `subfinder` — passive subdomain discovery
- `dnsx` — DNS operations
- `naabu` — port discovery
- `ffuf` — web fuzzing
- `anew` — unique-line stream processing

## Bug Hunter additions

- ProjectDiscovery: `katana`, `alterx`, `tlsx`, `mapcidr`, `asnmap`, `cdncheck`, `notify`, and `interactsh-client`
- Tomnomnom utilities: `waybackurls`, `assetfinder`, `unfurl`, `qsreplace`, and `gf`
- Web reconnaissance: `dalfox`, `gau`, `subjs`, `jsluice`, `gowitness`, `puredns`, `massdns`, `hakrawler`, and `gospider`
- Isolated Python applications: `arjun`, `dirsearch`, `dnsgen`, `sqlmap`, and `wafw00f`
- Content: SecLists, GF patterns, and refreshed DNS resolver lists

## Advanced additions

- `shuffledns` — high-volume DNS resolution workflow
- `uncover` — search-engine API discovery
- `cvemap` — CVE intelligence
- `trufflehog` — verified secret discovery
- `gitleaks` — source-code secret detection
- `trivy` — repository, container, and cloud configuration scanning
- `semgrep` — static analysis for modern application code
- PayloadsAllTheThings and fuzzDicts

Some tools need provider credentials or external services before all functionality is available. VPS Buddy does not request or store those credentials during setup.

Go and Python tools are built or installed in isolated user-owned locations. Tools that cannot be installed safely with their language package manager use official, architecture-specific GitHub release artifacts and published SHA-256 checksums.

## Version policy

The manifest intentionally follows the `latest` channel for fast-moving security tools. Every declared upstream install path is re-tested weekly in GitHub Actions, while the exact version resolved on a VPS is written to its private state and lock files. Users can deliberately update a managed tool with:

```bash
vpsbuddy tools update TOOL
```
