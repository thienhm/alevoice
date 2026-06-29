# Exec Plan

## Goal

Add a source-first setup CLI that downloads and installs the pinned FunASR
SenseVoice runtime/model, writes AleVoice config, validates the install with a
doctor path, and keeps the current app and CLI transcription flow working.

## Scope

In scope:

- Manifest-driven setup data for `funasr-sensevoice`.
- `AleVoiceCLI setup funasr-sensevoice`.
- `AleVoiceCLI doctor`.
- `AleVoiceCLI transcribe`.
- `AleVoiceCLI run`.
- New config shape with legacy config read compatibility.
- README and alpha setup docs for the one-command flow.

Out of scope:

- Notarized app distribution.
- Automatic engine upgrades.
- `whispercpp` or `funasr-nano` runtime support.
- GUI installer behavior.
- Hidden background downloads during app launch.

## Risk Classification

Risk flags:

- External systems.
- Public contracts.
- Existing behavior.
- Weak proof.

Hard gates:

- External provider behavior.

## Work Phases

1. Discovery.
2. Design.
3. Validation planning.
4. Implementation.
5. Verification.
6. Harness update.

## Stop Conditions

Pause for human confirmation if:

- The provider artifact layout no longer matches the pinned manifest data.
- The config migration needs to drop or rewrite user-managed engine entries.
- Validation requirements need to be weakened.
- Another engine must be included in this first slice.
