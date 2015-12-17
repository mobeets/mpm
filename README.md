# Matlab Package Manager (mpm)

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Setup

Clone this repo and add it to your Matlab path (using `addpath`).

## Usage

__Install a single package__

From Matlab File Exchange:

```
>> mpm export_fig http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
```

From Github:

```
>> mpm matlab2tikz https://github.com/matlab2tikz/matlab2tikz.git
```

Note that for Github repos you must add the '.git' to the url.

If the package already exists in the installation directory you can force mpm to overwrite it using `-f`.

```
>> mpm matlab2tikz https://github.com/matlab2tikz/matlab2tikz.git
Package "matlab2tikz" already exists at /Users/mobeets/Documents/MATLAB/matlab2tikz
>> mpm matlab2tikz https://github.com/matlab2tikz/matlab2tikz.git -f
Installed "matlab2tikz" to /Users/mobeets/Documents/MATLAB/matlab2tikz
```

__Install multiple packages using requirements file__

```
>> mpm -r /Users/mobeets/example/requirements.txt
```

Specifying a requirements file lets you install multiple packages at once. Note that `mpm` requires the absolute path to your requirements file. `which('requirements.txt')` might help! The file should look something like this:

    export-fig http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig?download=true
    matlab2tikz https://github.com/matlab2tikz/matlab2tikz.git

## What it does

By default, mpm will install all Matlab packages to the directory specified by `userpath`. You can edit `config.m` to specify a custom installation directory.

If you restart Matlab, you'll want to call `mpmpaths` to re-add all the folders in the installation directory to your Matlab path. Better yet, just call `mpmpaths` from your Matlab [startup script](http://www.mathworks.com/help/matlab/ref/startup.html). (Note that `mpmpaths` won't add any subfolders of packages.)
