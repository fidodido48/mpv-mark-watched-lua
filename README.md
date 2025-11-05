MARK_WATCHED.LUA MPV SCRIPT

INTRODUCTION

Mpv's lua script for marking YT URLs watched after finished playback (at end-of-file event - EOF). It has some 'smart' capabilities: 
1. Doesn't mark files which have been interrupted early, 
2. Doesn't duplicate archive file entries (skips adding ID in that case)
3. Although it add IDs automatically, you can force manual add by pressing "Ctrl+Y" if they wish so (still skipped for duplicates tho).

INSTALLATION

1. Git clone repo
2. Put the script in the proper mpv's scripts dir (```$HOME.config/mpv/scripts/mark_watched.lua```)
3. [REQUIRED!] EDIT SCRIPT FILE AND ADD YOUR PROPER ARCHIVE FILE PATH/LOCATION.
3.1 [OPTIONAL] You can customize the shortcut as well, if you want. Default is "```Ctrl+Y```" (case-sensitive!)
4. Run '```mpv --msg-debug=mark_watched=debug```' to check/debug/troubleshoot. 
If all is good you should see similiar output in the terminal:

```
[mark_watched] Loading lua script .config/mpv/scripts/mark_watched.lua...
[mark_watched] loading mp.defaults
[mark_watched] loading file .config/mpv/scripts/mark_watched.lua
[mark_watched] Loaded 60188 existing IDs
[mark_watched] Archive file used: .../ytdlp_archive.txt
[...]
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60188 existing IDs
[mark_watched] Appended id: fPPcH_dC8LE
[input] No key binding found for key 'Ctrl+y'.
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
[mark_watched] YT ID (from path): fPPcH_dC8LE
[mark_watched] Loaded 60189 existing IDs
[mark_watched] ID already present (skipping): fPPcH_dC8LE
```
