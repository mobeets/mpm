# Matlab Package Manager (mpm)

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Quickstart

Download/clone this repo and add it to your Matlab path (using `addpath`). Now try the following:

- `mpm install [package-name]`: install package by name
- `mpm uninstall [package-name]`: remove package, if installed
- `mpm search [package-name]`: search for package given name (checks Github and Matlab File Exchange)
- `mpm freeze`: lists all packages currently installed
- `mpm init`: adds all installed packages to path (run when Matlab starts up)

## More details

### Install a single package

__Install (searches FileExchange and Github):__

```
>> mpm install export_fig
```

When installing, mpm checks for a file in the package called `install.m`, which it will run after confirming (or add `--force` to auto-confirm). It also checks for a file called `pathlist.m` which tells it which paths (if any) to add.

__Install a Github release (by tag, branch, or commit)__

By tag:

```
>> mpm install matlab2tikz -t 1.0.0
```

By branch:

```
>> mpm install matlab2tikz -t develop
```

By commit:

```
>> mpm install matlab2tikz -t ca56d9f
```

__Uninstall__

```
>> mpm uninstall matlab2tikz
```

When uninstalling, mpm checks for a file in the package called `uninstall.m`, which it will run after confirming (or add `--force` to auto-confirm).

__Search without installing:__

```
>> mpm search export_fig
```

__Install from a url:__

```
>> mpm install covidx -u https://www.mathworks.com/matlabcentral/fileexchange/76213-covidx
```
OR:

```
>> mpm install export_fig -u https://github.com/altmany/export_fig.git
```

(Note that when specifying Github repo urls you must add the '.git' to the url.)

__Install local package:__

```
>> mpm install my_package -u path/to/package --local
```

The above will copy `path/to/package` into the default install directory. To skip the copy, add `-e` to the above command.

__Overwrite existing packages:__

```
>> mpm install matlab2tikz --force
```

__Install/uninstall packages in a specific directory:__

```
>> mpm install matlab2tikz -d /Users/mobeets/mypath
```

Note that the default installation directory is `mpm-packages/`.

## Environments ("Collections")

mpm has rudimentary support for managing collections of packages. To specify which collection to act on, use `-c [collection_name]`. Default collection is "default".

```
>> mpm install cbrewer -c test
Using collection "test"
Collecting 'cbrewer'...
   Found url: https://www.mathworks.com/matlabcentral/fileexchange/58350-cbrewer2?download=true
   Downloading https://www.mathworks.com/matlabcentral/fileexchange/58350-cbrewer2?download=true...
>> mpm init -c test
Using collection "test"
   Adding to path: /Users/mobeets/code/mpm/mpm-packages/mpm-collections/test/cbrewer
   Added paths for 1 package(s).
```

## Installing multiple packages from file

```
>> mpm install -i /Users/mobeets/example/requirements.txt
```

Specifying a requirements file lets you install or search for multiple packages at once. See 'requirements-example.txt' for an example. Make sure to provide an absolute path to the file!

To automatically confirm installation without being prompted, set `--approve`. Note that this is only available when installing packages from file.

## What it does

By default, mpm installs all Matlab packages to the directory `mpm-packages/`. (You can edit `mpm_config.m` to specify a custom default installation directory.)

If you restart Matlab, you'll want to run `mpm init` to re-add all the folders in the installation directory to your Matlab path. Better yet, just run `mpm init` from your Matlab [startup script](http://www.mathworks.com/help/matlab/ref/startup.html).

## Troubleshooting

Because there's no standard directory structure for a Matlab package, automatically adding paths can get a bit messy. When mpm downloads a package, it adds a single folder within that package to your Matlab path. If there are no `*.m` files in the package's base directory, it looks in folders called 'bin', 'src', 'lib', or 'code' instead. You can specify the name of an internal directory by passing in an `-n` or `internaldir` argument. To install a package without modifying any paths, set `--nopaths`. Or to add _all_ subfolders in a package to the path, set `--allpaths`.

Mpm keeps track of the packages it's downloaded in a file called `mpm.mat`, within each installation directory.

## Requirements

mpm should work cross-platform on versions Matlab 2014b and later. Also note that, starting with Matlab 2022, you may see a warning when using mpm, as Matlab includes a built-in command of the same name (used for installing Matlab products).
