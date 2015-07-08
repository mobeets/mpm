# Matlab Package Manager

A simple package manager for Matlab (inspired by [pip](https://github.com/pypa/pip)). Downloads packages from Matlab Central's File Exchange, GitHub repositories, or any other url pointing to a .zip file.

## Setup

__1)__ Clone this repository

__2)__ Edit your `~/.bash_profile`

```    
MPM_MATLABPATH=$HOME/Documents/MATLAB
export MPM_MATLABPATH
alias mpm='python $HOME/mpm/main.py -o $MPM_MATLABPATH'
```

The `-o` option specifies where mpm should install its MATLAB packages.
(If you didn't clone mpm to your home directory, make sure to correct the path in the alias definition above.)

__3)__ Make sure the script `mpmpath.m` is somewhere in your Matlab search [path](http://www.mathworks.com/help/matlab/matlab_env/what-is-the-matlab-search-path.html).

It's probably best to clone mpm into $MPM_MATLABPATH, and then you can skip this step.

__4)__ Call `mpmpath` in your Matlab [startup](http://www.mathworks.com/help/matlab/ref/startup.html) script, and after installing any packages using mpm.

## Usage

__Install a single file__

From File Exchange:

```
$ mpm export_fig -e http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
```

From Github:

```
$ mpm mASD -e https://github.com/mobeets/mASD.git
```

If the package already exists in the installation directory you can force mpm to overwrite it using `-f`.

```
$ mpm mASD -e https://github.com/mobeets/mASD.git
Package "mASD" already exists at /Users/mobeets/Documents/MATLAB/mASD
$ mpm mASD -e https://github.com/mobeets/mASD.git -f
Installed "mASD" to /Users/mobeets/Documents/MATLAB/mASD
```

__Install from list of requirements in file__

```
$ mpm -r requirements.txt
```

Your requirements file should look something like this:

    export-fig -e http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig?download=true
    gridfitdir -e http://www.mathworks.com/matlabcentral/fileexchange/downloads/9937/akamai/gridfitdir.zip
    mASD -e https://github.com/mobeets/mASD.git

Note: After installing anything using mpm you must either restart Matlab or call `mpmpath`.
