# DGX Spark Ubuntu 24.04 STIG baseline assessment

Scan date: 2026-09-28 (UTC). Target: a lab NVIDIA DGX Spark GB10 running Ubuntu 24.04 ARM64. This assessment was run **before** Tailscale and additional user accounts were installed.

## Method and scope

- Scanner: OpenSCAP `1.3.9` on the Spark, run with sudo in audit-only mode.
- Content: [ComplianceAsCode 0.1.82](https://github.com/ComplianceAsCode/content/releases/tag/v0.1.82), Ubuntu 24.04 STIG profile `xccdf_org.ssgproject.content_profile_stig`, aligned to DISA **V1R5**. The release archive SHA-512 verification passed.
- Command: `sudo oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig --results stig-results.xml --report stig-report.html ssg-ubuntu2404-ds.xml`.
- The original XML and command log remain with the lab operator. This repository contains a [redacted HTML report](stig-report-redacted.html). The scanner exited `2`, meaning it completed with failed rules.
- [DISA currently lists the Ubuntu 24.04 manual STIG at V1R6 and its SCAP benchmark at V1R5](https://www.cyber.mil/stigs/stig-announcements). This is an automated gap assessment against V1R5 content, not a full V1R6 manual review or an authorization decision.

## Results

| Result | Count |
| --- | ---: |
| Pass | 59 |
| Fail | 85 |
| Not applicable | 91 |
| Not checked | 4 |

The data stream contains 409 additional unselected rules outside this profile. The four not-checked rules concern temporary-account expiry, sudo-group restriction, required UFW services, and DoD certificates. They need manual review. The report's calculated score was `44.405865/100`; use the rule findings and applicability decisions rather than treating that score as a compliance certification.

## Findings most relevant to this build

- **NVIDIA desktop package:** Stage 02 installed `nvidia-system-station`, which brings GNOME to the Canonical Server install. Ten failed rules are GNOME `dconf` settings, including screen locking, smart-card removal, login banner, and autorun behavior. These are the clearest findings attributable to the installed software stack. Other smart-card and desktop controls also need an applicability decision with the client.
- **FIPS:** `is_fips_mode_enabled` failed. The Spark was installed as stock Ubuntu plus NVIDIA's kernel and driver; no Ubuntu Pro subscription or FIPS stream is attached. Check the client's FIPS requirement and Canonical/NVIDIA support for this exact ARM64 kernel and driver combination before attempting remediation.
- **Host hardening:** AIDE, audit tooling, password/PAM policy, SSH settings, firewall, time service, bootloader password, and log permissions account for many failures. There was no scan of the bare Ubuntu installation, so these cannot all be attributed to the NVIDIA installation.
- **Container and model scope:** This Ubuntu OS profile did not identify a Docker-, NVIDIA-, or vLLM-specific failed rule. Separate container runtime, application, model/data handling, and network reviews are still needed.

No STIG remediation was applied. Automatic profile fixes can alter SSH, PAM, desktop, kernel, and network behavior and require testing with this GPU/container stack. After approved configuration changes, rerun the scan and complete the manual V1R6 review, recording findings and documented exceptions.
