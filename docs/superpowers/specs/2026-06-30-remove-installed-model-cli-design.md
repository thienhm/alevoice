# Remove Installed Model CLI Design

Date: 2026-06-30
Status: Approved

## Goal

Add an interactive `AleVoiceCLI remove` command that lets alpha users remove an
installed model safely from both AleVoice config and the managed runtime/model
directory.

## Product Decision

Use an interactive-only command for this slice.

```bash
swift run AleVoiceCLI remove
```

The command lists installed engines from `Config/speech-engine.json`, marks the
currently selected engine, asks the user to choose one by number, then asks for
confirmation before deleting anything.

This is preferred over `remove <engine-id>` because the current request is for a
list-and-select workflow, and interactive selection reduces accidental deletion
while AleVoice is still source-first and local-only.

## Behavior

`remove` must:

- load the same config path resolver used by `setup` and `doctor`
- list installed engines in stable sorted order
- show id, display name, and a selected marker
- reject empty configs and malformed selections
- treat confirmation as opt-in only; `y` and `yes` remove, anything else
  cancels without mutation
- delete the removed engine entry from `Config/speech-engine.json`
- delete the managed install directory
  `~/Library/Application Support/AleVoice/engines/<engine-id>`
- leave the downloads cache untouched
- reject removal when it would leave zero installed engines
- if the selected engine is removed, select the next remaining sorted engine
  and use that engine's default mode
- if the selected engine is not removed, preserve the current selection and mode
  when still valid

## Architecture

Add a focused `InstalledModelRemover` service in `Sources/AleVoiceCLI`.
`CLIProgram` owns parsing, prompting, and output. The remover owns config
mutation and filesystem deletion.

The service should return a small result with removed id, removed display name,
new selected id, and removed directory path. This keeps CLI output testable
without mixing prompt text into the mutation logic.

## Error Handling

Failure cases should return non-zero with concise messages:

- missing or invalid config surfaces the existing config load error
- no installed engines: `no installed models found`
- invalid selection: `invalid selection`
- last remaining engine: `cannot remove the only installed model`
- filesystem delete errors bubble through the existing CLI error path

## Testing

Use TDD in the existing Swift test target:

- CLI help includes `remove`
- interactive command prints installed engines and selected marker
- cancellation leaves config and files untouched
- confirmed removal deletes config entry and engine install directory
- removing the selected engine chooses the next sorted engine and fallback mode
- trying to remove the only installed model fails

Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
as final proof.
