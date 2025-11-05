MPV MARK_WATCHED.LUA

INTRODUCTION
Mpv's lua script for marking YT URLs watched after finished playback (at end-of-file event - EOF). It has some 'smart' capabilities: 
1. Doesn't mark files which have been interrupted early, 
2. Doesn't duplicate archive file entries (skips adding ID in that case)
3. Although it add IDs automatically, you can force manual add by pressing "Ctrl+Y" if they wish so (still skipped for duplicates tho).

INSTALLATION
1. Git clone repo
2. Put the script in the proper mpv's scripts dir ($HOME.config/mpv/scripts/mark_watched.lua)
3. *** _EDIT SCRIPT FILE AND ADD YOUR PROPER ARCHIVE FILE PATH/LOCATION_ (VERY IMPORTANT - WIHTOUT THIS IT WON'T WORK!) ***
3.1 [OPTIONAL] You can customize the shortcut if you want. Default is "Ctrl+Y" (case-sensitive!)
4. Run 'mpv --msg-debug=mark_watched=debug' to check/debug/troubleshoot
