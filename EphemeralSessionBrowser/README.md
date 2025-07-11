# Ephemeral Session Browser

this tool allows you to run many independent ephemeral browser session side-by-side.
this is effectively equivalent to running many independing incognito sessions, or having infinitely many browsers installed.
browser session, cookies, history and any other changes made to the profile are discarded after closing the browser window.

> [!NOTE]
> Ephemeral Session Browser is the successor to the multi-session-browser script in this repository.

## Usage

- install Google Chrome. if chrome is not installed, the script will attempt to install it for you.
- run the script by double-clicking the `EphemeralSessionBrowser.bat` file
  * this will install the script and run it for the first time
  * on the initial run, setup the browser as you like (install extensions, set homepage, add bookmarks)
  * to update, simply re-run the install script  
- for subsequent runs, use the shortcut created on the desktop

## Uninstall

to uninstall, remove the following files / directories:
- %USERPROFILE%\Desktop\EphemeralSessionBrowser.lnk
- %USERPROFILE%\Microsoft\Windows\Start Menu\Programs\Ephemeral Session Browser.lnk
- %LOCALAPPDATA%\shadow578\EphemeralSessionBrowser\

 