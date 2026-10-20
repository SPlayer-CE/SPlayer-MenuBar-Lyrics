# Security Policy

## Supported versions

Security fixes are applied to the latest release. Please reproduce the issue on the newest version before reporting it.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting: open the **Security** tab of this repository and choose **Report a vulnerability**. Do not open a public issue for security problems.

Include:

- Affected version and macOS version
- Steps to reproduce
- Impact and any suggested fix
- Relevant logs or the diagnostic report (remove personal information such as track titles if needed)

## Scope

The app talks to SPlayer-Next over its local external API and to GitHub's Releases API for update checks. The optional favorite bridge exposes a minimal HTTP service on `127.0.0.1:14561`.

Reports about SPlayer-Next itself should go to the SPlayer-Next project instead.
