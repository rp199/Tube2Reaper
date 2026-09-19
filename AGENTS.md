# Tube2Reaper — shared contributor and agent context

Read this file and README.md before changing the project. This is the shared
context for Codex, Claude, and human contributors. Keep it aligned with the code;
put user-facing installation instructions in README.md.

## Task workflow

At the start of project work, check `tasks/` for active task files before choosing
new work. Task files begin with YAML front matter containing either
`status: active` or `status: complete`.

- Read active task files and use their unchecked items as the work queue.
- When completing an item, change its checkbox from `[ ]` to `[x]`.
- When no unchecked items remain, change the file status to `complete`.
- Skip the body of completed task files unless historical context is needed. The
  status is deliberately at the top so agents can filter files without loading
  their contents, reducing context and token use.
- If new work is added to a completed file, change its status back to `active`.

To list active files cheaply, use:

```sh
rg -l '^status: active$' tasks -g '*.md'
```

## Goal and agreed direction

The project began with guitar solo covers, but the product is instrument-neutral.
Use generic audio/session/recording wording in the UI and documentation.
The desired workflow is: search
for a song, select the correct result, download audio, estimate tempo, and create
a saved REAPER project with imported audio and an empty Recording track.

Portability and few dependencies are explicit priorities. An initial Python
companion proposal was rejected in favor of a Lua ReaScript running in REAPER.
Do not bring back Python, a companion app, a web server, or an additional UI
framework without a concrete need and discussion with the user.

Use REAPER's embedded Lua, native APIs, and gfx UI. External helpers are confined
to YouTube access/conversion: standalone yt-dlp, Deno, and FFmpeg (with ffprobe
alongside it). Standalone yt-dlp contains its own runtime; no separately installed
Python is required. Local-file use must continue working without any helpers.

## Source map

| File | Responsibility |
| --- | --- |
| Tube2Reaper.lua | Entry point, preferences, helper discovery, search/download workflow, project creation, audio sampling, save and event loop |
| lua/ui.lua | REAPER gfx drawing, tempo controls, results scrolling, duration formatting, progress |
| lua/tempo.lua | Pure Lua constant-tempo estimator using smoothed onset-envelope autocorrelation |
| lua/jobs.lua | Argument quoting, asynchronous shell/PowerShell helpers, file-based completion polling |
| lua/errors.lua | User-facing classification of expected downloader errors |
| lua/clipboard.lua | Native OS clipboard bridge for the custom gfx text field |
| lua/youtube.lua | YouTube URL recognition and canonical result URLs |
| tests/test_lua.lua | Synthetic tempo fixtures, silence, Unix command-argument escaping |
| tests/test_tempo_modes.lua | Real controller with REAPER/UI/audio boundaries mocked: automatic success/fallback, review, off |
| tests/test_search_field.lua | Text editing, selection, clipboard actions, focus and submission |
| tests/test_youtube.lua | Search terms, direct URL recognition, URL normalization |
| tests/test_errors.lua | Downloader error classification |
| bin/ | Optional per-platform helper binaries; binaries are ignored by Git |
| README.md | User installation, usage, troubleshooting, portability, verification status |
| docs/youtube-preview.md | Investigation and decision on playable result previews |

The unused Python prototype, virtual environment, uv binaries, and Python project
metadata were removed after the Lua architecture was validated. Do not add Python
project files or treat Python tooling as part of the build without revisiting the
agreed dependency constraints with the user.

## Behavior to preserve

- Tempo mode is persisted in REAPER ExtState: section `Tube2Reaper`, key
  `tempo_mode`, values `auto`, `review`, `skip`. Default/unknown values use `auto`.
- Automatic estimates and saves without a modal confirmation. An inconclusive
  estimate saves at 120 BPM with a status message.
- Review prompts for BPM. Cancelling or providing an invalid value leaves 120 BPM.
- Off does not create an audio accessor or analyze samples; it saves at 120 BPM.
- Create a new project tab; do not replace a user's current project.
- Copy imported audio into the session, use item timebase `C_BEATATTACHMODE=0`,
  and save with relative media references. Recording path is `Recordings`.
