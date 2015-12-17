# Matlab Package Manager (mpm)

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Setup

Clone this repo and add it to your Matlab path. By default, mpm will install all Matlab packages to the directory specified by `userpath`. You can edit `config.m` to specify a custom installation directory.

You can call `mpmpaths` in your Matlab [startup script](http://www.mathworks.com/help/matlab/ref/startup.html) to automatically add all folders in the installation directory to your Matlab path. (Note that this won't add any subfolders.)

## Usage

__Install a single package__

From Matlab File Exchange:

```
>> mpm export_fig http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
```

From Github:

```
>> mpm mASD https://github.com/mobeets/mASD.git
```

If the package already exists in the installation directory you can force mpm to overwrite it using `-f`.

```
>> mpm mASD https://github.com/mobeets/mASD.git
Package "mASD" already exists at /Users/mobeets/Documents/MATLAB/mASD
>> mpm mASD https://github.com/mobeets/mASD.git -f
Installed "mASD" to /Users/mobeets/Documents/MATLAB/mASD
```

__Install multiple packages using requirements file__

```
>> mpm -r /Users/mobeets/example/requirements.txt
```

Specifying a requirements file lets you install multiple packages at once. Note that `mpm` requires the absolute path to your requirements file. `which('requirements.txt')` might help! The file should look something like this:

    export-fig http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig?download=true
    gridfitdir http://www.mathworks.com/matlabcentral/fileexchange/downloads/9937/akamai/gridfitdir.zip
    mASD https://github.com/mobeets/mASD.git
