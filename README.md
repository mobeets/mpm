# Matlab Package Manager (mpm)

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Quickstart

Download/clone this repo and add it to your Matlab path (using `addpath`). Now try the following:

- `mpm install [package-name]`: install package by name
- `mpm uninstall [package-name]`: remove package, if installed
- `mpm search [package-name]`: find url given package name
- `mpm freeze`: lists all packages currently installed
- `mpm init`: adds all installed packages to path (for running on Matlab startup)

## More details

### Install a single package

__Install (searches FileExchange and Github):__

```
>> mpm install export_fig
```

__Install a particular Github release (by tag)__

```
>> mpm install matlab2tikz -t 1.0.0
```

__Uninstall__

```
>> mpm uninstall matlab2tikz
```

__Search without installing:__

```
>> mpm search export_fig
```

__Install from a url:__

```
>> mpm install export_fig -u http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
```
OR:

```
>> mpm install export_fig -u https://github.com/altmany/export_fig.git
```

(Note that when specifying Github repo urls you must add the '.git' to the url.)

__Overwrite existing packages:__

```
>> mpm install matlab2tikz --force
```

__Install/uninstall packages in a specific directory:__

```
>> mpm install matlab2tikz -d /Users/mobeets/mypath
```

Note that the default installation directory is`mpm-packages/`.

### Install multiple packages using a requirements file

```
>> mpm install -i /Users/mobeets/example/requirements.txt
```

Specifying a requirements file lets you install or search for multiple packages at once. See 'requirements-example.txt' for an example. Make sure to provide an absolute path to the file!

By default, mpm tries to find the best folder in the package to add to your Matlab path. To install a package without modifying any paths, set `--nopaths`.

## What it does

By default, mpm installs all Matlab packages to the directory `mpm-packages/`. (You can edit `mpm_config.m` to specify a custom default installation directory.)

If you restart Matlab, you'll want to run `mpm init` to re-add all the folders in the installation directory to your Matlab path. Better yet, just run `mpm init` from your Matlab [startup script](http://www.mathworks.com/help/matlab/ref/startup.html).

## Troubleshooting

Because there's no standard directory structure for a Matlab package, automatically adding paths can get a bit messy. When mpm downloads a package, it adds a single folder within that package to your Matlab path. If there are no `*.m` files in the package's base directory, it looks in folders called 'bin', 'src', 'lib', or 'code' instead. You can specify the name of an internal directory by passing in an `-n` or `internaldir` argument.

Mpm keeps track of the packages it's downloaded in a file called `mpm.mat`, within each installation directory.
