# YouTube preview investigation

## Finding

An embedded, directly playable YouTube video is not practical in the current
dependency-free REAPER Lua UI.

REAPER's built-in `gfx` API provides drawing, images, text, mouse, and keyboard
input. It does not expose a browser/WebView or an HTML/JavaScript host. YouTube's
player is a web application and cannot be rendered by `gfx`. The official
ReaScript API provides local-file audio sources, but no YouTube player or web
view. Embedding the real player would therefore require a native REAPER extension
or a separate browser UI, conflicting with the project's portability and minimal
dependency goals.

## Options considered

| Option | Result |
| --- | --- |
| Embed YouTube in `gfx` | Not supported; there is no browser/WebView API. |
| Open the result on YouTube | Implemented with an **Open** button using the OS browser. No media download required. |
| Download a short audio preview | Technically possible with yt-dlp/FFmpeg, then local REAPER playback, but it still downloads media, adds caching/cancellation complexity, and can trigger the same YouTube restrictions as full downloads. |
| Native extension or separate web UI | Could host a WebView, but adds compiled platform-specific code or another application and is outside the agreed architecture. |

## Decision

Use the external-browser **Open** button for visual/video preview. Keep an audio
snippet preview as a possible future opt-in feature if browser navigation proves
too disruptive. Do not add a WebView dependency for the current version.

References: [REAPER ReaScript API](https://www.reaper.fm/sdk/reascript/reascripthelp.html)
and its documented `gfx` drawing/input functions.
