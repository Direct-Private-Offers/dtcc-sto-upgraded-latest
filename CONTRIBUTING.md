# Contributing Guidelines

## Branch Protections
- Protected branches: `main`
- Require reviews and passing CI; no force-push to protected branches.

## Pull Request Checklist
- Security impact assessed (upgradeability, secrets, external calls)
- Tests added/updated; do not remove critical tests without an approved RFC
- Docs updated (README/API/deployment as needed)
- CI green (lint, tests)

## Reviews
- At least one maintainer approval; security-sensitive changes require architect approval.

## RFC Requirement
- Architecture/security-affecting changes must have an approved RFC (see `docs/RFC_TEMPLATE.md`).

## Secrets & Keys
- No plain-text secrets in repo; use env vars/secret managers; rotate on incident.

## Incident Response
- Open an issue titled `Incident-YYYY-MM-DD` with scope, actions, rotation plan; link PRs.
