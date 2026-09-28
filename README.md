# DGX Spark on stock Ubuntu 24.04

This public package documents a tested installation of Canonical Ubuntu 24.04 ARM64 on an NVIDIA DGX Spark (GB10), followed by NVIDIA's DGX software stack, Docker GPU access, and vLLM serving Nemotron 3.5 Lightning.

- [Setup guide](SETUP.md): installer path, numbered stages, observed corrections, verification, optional Tailscale access, and handoff checks.
- [Scripts](scripts/README.txt): six shell scripts used for the NVIDIA stack, Docker GPU test, vLLM, and optional Tailscale installation. Review them before running them on another machine.
- [STIG assessment](report/ASSESSMENT.md) and [redacted HTML scan report](report/stig-report-redacted.html): a point-in-time Ubuntu 24.04 gap assessment from a lab Spark. The original XML and scan log are retained privately. This is not a compliance certification.

The HTML report removes the evaluated host name, operator name, network addresses, and MAC addresses. The rule results and remediation text are retained. Do not reuse the lab findings as a substitute for scanning the client's own build.

Scripts require access to the approved Ubuntu, NVIDIA, Docker, Hugging Face, and (if used) Tailscale repositories. They contain no credentials, installer image, model weights, or machine-specific USB formatting commands. Recheck package and model versions before deployment. The scripts do not configure STIG or FIPS controls automatically.

The STIG report contains content from [ComplianceAsCode v0.1.82](https://github.com/ComplianceAsCode/content/releases/tag/v0.1.82); see its [BSD-3-Clause license](report/ComplianceAsCode-LICENSE.txt). The Nemotron model and draft weights have a separate [OpenMDW 1.1 license](https://openmdw.ai/license/1-1/) that the deploying organization should review.
