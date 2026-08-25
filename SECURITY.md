# Security policy

## Reporting a vulnerability

Do not open a public issue for a vulnerability in VPS Buddy.

Use [GitHub private vulnerability reporting](https://github.com/codejavu-llc/VPS_buddy/security/advisories/new) to send CodeJavu:

- the affected version or commit;
- impact and realistic attack conditions;
- reproducible steps or a minimal proof of concept;
- any suggested mitigation; and
- whether you plan to disclose the issue elsewhere.

Please avoid accessing data that is not yours, disrupting services, or testing outside this repository and infrastructure you control. We will acknowledge a complete report as soon as reasonably possible and coordinate remediation and disclosure through the private advisory.

## Scope

Security-sensitive areas include:

- archive and checksum verification;
- command or configuration injection;
- unsafe filesystem operations;
- privilege-boundary mistakes;
- secret exposure in logs or AI helpers;
- release and GitHub Actions supply-chain risks; and
- scope-control bypasses in future workflow functionality.

Reports about the behavior of third-party tools installed by VPS Buddy should normally be sent to their upstream maintainers unless VPS Buddy introduces the vulnerability.

## Supported versions

| Version | Supported |
|---|---|
| Latest 3.x release | Yes |
| `main` | Yes |
| 2.x and older | No |
