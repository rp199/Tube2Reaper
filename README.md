# Tube2Reaper

[![REAPER integration](https://github.com/rp199/Tube2Reaper/actions/workflows/reaper-integration.yml/badge.svg)](https://github.com/rp199/Tube2Reaper/actions/workflows/reaper-integration.yml)

Turn a YouTube video or local audio file into a ready-to-record
[REAPER](https://www.reaper.fm/) project.

Tube2Reaper searches or imports audio, optionally estimates its BPM, creates a
new project tab, adds a **Recording** track, and saves everything together.

## Quick start

### 1. Download

Choose **Code → Download ZIP** above and extract it, or run:

```sh
git clone https://github.com/rp199/Tube2Reaper.git
```

Keep the whole `Tube2Reaper` folder together. A good location is
`Scripts/Tube2Reaper` inside REAPER's resource folder, available from
**Options → Show REAPER resource path in explorer/finder**.

### 2. Add YouTube support (optional)

Local files work immediately. For YouTube on Windows, double-click:

```text
Install-Windows.cmd
```

It installs Tube2Reaper and the YouTube helpers for your Windows account. It does
not require administrator access.

On macOS with Homebrew, run:

```sh
brew install yt-dlp deno ffmpeg
```

Linux, non-Homebrew macOS, and manual Windows instructions are in
[Manual YouTube helper setup](#manual-youtube-helper-setup) below.

### 3. Add the script to REAPER

1. Open **Actions → Show action list**.
2. Select **Main**, then **New action… → Load ReaScript…**.
3. Choose `Tube2Reaper.lua`. On Windows, the installer places it in
   `%APPDATA%\REAPER\Scripts\Tube2Reaper`. On other systems, select it from the
   downloaded folder.
4. Select **Script: Tube2Reaper.lua** and choose **Run/close**.

You can also assign it a keyboard shortcut from the Action List.

## Use

1. Run Tube2Reaper from REAPER's Action List.
2. Choose **Automatic**, **Review BPM**, or **Off** for tempo detection.
3. Search by song or artist, paste a YouTube link, or choose a local audio file.
4. Choose **Import** beside a result, or **Open in browser** to check it first.
5. Record into the empty **Recording** track in the new project tab.

Your existing project tabs stay open. Tube2Reaper saves the new project
automatically.

## How it works

For YouTube, yt-dlp finds and downloads the best available audio, and FFmpeg
decodes it to WAV without adding another lossy encoding step. Tube2Reaper then:

1. Creates a new REAPER project tab.
2. Copies the audio into its own session folder.
3. Adds the audio and an empty **Recording** track.
4. Analyzes up to the first 90 seconds when tempo detection is enabled.
5. Applies a whole-number BPM and aligns the first strong note to the beat grid
   without trimming any audio.
6. Saves the project with relative media paths.

Sessions are stored in REAPER's resource folder:

```text
Tube2Reaper/sessions/<unique-session>/
  Tube2Reaper.rpp
  ImportedAudio.<extension>
  Recordings/
```

YouTube audio is saved as WAV; local audio keeps its original format. Move or
back up the whole session folder to keep the project and media together.

## Manual YouTube helper setup

The Windows installer normally handles this section for you. Manual setup is
useful for portable REAPER installations or systems where the installer cannot
be used.

YouTube support uses
[yt-dlp](https://github.com/yt-dlp/yt-dlp/releases/latest),
[Deno](https://github.com/denoland/deno/releases/latest), and
[FFmpeg](https://ffmpeg.org/download.html). Download versions matching your
operating system and processor, then place them in Tube2Reaper's `bin/` folder:

```text
macOS/Linux                 Windows
bin/yt-dlp                  bin/yt-dlp.exe
bin/deno                    bin/deno.exe
bin/ffmpeg                  bin/ffmpeg.exe
bin/ffprobe                 bin/ffprobe.exe
```

Common yt-dlp downloads are `yt-dlp_macos`, `yt-dlp.exe`, `yt-dlp_arm64.exe`,
`yt-dlp_linux`, and `yt-dlp_linux_aarch64`. Rename the downloaded file to the
name shown above.

On macOS and Linux, make manually installed files executable:

```sh
chmod +x bin/yt-dlp bin/deno bin/ffmpeg bin/ffprobe
```

Linux users can install FFmpeg through their package manager instead, such as
`sudo apt install ffmpeg`. Clipboard shortcuts on Linux require `wl-clipboard`,
`xclip`, or `xsel`; normal typing does not.

For a portable Windows installation, run PowerShell from the extracted folder and
provide that installation's REAPER resource directory:

```powershell
.\Install-Windows.ps1 -ReaperResourcePath "D:\REAPER"
```

The Windows installer downloads yt-dlp and Deno from their GitHub releases and a
Windows FFmpeg build from the BtbN FFmpeg Builds repository linked by FFmpeg's
download page.

## Troubleshooting and limitations

| Problem | What to do |
| --- | --- |
| A Lua module cannot be opened | Keep the complete `lua/` folder beside `Tube2Reaper.lua`. |
| A YouTube helper is missing | Check the filenames and their location in `bin/`, or reinstall them with Homebrew. |
| Windows setup fails | Check your internet connection, then run `Install-Windows.cmd` again. Partial downloads are not installed. |
| A download fails | Update the helpers and try another video. Some videos are unavailable or require sign-in. |
| macOS blocks a helper | Approve that executable through the normal macOS security settings. |
| Tempo analysis pauses | Return to the newly created project tab. |
| BPM sounds half or double | Use **Review BPM** or change the project tempo in REAPER. |
| An update does not appear | Close the Tube2Reaper window and run the action again. |

Tempo detection and first-note alignment work best with a clear, steady beat.
Quiet fade-ins, pickups, live drums, tempo changes, and half/double-time
interpretations can confuse them. The imported audio is time-based, so changing
the project BPM does not stretch it automatically.

Tube2Reaper does not sign in to YouTube or read browser cookies. Closing the
window does not currently stop a download already in progress. Download only
material you have permission to use.

Real REAPER project creation is automatically tested on Windows and has been
verified locally on macOS. Linux has not yet been tested.

## Update

On Windows, extract the latest version and run `Install-Windows.cmd` again.

On other systems, close Tube2Reaper, replace `Tube2Reaper.lua` and the `lua/`
folder, then run the action again. Homebrew users can update the YouTube helpers
with:

```sh
brew upgrade yt-dlp deno ffmpeg
```

## License

Tube2Reaper is available under the [MIT License](LICENSE). Third-party helper
programs are not included and use their own licenses.
