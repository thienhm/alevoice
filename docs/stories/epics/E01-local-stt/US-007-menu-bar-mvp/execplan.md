# Exec Plan

## Goal

Ship AleVoice as a resident menu bar MVP with Auto-only dictation, overlay
feedback, formatting normalization, completed paste proof, and aligned product
documentation.

## Scope

In scope:

- menu bar resident app shape
- settings/debug window opened from the menu
- Auto-only dictation workflow
- overlay state feedback
- formatting normalization before paste
- paste validation updates
- README and product doc alignment

Out of scope:

- caret-relative overlay placement
- forced EN/VI modes
- advanced grammar correction
- distribution packaging or notarization

## Risk Classification

Risk flags:

- Public contracts
- Cross-platform
- Existing behavior
- Weak proof
- Multi-domain

Hard gates:

- Removing or weakening validation requirements is not allowed.
- If platform behavior forces a different product contract than Auto-only menu
  bar MVP, pause for confirmation.

## Work Phases

1. Discovery and story setup.
2. TDD plan and failing tests.
3. Menu bar and overlay implementation.
4. Formatting and Auto-only workflow implementation.
5. Platform verification.
6. Harness and docs update.

## Stop Conditions

Pause for human confirmation if:

- menu bar accessory behavior blocks opening the settings/debug window
- Auto-only workflow proves incompatible with the current FunASR path
- manual paste proof reveals focused-app delivery failure that changes product
  scope
- validation would need to be weakened
