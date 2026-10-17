# ADR 0003: Configuration layers

- Status: accepted
- Date: 2026-08-30

## Decision

Configuration has five distinct layers:

1. immutable distribution defaults in `/usr/share/spectrumos`;
2. administrator policy in `/etc/spectrumos`;
3. user-owned overrides under XDG configuration paths;
4. generated palettes/config fragments under XDG cache/state paths;
5. optional private work configuration under `~/.config/spectrumos-personal`.

Applications should include or consume these layers where supported. Where an application cannot include layered files, a focused renderer produces a user-owned effective file without silently replacing unrelated user content.

## Consequences

Packages do not own personal dotfiles. Generated output is disposable. Private work data never becomes a distro input or repository artifact.

