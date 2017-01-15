# Matlab Package Manager (mpm)

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Setup

Clone this repo and add it to your Matlab path (using `addpath`).

To run the basic version you will need a working Python installation. To install repositories without specifying a url, you will also need the `lxml` and `PyGithub` packages (which you can install with `$ pip install ...`).

## Usage

### Install a single package

__Install without a url (searches FileExchange and Github):__

```
>> mpm export_fig
```

__Install a particular Github release (by tag)__

```
>> mpm matlab2tikz -v 1.0.0
```

__Search without installing:__

```
>> mpm export_fig -s
```

__Install from a url:__

```
>> mpm export_fig http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
```
OR:

```
>> mpm export_fig https://github.com/altmany/export_fig.git
```

Note that for Github repo urls you must add the '.git' to the url.

__Overwrite existing packages:__

```
>> mpm matlab2tikz -f
```

### Install multiple packages using a requirements file

```
>> mpm -r /Users/mobeets/example/requirements.txt
```

Specifying a requirements file lets you install multiple packages at once. Note that `mpm` requires the absolute path to your requirements file. `which('requirements.txt')` might help! The file should just be a list of package names and urls. See 'requirements-example.txt' for an example.

## What it does

By default, mpm will install all Matlab packages to the directory specified by `userpath`. You can edit `config.m` to specify a custom installation directory.

If you restart Matlab, you'll want to call `mpmpaths` to re-add all the folders in the installation directory to your Matlab path. Better yet, just call `mpmpaths` from your Matlab [startup script](http://www.mathworks.com/help/matlab/ref/startup.html). (Note that `mpmpaths` won't add any subfolders of packages.)
