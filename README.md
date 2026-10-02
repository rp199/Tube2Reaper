# Tube2Reaper

[![REAPER integration](https://github.com/rp199/Tube2Reaper/actions/workflows/reaper-integration.yml/badge.svg)](https://github.com/rp199/Tube2Reaper/actions/workflows/reaper-integration.yml)

[REAPER](https://www.reaper.fm/) script for importing audio from YouTube or a
local file into the current project, with optional BPM detection.

## Quick start

### 1. Download Tube2Reaper

Choose **Code → Download ZIP** above and extract it, or run:

```sh
git clone https://github.com/rp199/Tube2Reaper.git
```

Keep the full `Tube2Reaper` folder together.

### 2. Add YouTube support (optional)

Local files need no extra software. For YouTube on Windows, double-click:

```text
Install-Windows.cmd
```

This installs Tube2Reaper and its YouTube tools without administrator access.

On macOS with Homebrew, run:

```sh
brew install yt-dlp deno ffmpeg
```

See [Manual YouTube setup](#manual-youtube-setup) for other systems.

### 3. Add the script to REAPER

1. Open **Actions → Show action list → New action… → Load ReaScript…**.
2. Select `Tube2Reaper.lua`.
3. Run **Script: Tube2Reaper.lua**. You can also assign it a shortcut.

The Windows installer copies the script to
`%APPDATA%\REAPER\Scripts\Tube2Reaper`.

## Use

1. Open the project that should receive the audio.
2. Run Tube2Reaper from REAPER's Action List.
3. Choose **Automatic**, **Review BPM**, or **Off**.
4. Search by song or artist, paste a YouTube link, or choose a local file.
5. Choose **Import**. Use **Open in browser** to check a result first.

## Behavior

- Adds one audio track at the current edit cursor.
- **Automatic** applies the detected BPM. **Review BPM** asks first. **Off** does
  not analyze audio or change the project tempo.
- When BPM detection succeeds, aligns the first strong note to the beat grid.
- Does not create, save, or rename projects, change the recording path, or add
  any other tracks.
- Uses yt-dlp and FFmpeg to download YouTube audio as WAV.

YouTube WAV files remain in REAPER's resource folder:

```text
Tube2Reaper/downloads/<unique-download>/
  ImportedAudio.wav
```

Local files remain in their original location. Use REAPER's media management to
copy them into the project folder if needed.

## Manual YouTube setup

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

Rename downloaded files to the names shown above.

On macOS and Linux, make manually installed files executable:

```sh
chmod +x bin/yt-dlp bin/deno bin/ffmpeg bin/ffprobe
```

Linux users can install FFmpeg through their package manager. Clipboard shortcuts
require `wl-clipboard`, `xclip`, or `xsel`.

For a portable Windows installation, run PowerShell from the extracted folder and
provide that installation's REAPER resource directory:

```powershell
.\Install-Windows.ps1 -ReaperResourcePath "D:\REAPER"
```

## Troubleshooting

| Problem | What to do |
| --- | --- |
| A Lua module cannot be opened | Keep the complete `lua/` folder beside `Tube2Reaper.lua`. |
| A YouTube helper is missing | Check the filenames and their location in `bin/`, or reinstall them with Homebrew. |
| Windows setup fails | Check your internet connection, then run `Install-Windows.cmd` again. Partial downloads are not installed. |
| A download fails | Update the helpers and try another video. Some videos are unavailable or require sign-in. |
| macOS blocks a helper | Approve that executable through the normal macOS security settings. |
| Tempo analysis pauses | Return to the project containing the imported audio. |
| BPM sounds half or double | Use **Review BPM** or change the project tempo in REAPER. |
| An update does not appear | Close the Tube2Reaper window and run the action again. |

Tempo detection works best with a clear, steady beat. Fade-ins, live drums, tempo
changes, and half/double-time interpretations can produce incorrect results. The
audio is time-based, so changing BPM does not stretch it.

Tube2Reaper does not sign in to YouTube or read browser cookies. Closing its
window does not cancel a running download. Linux has not been tested.

## Update

On Windows, extract the latest version and run `Install-Windows.cmd` again.

On other systems, replace `Tube2Reaper.lua` and the `lua/` folder. Homebrew users
can update the YouTube tools with:

```sh
brew upgrade yt-dlp deno ffmpeg
```

## License

[MIT](LICENSE). Third-party tools use their own licenses.
