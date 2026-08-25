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

## Version policy

The development manifest currently uses an explicit `latest` channel for fast-moving security tools. The resolved module or application version is written to the local state and lock files. Before a stable VPS Buddy release, CI maintainers should replace mutable versions with the tested versions for that release. Users can deliberately update a managed tool with:

```bash
vpsbuddy tools update TOOL
```
