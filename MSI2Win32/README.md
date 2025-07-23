# MSI 2 Win32

a simple utility to convert MSI installers to intunewin packages, so that they can be installed using Win32 (via Intune Management Extension) instead of Line-of-business install method.

## Installation

place these files somewhere on your disk. 
download the IntuineWinAppUtil and place it alongside (where the .dummy file is located).

## Usage

simply drag the msi file onto `msi2win32.bat` and the intunewin package is automatically created.
the output will be placed alongside the .msi file.

bundling cabinet files (.cab) is not yet supported by this tool. 
you'll have to use IntuneWinAppUtil directly for that.
