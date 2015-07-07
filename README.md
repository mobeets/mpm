# Matlab Package Manager

A simple Matlab package manager for downloading packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Usage

__Setup__

`alias mpm='python main.py'`

__Install a single file__

`mpm -n export_fig -u https://codeload.github.com/altmany/export_fig/legacy.zip/master`

`mpm -n mASD -u https://github.com/mobeets/mASD.git`

## Coming soon

__Install from `requirements.txt`__

`mpm -f requirements.txt`

__Install to temporary folder__

__Matlab home path as variable__
