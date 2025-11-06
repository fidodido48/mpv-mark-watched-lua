_MARK_WATCHED.LUA_ _MPV_ _SCRIPT_

__INTRODUCTION__
----------------

Mpv's lua script for marking YT URLs watched after each URLs finished playback (at end-of-file event - EOF). Its designed for mpv/yt-dlp combo (internal mpv's ytdl_hook). Easily resume watching/streaming your playlists from the last left-off point. It has some 'smart' capabilities: 
- Doesn't mark URLs interrupted early (only on shortcut press or file EOF)
- Doesn't duplicate archive file entries (skips in that case)
- Although it does add IDs automatically, you can force manual add by pressing shortcut key (**"Ctrl+Y"** by default) if you wish so.

__REQUIREMENTS__
----------------

- mpv
- yt-dlp
- your own yt-dlp's archive_file.txt

__INSTALLATION__
----------------

1. Git clone repo 

```git clone https://github.com/fidodido48/mpv-mark-watched-lua.git $HOME/.config/mpv/scripts```

2. Make sure to put the script in the proper mpv's scripts dir 
(```$HOME/.config/mpv/scripts/mark_watched.lua```)

3. EDIT SCRIPT FILE AND ADD YOUR PROPER ARCHIVE FILE PATH/LOCATION. 
You can customize the shortcut as well, if you want. 
Default is "```Ctrl+Y```" (case-sensitive)

```
-- USER CONFIGURATION
-- SET YOUR YT-DLP ARCHIVE FILE PROPER PATH/LOCATION
local ARCHIVE_FILE = "/path/to/ytdlp_archive.txt"
-- SET YOUR PREFERRED SHORTCUT KEY(S)
local SHORTCUT_KEY = "Ctrl+Y"
-- END OF USER CONFIGURATION
```
__USAGE/TESTING__
-----------------

Run '```mpv --msg-debug=mark_watched=debug```' to check/debug/troubleshoot. 

If all is good you should see similiar output in the terminal:

```
[mark_watched] Loading lua script .config/mpv/scripts/mark_watched.lua...
[mark_watched] loading mp.defaults
[mark_watched] loading file .config/mpv/scripts/mark_watched.lua
[mark_watched] Loaded 60188 existing IDs
[mark_watched] Archive file used: .../ytdlp_archive.txt
```

1st shortcut key press/file EOF reached:
```
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60188 existing IDs
[mark_watched] Appended ID: fPPcH_dC8LE
```

2nd shortcut key press/file EOF reached: 
```
[input] No key binding found for key 'Ctrl+y'.
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
```

3rd and n-th shortcut key presses/file EOF reached:
```
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
```
-----------------------------------------------------------------------
