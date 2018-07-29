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

## mpmimport

`mpmimport` is an experimental function meant to approximate the `import package` namespace management features in most modern languages (modeled after Python). 
In languages such as Python, you must explicitely state which packages and functions you want your current script to have access to by adding `import XXX` statements to the top of the script (or in your shell). This allows you to control the global namespace, prevent silent name clashes (two functions with the same name on your matlab path that do different things) and be generally explicit about what your script requires (better for sharing your code with others or future you...). The `mpm` package manager provides excellent facilities for automatically downloading packages and adding them to a standard location, and `mpmimport` is meant to compliment this by dynamically adding packages to your path as needed. 

For example, install `imstack` from matlab file exchange without modifying the path (using the `--nopaths` flag):

``` matlab
mpm install imstack --nopaths
```

Now, one of the main functions in `imstack` is `addRoiToolbar`. To confirm that it is not on your path at the moment, type the following into the matlab shell:

``` matlab
help addRoiToolbar
```
Returns:

``` matlab
addRoiToolbar not found.

Use the Help browser search field to search the documentation, or
type "help help" for help command options, such as help for methods.
```

Now run the following in the console:

``` matlab
mpmimport("imstack")
```

When you type repeat the help query above, you should see the following now:

``` matlab
help addRoiToolbar
```
Returns:

``` matlab

help addRoiToolbar
 addRoiToolbar
 Add a toolbar for creating ROIs like Line Ellipse Rectangle Polygon and Freehand
 Right-click the ROIs to open a context menu, and you will see more
 functions there such as histogram, x-y plot, etc.
 Example:
 
    load mri;
    imshow(D(:,:,14))
    addRoiToolbar;
```

Note that the path will be modified for the duration of the session if you run this in a script or in the shell. 



## Troubleshooting

Because there's no standard directory structure for a Matlab package, automatically adding paths can get a bit messy. When mpm downloads a package, it adds a single folder within that package to your Matlab path. If there are no `*.m` files in the package's base directory, it looks in folders called 'bin', 'src', 'lib', or 'code' instead. You can specify the name of an internal directory by passing in an `-n` or `internaldir` argument.

Mpm keeps track of the packages it's downloaded in a file called `mpm.mat`, within each installation directory.
