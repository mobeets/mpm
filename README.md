# Matlab Package Manager

A simple Matlab package manager (inspired by [pip](https://github.com/pypa/pip)) for downloading packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Usage

__Setup__

`alias mpm='python main.py'`

__Install a single file__

`mpm -n export_fig -e https://codeload.github.com/altmany/export_fig/legacy.zip/master`

`mpm -n mASD -e https://github.com/mobeets/mASD.git`

__Install from list of requirements in file__

`mpm -r requirements.txt`

The requirements file should look something like this:

    export-fig -e http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig?download=true
    gridfitdir -e http://www.mathworks.com/matlabcentral/fileexchange/downloads/9937/akamai/gridfitdir.zip
    mASD -e https://github.com/mobeets/mASD.git

## Coming soon

__Install to temporary folder__

__Matlab home path as variable__
