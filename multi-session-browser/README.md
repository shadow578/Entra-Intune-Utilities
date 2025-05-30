# Multi Session Browser

this tool allows you to run many independent ephemeral browser session side-by-side.
this is effectively equivalent to running many independing incognito sessions, or having infinitely many browsers installed.
browser session, cookies, history and any other changes made to the profile are discarded after closing the browser window.

## Usage

- install Google Chrome. any other chromium browser may also work.
- run the script with `msb.ps1 -BaseProfile`. this will open (and on the first run create) the browsers base profile. make your initial setup here (install browser extensions, set homepage, add bookmarks)
- close the browser window to commit the base profile
- from now on, call the script without any parameters (or use the .bat wrapper) to start a new ephemeral browser
