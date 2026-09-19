# Tube2Reaper

Tube2Reaper turns a YouTube video or local audio file into a ready-to-record
[REAPER](https://www.reaper.fm/) project.

It can:

- Search YouTube by song or artist, or accept a direct YouTube link.
- Import a local audio file instead of downloading one.
- Estimate the tempo automatically, let you review it, or skip tempo detection.
- Create a new REAPER project tab with the audio and an empty **Recording** track.
- Save the project and media together so the session is easy to move or back up.

Tube2Reaper is a Lua ReaScript, not a VST or audio effect. It has been tested on
REAPER 7.78 on Apple Silicon macOS. Windows and Linux support is included but has
not yet been tested on those platforms.

## Install

### 1. Download Tube2Reaper

Select **Code → Download ZIP** on this page and extract it, or clone the repository:

```sh
git clone https://github.com/rp199/Tube2Reaper.git
```

Keep the entire folder in a permanent location. A convenient place is
`Scripts/Tube2Reaper` inside REAPER's resource folder. In REAPER, choose
**Options → Show REAPER resource path in explorer/finder** to open that folder.

The main script and its `lua` folder must stay together:

```text
Tube2Reaper/
  Tube2Reaper.lua
  lua/
    clipboard.lua
    errors.lua
    jobs.lua
    tempo.lua
    ui.lua
    youtube.lua
  bin/                 # YouTube helpers go here when installed manually
```

### 2. Install YouTube support (optional)

Local audio works without additional software. YouTube search and download use
[yt-dlp](https://github.com/yt-dlp/yt-dlp/releases/latest),
[Deno](https://github.com/denoland/deno/releases/latest), and
[FFmpeg](https://ffmpeg.org/download.html).

#### macOS with Homebrew

```sh
brew install yt-dlp deno ffmpeg
yt-dlp --version
deno --version
ffmpeg -version
```

Tube2Reaper automatically checks the standard Apple Silicon and Intel Homebrew
locations. Nothing needs to be copied into `bin/`.

#### Manual installation on macOS, Windows, or Linux

Download executables that match your operating system and processor, extract any
archives, and place the files below in Tube2Reaper's `bin/` folder:

```text
macOS/Linux                 Windows
bin/yt-dlp                  bin/yt-dlp.exe
bin/deno                    bin/deno.exe
bin/ffmpeg                  bin/ffmpeg.exe
bin/ffprobe                 bin/ffprobe.exe
```

Useful yt-dlp download names are:

- macOS: `yt-dlp_macos`
- Windows: `yt-dlp.exe` or `yt-dlp_arm64.exe`
- Linux: `yt-dlp_linux` or `yt-dlp_linux_aarch64`

Rename the downloaded file to the name shown in the `bin/` layout. On macOS and
Linux, make the files executable:

```sh
chmod +x bin/yt-dlp bin/deno bin/ffmpeg bin/ffprobe
```

Linux users may instead install FFmpeg with their distribution package manager.
For example:

```sh
sudo apt install ffmpeg
```

On Linux, search-field clipboard shortcuts also require `wl-clipboard`, `xclip`,
or `xsel`. Normal typing does not require any of them.

### 3. Add Tube2Reaper to REAPER

1. Open **Actions → Show action list** in REAPER.
2. Select the **Main** section.
3. Choose **New action… → Load ReaScript…**. Some REAPER versions label this
   **ReaScript: Load**.
4. Select `Tube2Reaper.lua` from the downloaded folder.
5. Select **Script: Tube2Reaper.lua** and choose **Run/close**.

You can optionally assign a keyboard shortcut using **Add…** under “Shortcuts for
selected action.”

## Use

1. Run **Script: Tube2Reaper.lua** from REAPER's Action List.
2. Choose a tempo mode:
   - **Automatic** estimates the BPM and applies it immediately.
   - **Review BPM** estimates the BPM and lets you edit it before saving.
   - **Off** skips analysis and leaves the project at 120 BPM.
3. Enter a song, artist, or direct YouTube link and press **Enter** or select
   **Search**. To use an existing file, select **Choose local audio** instead.
4. Select a search result to download it. Select **Open** to check the video in
   your browser first.
5. Tube2Reaper creates and saves a new project tab. Your existing projects remain
   open.
6. Choose an input, add any effects you want, and arm the **Recording** track.

The search field supports normal cursor movement, text selection, and clipboard
shortcuts. When the field is not active, `S` focuses search and `L` opens the local
audio picker.

## How it works

For YouTube, Tube2Reaper asks yt-dlp for search results and downloads the best
available audio from the selected video. FFmpeg decodes it to WAV; this avoids an
additional lossy encoding step, but it cannot restore quality already removed by
YouTube.

Tube2Reaper then:

1. Creates a new project tab without closing or replacing your current project.
2. Copies the audio into a new self-contained session folder.
3. Adds the audio to one track and creates an empty **Recording** track.
4. Analyzes up to the first 90 seconds when tempo detection is enabled.
5. Applies a whole-number BPM and saves the REAPER project with relative media
   references.

The imported item is time-based, so changing the project tempo does not stretch
the audio automatically. Tempo estimation works best with a clear, steady beat;
intros, live drums, tempo changes, and half/double-time interpretations can make
the estimate less reliable.

## Saved sessions

Sessions are stored inside REAPER's resource folder:

```text
Tube2Reaper/
  sessions/<unique-session>/
    Tube2Reaper.rpp
    ImportedAudio.<extension>
    Recordings/
```

YouTube audio is saved as WAV. Local audio keeps its original format. Move or back
up the entire session folder so the project and its media stay together.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| A Lua module cannot be opened | Keep the complete `lua/` folder beside `Tube2Reaper.lua`. |
| A YouTube helper is missing | Verify the helper names and their location in `bin/`, or reinstall them with Homebrew. |
| Search works but download fails | Update yt-dlp, check FFmpeg and Deno, and try another video. Some videos are unavailable or require a signed-in session. |
| macOS blocks a helper | Approve that executable through the normal macOS security flow. Do not disable Gatekeeper globally. |
| Tempo analysis pauses | Return to the newly created Tube2Reaper project tab. |
| BPM sounds half or double the correct speed | Use **Review BPM** or edit the project tempo in REAPER. |
| Changes do not appear after updating files | Close the Tube2Reaper window and run the action again. |

Tube2Reaper does not sign in to YouTube or read browser cookies. Closing its window
does not currently stop a download already in progress. Download only material
you have permission to use.

## Update

Close Tube2Reaper, replace `Tube2Reaper.lua` and the `lua/` folder with the newer
versions, then run the action again. If using Homebrew, update the YouTube helpers
with:

```sh
brew upgrade yt-dlp deno ffmpeg
```

For manually installed helpers, replace them with current releases from their
official download pages.

## License

Tube2Reaper is available under the [MIT License](LICENSE). Third-party helper
programs are not included and use their own licenses.
