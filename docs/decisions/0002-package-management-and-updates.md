# ADR 0002: Package management and update integrity

- Status: accepted
- Date: 2026-08-30

## Decision

Pacman installs and upgrades official repository packages. Paru is the sole supported AUR helper and is used only for AUR packages. SpectrumOS2 never performs a partial Arch upgrade. Future stable/testing/edge channels will publish coherent, signed repository states and run preflight checks, snapshots, transactions, migrations, and health checks.

## Rationale

This preserves Arch's package model, limits AUR trust exposure, and provides a path to controlled releases without pretending individual package pinning is a safe stability mechanism.

