# Ephemeral Session Browser

this tool allows you to run many independent ephemeral browser session side-by-side.
this is effectively equivalent to running many independing incognito sessions, or having infinitely many browsers installed.
browser session, cookies, history and any other changes made to the profile are discarded after closing the browser window.

> [!NOTE]
> Ephemeral Session Browser is the successor to the multi-session-browser script in this repository.

## Usage

- install Google Chrome. if chrome is not installed, the script will attempt to install it for you.
- run the script by double-clicking the `EphemeralSessionBrowser.bat` file to start the install wizard.
  - to update, simply download and run the latest version of the script.
- if you wish to uninstall or modify the installation, you can start the install wizard again by via the windows programs and features menu.
- to quickly modify the base profile, hold down the `Shift` key while starting.

## About the Loader

> or "why is this a batch file, when it contains powershell code?!"

while powershell scripts are great, and really powerful, they are kind of a pain to run since you can't just double-click them.
this is why this script is distributed as a batch file, which contains the powershell code and, prepended to it, a loader written in batch (well, technically. it's a batch script running a powershell command).
so, when you double-click the batch file, this happens:

1. a new powershell session is started with a pre-defined command
2. this command reads the batch file, strips away the loader part (everything before the `# END OF LOADER #` line), and saves it to a temporary file
3. that temporary file is then executed in the same powershell session
4. the temporary file, containing the actual powershell code, then does its thing (showing you the install wizard, etc.)
5. finally, the temporary file is deleted and the batch script skips to EOF to exit gracefully

and all of that because microsoft decided that you can't just double-click a powershell script to run it...
