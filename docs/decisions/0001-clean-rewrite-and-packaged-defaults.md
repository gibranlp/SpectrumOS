# ADR 0001: Clean rewrite and packaged defaults

- Status: accepted
- Date: 2026-08-30

## Context

Legacy SpectrumOS mixes installation, dotfile deployment, mutable system state, generated themes, hardware decisions, and application choices in large shell scripts. Reusing that structure would reproduce its coupling and safety problems.

## Decision

SpectrumOS2 is a separate repository and product. Legacy code is reference-only. Distribution-owned defaults will be delivered by Arch packages into `/usr/share/spectrumos` and `/etc/spectrumos`; user material and generated state remain separate. Bootstrap will orchestrate packages and migrations rather than becoming the product itself.

## Consequences

Migration is slower than copying files, but ownership, upgrades, rollback, and reproducibility become testable. Legacy components require individual review and often a rewrite.

