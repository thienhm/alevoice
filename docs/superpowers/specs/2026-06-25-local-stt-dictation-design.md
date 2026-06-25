# Local STT Dictation App Design

Date: 2026-06-25
Project: `/Users/alex/Documents/alevoice`
Status: Draft for review

## Goal

Build local macOS speech-to-text app for fast cross-app dictation. Primary use case is speaking prompts into AI agent tools or filling any text input on Mac. App must run fully local on this machine, support Vietnamese and English, default to automatic language handling, and allow user to lock recognition to a single language when needed for better precision.

## User Requirements Captured

- Primary workflow: live dictation into arbitrary text fields across apps.
- Language: Vietnamese and English.
- Default language behavior: auto.
- Optional language behavior: force English or force Vietnamese.
- Trigger: hold Right Option to record.
- Output behavior: paste transcript immediately when key is released.
- UX feedback: tiny floating recording indicator while key is held.
- Accuracy/latency target: balanced, roughly 1-2 seconds after release.
- Text post-processing: support basic formatting commands such as newline and punctuation words.

## Product Shape

This should be native macOS menu bar utility, not web app. It needs direct access to microphone, global key state, focused app context, and paste simulation. Native Swift app is best fit for those platform integration needs.

MVP interaction flow:

1. User presses and holds Right Option.
2. App starts microphone capture.
3. Floating indicator appears and shows recording state.
4. User releases Right Option.
5. App stops capture and transcribes locally.
6. App applies lightweight formatting-command normalization.
7. App pastes resulting text into currently focused text input.
8. Indicator briefly shows processing/success/failure state, then disappears.

## Research Summary

### Apple Native Speech Stack

Apple now offers newer speech APIs such as `SpeechAnalyzer` and `SpeechTranscriber` on recent macOS versions. On paper this is attractive because it gives best platform integration, strong energy profile, and less third-party runtime complexity.

However, local probe on target machine showed `SpeechTranscriber.supportedLocales` on macOS 26.5.1 includes several languages such as English, Chinese, Japanese, Korean, French, German, Spanish, Italian, and Portuguese, but not Vietnamese. That makes Apple-native speech unsuitable as primary engine for this project today.

Result: Apple speech stack is rejected as main STT engine for MVP, but may still be useful later for English-only fast path if requirements change.

Sources:

- Apple docs: <https://developer.apple.com/documentation/speech/speechtranscriber>
- Apple WWDC session: <https://developer.apple.com/videos/play/wwdc2025/277/>

### Whisper Family

Whisper remains strongest baseline for fully local multilingual dictation. It supports Vietnamese and English, supports auto language detection, and allows forced language mode when needed.

Two relevant deployment forms:

- `whisper.cpp`: mature local embedding route, app-friendly, optimized for Apple Silicon with ARM/Accelerate/Metal/Core ML support.
- MLX-based Whisper implementations: potentially very fast on Apple Silicon, but packaging and distribution are more complex because they tend to rely on Python/MLX runtime.

Result: Whisper is strong candidate for engine family, with `whisper.cpp` as best starting point.

Sources:

- <https://github.com/ggml-org/whisper.cpp>
- <https://github.com/ml-explore/mlx-examples/tree/main/whisper>
- <https://huggingface.co/openai/whisper-large-v3-turbo>

### FunASR

FunASR is broader speech toolkit from ModelScope / Alibaba Tongyi Lab. It is not single model; it includes models and runtime pieces for ASR, VAD, punctuation, timestamps, diarization, and API serving.

Of special interest is `Fun-ASR-Nano`, which is presented as multilingual model with Vietnamese and English support. FunASR also provides `llama.cpp` / GGUF runtime path that is much more compatible with local macOS app shipping than its Python-first stack.

FunASR is interesting because it may perform especially well for multilingual or Asian-language usage, but it is less proven in local Mac dictation apps than Whisper. Published benchmarks are not enough to choose it outright because they may not match short prompt-style VI/EN dictation.

Result: FunASR should be benchmarked against Whisper before final engine lock.

Sources:

- <https://github.com/modelscope/FunASR>
- <https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-2512>
- <https://www.funasr.com/llama-cpp.html>

## Engine Decision

Final architecture should support pluggable engines. MVP should not hard-wire app logic directly to one recognizer.

Recommended decision:

- App architecture: define `SpeechEngine` interface.
- MVP benchmark targets:
  - `whisper.cpp` with multilingual Whisper model.
  - FunASR `Fun-ASR-Nano` via GGUF / llama.cpp runtime if integration quality is acceptable.
- MVP default engine candidate: `whisper.cpp`, unless benchmark on target machine shows FunASR materially better on both latency and recognition quality for real VI/EN prompt dictation.

This gives conservative path to first shipping app while preserving option to switch engine later without UI rewrite.

## Recommended Architecture

### App Layer

Native Swift macOS menu bar application.

Responsibilities:

- manage lifecycle and settings
- request permissions
- register and monitor global Right Option hold behavior
- show floating indicator overlay
- coordinate recording/transcription/output pipeline
- manage history/debug logging if added later

