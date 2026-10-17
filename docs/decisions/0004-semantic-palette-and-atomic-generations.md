# ADR 0004: Semantic palette and atomic generations

- Status: accepted
- Date: 2026-08-30

## Context

Legacy SpectrumOS coupled applications to pywal's numbered colors and cache layout. Its global apply script copied full configurations, restarted processes, and could leave consumers inconsistent when one step failed.

## Decision

SpectrumOS2 owns a versioned semantic palette schema. Extractors produce that schema; independent renderers generate application-specific files. A complete generation is staged and activated through an atomic `current` symlink replacement. Static packaged palettes are always available as fallbacks.

The initial roles are background, two surfaces, foreground, muted, two accents, success, warning, and error. Schema v1 validates color syntax and baseline foreground/muted contrast against the background.

## Consequences

Applications no longer depend on a specific extractor. Failed rendering cannot expose a partially written generation, and the previous generation remains recoverable. Application reloads, extraction, retention, and system-session exports remain separate responsibilities.
