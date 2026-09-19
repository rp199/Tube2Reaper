# Tube2Reaper

Prepare an audio session inside REAPER: search for a song, select it, and
create a project with imported audio, a Recording track, and an estimated tempo.

Tube2Reaper is a **Lua ReaScript**, not a VST/audio effect. Local audio works with
REAPER alone. YouTube support needs three external helpers: yt-dlp, Deno, and
FFmpeg. You do **not** need to install Python, Lua, SWS, or ReaImGui to use it.

This is an early version. macOS has been tested; Windows/Linux instructions are
provided but have not yet been validated on those systems. There is no installer
or signed release bundle yet.

## 1. Install the REAPER script

1. Install [REAPER](https://www.reaper.fm/download.php). REAPER 7.78 on Apple Silicon
   macOS is the tested baseline; compatibility with older versions is not established.
2. Obtain the whole Tube2Reaper project folder, not just the main Lua file.
   Put it somewhere permanent and writable. A useful location is
   `Scripts/Tube2Reaper` inside REAPER's resource folder, which you can open with
   **Options → Show REAPER resource path in explorer/finder**.
3. Keep this structure:

   ```text
   Tube2Reaper/
     Tube2Reaper.lua
     lua/
       jobs.lua
       tempo.lua
       ui.lua
       errors.lua
     bin/                 # Only needed for YouTube
   ```

4. In REAPER, open **Actions → Show action list** and select the **Main** section.
5. Click **New action… → Load ReaScript…**. Some versions label this
   **ReaScript: Load**. Select `Tube2Reaper.lua`.
6. Select **Script: Tube2Reaper.lua** and click **Run/close**.
   Optionally assign a shortcut with **Add…** under “Shortcuts for selected action.”

You can now use **Choose local audio**. Skip to [Using Tube2Reaper](#3-using-tube2reaper)
if you do not need YouTube.

If the action is already registered against your current checkout, no second
installation is needed.

## 2. Install the YouTube helpers

Choose the instructions for your OS below. Download **executables**, not source
archives or Python packages. Extract ZIP/TAR archives before copying their contents.

Helper binaries are not tracked in the source repository. A fresh source checkout
does not include them, even if the original development machine already has them.

### macOS — with Homebrew

If Homebrew is installed and works in Terminal:

```sh
brew install yt-dlp deno ffmpeg
yt-dlp --version
deno --version
ffmpeg -version
```

The script checks both `/opt/homebrew/bin` (Apple Silicon) and
`/usr/local/bin` (usual Intel Homebrew location). No files need to be copied to
`bin/` for this method. Homebrew manages these helpers and any dependencies they
need; it is a convenience, not a Tube2Reaper requirement.

For installing Homebrew itself, follow [Homebrew's instructions](https://brew.sh/).
For an installation owned by another macOS account, resolve that setup with its
owner before installing packages; do not change the entire installation's
ownership just to run this project.

### macOS — without Homebrew

1. From [yt-dlp releases](https://github.com/yt-dlp/yt-dlp/releases/latest), download
   `yt-dlp_macos`, rename it to `yt-dlp`, and put it in Tube2Reaper's `bin/`.
   This standalone build bundles its runtime.
2. From [Deno releases](https://github.com/denoland/deno/releases/latest), choose
   the macOS archive for your processor: `aarch64-apple-darwin` for Apple Silicon,
   or `x86_64-apple-darwin` for Intel. Extract `deno` into `bin/`.
3. On the [FFmpeg downloads page](https://ffmpeg.org/download.html), follow a
   macOS binary-build link. Choose a build compatible with your processor.
   Extract `ffmpeg` and `ffprobe` into `bin/`. Prefer a standalone build;
   a binary linked to libraries on someone else's Mac is not portable.
4. In Terminal, enter the following, replacing the example directory with your
   actual Tube2Reaper folder:

   ```sh
   cd "/path/to/Tube2Reaper"
   chmod +x bin/yt-dlp bin/deno bin/ffmpeg bin/ffprobe
   ./bin/yt-dlp --version
   ./bin/deno --version
   ./bin/ffmpeg -version
   ./bin/ffprobe -version
   ```

If macOS blocks a downloaded executable, review its source and use the normal
macOS security approval flow. Do not disable Gatekeeper globally.

### Windows

1. Download the standalone executable from
   [yt-dlp releases](https://github.com/yt-dlp/yt-dlp/releases/latest):
   `yt-dlp.exe` for x64, or `yt-dlp_arm64.exe` for ARM64. Rename the latter to
   `yt-dlp.exe`.
2. Download the matching Windows archive from
   [Deno releases](https://github.com/denoland/deno/releases/latest) and extract
   `deno.exe`.
3. Follow a Windows build link on the
   [FFmpeg downloads page](https://ffmpeg.org/download.html). Extract
   `ffmpeg.exe` and `ffprobe.exe` from that build's `bin` directory.
   If using a shared build, retain its required DLLs alongside the executables.
4. Place the executables in Tube2Reaper's own `bin` folder:

   ```text
   Tube2Reaper/bin/
     yt-dlp.exe
     deno.exe
     ffmpeg.exe
     ffprobe.exe
   ```

5. In PowerShell, verify them from the Tube2Reaper directory:

   ```powershell
   Set-Location "C:\path\to\Tube2Reaper"
   .\bin\yt-dlp.exe --version
   .\bin\deno.exe --version
   .\bin\ffmpeg.exe -version
   .\bin\ffprobe.exe -version
   ```

Tube2Reaper launches helpers through `powershell.exe`. Installation only through
winget or a global PATH entry is not sufficient for the current helper discovery:
place the binaries in `bin/`. Windows behavior still needs on-device testing.

### Linux

1. Download the standalone build matching your processor/libc from
   [yt-dlp releases](https://github.com/yt-dlp/yt-dlp/releases/latest).
   Typical glibc systems use `yt-dlp_linux` (x86_64) or
   `yt-dlp_linux_aarch64` (ARM64). Rename it to `yt-dlp` and place it in `bin/`.
   **Do not choose the plain download named `yt-dlp`**: that version needs Python.
2. Download the matching Linux archive from
   [Deno releases](https://github.com/denoland/deno/releases/latest), extract
   `deno`, and place it in `bin/`. Confirm that the build supports your distribution.
3. Install FFmpeg through your distribution package manager, or place compatible
   standalone `ffmpeg` and `ffprobe` binaries in `bin/`. For Debian/Ubuntu:

   ```sh
   sudo apt install ffmpeg
   ```

4. From the Tube2Reaper directory:

   ```sh
   chmod +x bin/yt-dlp bin/deno
   ./bin/yt-dlp --version
   ./bin/deno --version
   ffmpeg -version
   ffprobe -version
   ```

If using local FFmpeg binaries, also make them executable and verify them as
`./bin/ffmpeg` and `./bin/ffprobe`. Linux behavior still needs on-device testing.

### Where the script looks

For yt-dlp, Deno, and FFmpeg, discovery checks in this order:

1. `bin/` alongside `Tube2Reaper.lua` (recommended for a portable folder).
2. `.tools/bin/` in the same folder (development fallback).
3. `/opt/homebrew/bin`, `/usr/local/bin`, then `/usr/bin`.

Windows executable names use `.exe` in the first two locations. The script does
not search arbitrary PATH entries. A stale binary in `bin/` takes precedence
over a newer Homebrew installation. Keep ffprobe beside ffmpeg for yt-dlp's
post-processing; ffprobe is not separately located by Tube2Reaper.

The three helpers and their purposes are documented upstream:
[yt-dlp dependencies](https://github.com/yt-dlp/yt-dlp#dependencies),
[Deno installation](https://docs.deno.com/runtime/getting_started/installation/),
[FFmpeg downloads](https://ffmpeg.org/download.html).

## 3. Using Tube2Reaper

1. Open the Tube2Reaper action.
2. Choose a tempo mode; the choice is remembered:
   - **Automatic** (default): estimate BPM and save without a confirmation.
   - **Review BPM**: estimate BPM, then let you edit it before saving.
   - **Off**: skip analysis and save at 120 BPM.
   Detected and manually entered tempos are rounded to a whole BPM before being
   applied to the REAPER project.
3. Type a song/artist in the inline **Search YouTube** field and press **Enter**
   or click **Search**. You can also paste a YouTube video/Shorts URL directly;
   it resolves that video rather than running a text search. Alternatively, click
   **Choose local audio**.
   The field supports arrow keys, Home/End, Backspace/Delete, and Cmd/Ctrl+A.
   Escape leaves the field; `S` focuses it and `L` opens local audio when you
   are not typing in the field. These shortcuts require the window to have focus.
4. For YouTube, click a search result. Downloading starts immediately; no further
   selection dialog appears. Use **Open** to inspect a result on YouTube without
   downloading it; Tube2Reaper confirms the OS browser command succeeded before
   showing “Opened video in your browser.” Scroll the results if necessary.
5. Tube2Reaper creates a new project tab with the imported audio and an empty
   **Recording** track, then saves it. Existing project tabs remain open.
6. Select your recording input, add your preferred effects, and arm the Recording track.

If automatic detection is inconclusive, the session saves at 120 BPM and the
status bar explains why. Cancelling the Review BPM dialog also leaves 120 BPM.
The imported item is time-based so changing project tempo does not stretch it.
Download only material you have permission to use.

## Sessions, portability, and updates

Open **Options → Show REAPER resource path in explorer/finder** to find:

```text
Tube2Reaper/
  sessions/<unique-session>/
    Tube2Reaper.rpp
    Backing.wav             # Local imports retain their original format
    Recordings/
  jobs/<unique-job>/
    stdout
    stderr
    done
```

Move the **entire session folder** to another computer, not just the RPP.
Projects save imported media references relative to the session folder.
Helper executables are OS/processor-specific: replace them when moving the
Tube2Reaper tool itself to another platform. Homebrew FFmpeg binaries may depend
on Homebrew libraries and should not simply be copied to another Mac.

To update Tube2Reaper, close its window, update `Tube2Reaper.lua` and `lua/` in
place, then run the action again. If you move the installation, load the script
from its new location in the Actions list.

For standalone yt-dlp, run `./bin/yt-dlp -U` (Windows: `.\bin\yt-dlp.exe -U`).
Replace Deno/FFmpeg from their official download sources as needed. Homebrew users
can run `brew upgrade yt-dlp deno ffmpeg`. No update happens automatically.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Cannot open a Lua module | Keep the complete `lua/` folder beside the main script. |
| YouTube helper missing | Verify the executable name and folder in “Where the script looks.” |
| FFmpeg missing | Install the executable, not the Python package named ffmpeg. |
| Permission denied / cannot execute | Check execute permissions on Unix, OS approval, architecture, and dependent libraries. Run the version commands above. |
| Search works but downloading fails | Update yt-dlp, verify Deno and FFmpeg/ffprobe, and inspect the newest job's `stderr`. Some videos require login or are unavailable; the UI does not currently handle sign-in. |
| Old behavior after editing files | Close the Tube2Reaper window and run the action again. |
| Tempo analysis pauses | Switch back to the newly created project tab. |
| BPM sounds half/double speed | Use Review BPM or edit the project tempo in REAPER. |

## Current limitations and verification

### YouTube asks to confirm you are not a bot

This is a YouTube download restriction, not a tempo or REAPER problem. Searching
may succeed while fetching the actual audio is blocked. Tube2Reaper shows an
inline explanation; **Details** opens the downloader output and log location in
REAPER's console. Updating yt-dlp may help with extraction changes, but does not
guarantee that YouTube will allow the request.

You can choose another result or import a local audio file. For authenticated
downloads, yt-dlp supports browser cookies as described in its
[official cookie instructions](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp).
Tube2Reaper does not currently expose authentication controls or read browser
cookies. Signing in in a browser alone does not authenticate this script.
An opt-in browser-session integration would be a separate feature. Never paste
cookies into an issue or commit them to this project.

### Other limitations

Tempo estimation uses onset-energy autocorrelation over up to the first 90
seconds. Intros, live drums, and half/double tempo can confuse it. Automatic
downbeat alignment and variable tempo maps are not implemented.

Closing the window does not stop an active download. After ten minutes, the UI
stops waiting, but the helper may still run. Logs remain in the resource folder.

Verified on REAPER 7.78/macOS: launching and inspecting the UI, local click-track
import, 120 BPM detection, imported/recording track creation, and saving relative
media paths. Standalone YouTube search and audio-format selection were tested.
The automatic/review/off branches have mocked controller tests. Full YouTube
download-to-project integration and Windows/Linux remain unverified.

Redistributing helper binaries requires their applicable license notices.
This repository is not yet a complete portable release bundle.

## Development

Use Lua 5.4 for command-line checks. End users use REAPER's embedded Lua.

```sh
lua tests/test_lua.lua
lua tests/test_tempo_modes.lua
lua tests/test_search_field.lua
lua tests/test_errors.lua
lua tests/test_youtube.lua
luac -p Tube2Reaper.lua lua/*.lua
```

The original development checkout has a locally compiled interpreter at
`.tools/downloads/lua-5.4.8/src/lua` and `luac` in the same directory.
It is not included in a fresh source checkout.

The unused Python prototype and its local environment were removed after the Lua
architecture was validated. Python is not a project, development, or runtime dependency.

See [AGENTS.md](AGENTS.md) for architecture and contributor context, and
[CLAUDE.md](CLAUDE.md) for the Claude entry point.