Likely frameworks:

- SwiftUI or AppKit for menu bar UI and settings
- AppKit for status bar item and overlay window
- `AVFoundation` for microphone capture
- Quartz / accessibility APIs for focused-app paste automation

### Recording Layer

Capture audio only while Right Option is held.

Responsibilities:

- start fast on key-down
- stop immediately on key-up
- collect short audio buffers
- optionally trim leading/trailing silence
- normalize or resample audio to engine-required format

Likely implementation:

- `AVAudioEngine`
- fixed sample rate conversion before inference if needed

### Engine Layer

Abstract protocol, for example:

- transcribe audio buffer
- choose language mode: auto / en / vi
- return text plus metadata such as detected language, confidence if available, and timing

Backends:

- `WhisperCppEngine`
- `FunASREngine`

This layer should hide model loading, warmup, prompt settings, and runtime-specific details.

### Post-processing Layer

Lightweight normalization after transcription.

Responsibilities:

- trim unwanted whitespace
- basic formatting-command replacement
- avoid over-aggressive rewrites
- preserve bilingual content

Initial command set:

- English: `new line`, `comma`, `period`, `question mark`, `colon`, `semicolon`, `open quote`, `close quote`
- Vietnamese: `xuong dong` or `xuống dòng`, `dấu phẩy`, `dấu chấm`, `dấu hỏi`, `dấu hai chấm`

This mapping should be configurable and intentionally small at first to avoid false positives.

### Output Layer

Insert transcript into currently focused text input.

Preferred method for MVP:

1. Save current clipboard contents if feasible.
2. Put transcript on clipboard.
3. Simulate `Cmd+V` to focused app.
4. Restore clipboard contents if safe and non-disruptive.

This is more broadly compatible than trying to directly mutate arbitrary focused UI elements across apps.

Known tradeoff: clipboard preservation must be careful because immediate restore can interfere with slow target apps. It may need delayed restoration or opt-out behavior.

### Overlay Layer

Tiny floating indicator shown while recording and processing.

States:

- idle: hidden
- recording: small red dot plus pulse/waveform
- processing: spinner or subtle animated state
- success: very brief confirmation flash
- error: short visible error state

Placement preference:

- near caret if practical and reliable
- otherwise near top-center or center of active screen

MVP should choose reliability over perfect caret tracking.

## Latency Strategy

User target is balanced speed and quality, roughly 1-2 seconds after release.

Implications:

- do not transcribe continuously during hold for MVP unless engine makes this nearly free
- capture while held, infer immediately after release
- pre-load model at app launch or first use
- keep model warm in memory
- benchmark quantized models, not full unoptimized checkpoints
- prioritize fast startup and warm inference over maximum benchmark accuracy

Candidate model strategy:

- first benchmark multilingual `large-v3-turbo` style Whisper option in quantized local runtime
- if median release-to-paste exceeds target, test smaller multilingual model
- benchmark FunASR Nano GGUF against same prompt corpus

Need real-user benchmark set made from actual short prompts in Vietnamese, English, and code-switched phrases.

## Language Handling

Default mode should be `Auto`.

Other selectable modes:

- `English`
- `Vietnamese`

Rules:

- `Auto` is default because user often switches between languages.
- Single-language lock is available for precision-sensitive sessions.
- App should show current mode in menu bar menu.
- If engine returns detected language metadata, app may expose it later for debugging/history.

Important limitation:

Mixed-language speech inside same utterance may be weaker than mostly-one-language utterances. This is known risk for both Whisper-style and other multilingual models. Real prompt testing matters more than generic benchmark claims.

## Permissions

Expected permissions:

- Microphone
- Accessibility
- Possibly Input Monitoring, depending on global key capture method chosen

App should provide clear onboarding with permission status and direct navigation guidance.

## Risks and Open Technical Questions

1. **Engine choice still unverified**
   - Need side-by-side benchmark on target M4 Mac mini.

2. **Clipboard restore behavior**
   - Must avoid disrupting user clipboard unexpectedly.

3. **Right Option capture reliability**
   - Need verify no problematic interaction with macOS keyboard layout behavior.

4. **Caret-relative overlay placement**
   - May be brittle across apps; fallback placement needed.

5. **Formatting command ambiguity**
   - Small controlled command list needed to avoid converting natural speech incorrectly.

6. **Code-switching quality**
   - Need benchmark with realistic bilingual prompts.

## Rejected or Deferred Alternatives

- Apple-native STT as primary engine: rejected because Vietnamese unavailable on this machine today.
- Cloud STT APIs: rejected because requirement is local app.
- Web app: rejected because cross-app dictation, global hotkey capture, and native permissions are core requirements.
- Python-first packaged desktop utility: deferred because native Swift packaging is cleaner for long-term tool usability.

## Recommended Next Step

Before implementation, write concrete build plan around benchmark-first workflow:

1. create benchmark harness
2. test `whisper.cpp` and FunASR candidate on real prompt samples
3. lock engine/model
4. build native shell app around chosen engine

This sequence reduces risk of building polished app on top of wrong inference backend.