- Create an empty Recording track; do not assume an instrument, input device, or arm recording.
- Search returns up to eight results. Clicking a result starts a download.
- YouTube queries are entered in the inline UI field, submitted by Enter/Search.
  Do not reintroduce the modal GetUserInputs search dialog. Typing must not
  trigger the S/L shortcuts; those apply only outside the focused input.
- Preserve standard input behavior: mouse/keyboard selection, Cmd/Ctrl+A/C/X/V,
  and direct YouTube URL resolution. Result Open buttons use the system browser.
- Keep slow external operations asynchronous and analysis incremental.
- Analysis pauses when the new session is not the active project tab.
- Helpers are found in project bin/, project .tools/bin/, /opt/homebrew/bin,
  /usr/local/bin, /usr/bin, in that order. There is no general PATH search.

## Storage and process model

Runtime data lives under `reaper.GetResourcePath()/Tube2Reaper`:
`sessions/<unique-id>/` holds projects/media/recordings; `jobs/<unique-id>/` holds
the generated launcher, stdout, stderr, and completion status.

jobs.lua invokes REAPER ExecProcess with asynchronous mode -2. Unix uses /bin/sh;
Windows uses powershell.exe. Quote every command argument through the jobs layer;
never interpolate search strings or titles as raw shell code. No browser cookies,
credentials, or login integration are currently used.

Keep helper binaries OS/architecture-specific. Do not claim a Homebrew dynamic
binary can be copied to another Mac without its dependent libraries. Packaged
releases will need third-party notices and platform testing.

## Verification workflow

From the project root, with Lua 5.4 installed:

```sh
lua tests/test_lua.lua
lua tests/test_tempo_modes.lua
lua tests/test_search_field.lua
lua tests/test_errors.lua
lua tests/test_youtube.lua
luac -p Tube2Reaper.lua lua/*.lua
```

This development checkout also has `.tools/downloads/lua-5.4.8/src/lua` and
`luac`. That is a local convenience, not a prerequisite shipped in source.

For integration changes, verify inside REAPER with a generated click track or
other suitable test audio: separate tab, imported/Recording tracks, expected BPM,
saved project and relative media reference. For tempo changes check all three
modes, including the no-estimate fallback. UI changes need visual inspection and
interaction checks; syntax/tests alone do not validate gfx behavior.

Close and rerun the script after editing; a running instance retains loaded Lua
modules. Preserve the user's open sessions and don't change recording hardware
or unrelated REAPER settings during tests. Document test sessions left behind.

## Evidence and unfinished work

As of the current implementation:

- Tested on Apple Silicon macOS with REAPER 7.78.
- Real REAPER checks: script launch, refreshed UI appearance, local 120 BPM click
  import/detection, track creation, saving with a relative backing-media path.
- Standalone YouTube search and simulated audio-format selection passed.
- Lua tests cover tempo fixtures and the automatic/review/off controller paths.
- Full YouTube download → conversion → project flow is not yet verified.
- A real YouTube download returned an anti-bot/sign-in requirement. Helpers were
  found correctly; expected nonzero exits now show inline feedback with Details
  instead of a Lua assertion popup. Authentication remains unimplemented; don't
  read browser cookies without an explicit user choice.
- Windows and Linux branches are not yet verified on those platforms.
- Tempo is a first-90-seconds constant-tempo estimate; no downbeat alignment or
  variable tempo map. Synthetic fixtures are not evidence of real-song accuracy.
- Closing the UI does not stop a helper. The ten-minute timeout stops waiting,
  not the process. Cancellation/process cleanup and detailed download progress
  are future improvements.
- No signed package, automatic helper installer, or complete release bundle.
- Windows PowerShell output encoding/error handling and shell argument edge cases
  deserve integration tests before calling Windows supported.

Update these statements when new evidence exists. Distinguish implemented,
unit-tested, and verified in REAPER; do not report untested paths as working.

## Working conventions

Keep changes scoped to the request and avoid extra dependencies. Follow existing
Lua module boundaries; keep pure analysis logic separate from REAPER state.
Use project-relative paths or REAPER's resource APIs in product code, never the
developer's absolute checkout path. Preserve user edits and media. Update README
whenever installation, helper discovery, settings, or workflow changes.
