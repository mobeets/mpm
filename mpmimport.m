function mpmimport(pkg)
%mpmimport adds specific packages/functions installed with mpm to the global path 
%   Very simple function. Given one or more packages, mpmimport will look
%   in the directory specified in mpm_config() for the metadata file, and
%   load that package's path into the current session.

opts = mpm_config(); % load the options to get dirs.
try
metadata_f = fullfile(opts.DEFAULT_INSTALL_DIR, 'mpm.mat');
metadata = load(metadata_f);
catch
    warning("Couldnt find metadata file in default location: ")
    error(metadata_f);
end
metadata = metadata.packages;
pkg_path = find_pkg(pkg, metadata);
if strcmp(pkg_path, "Not present")
    fprintf("package %s not found. Try: 'mpm install %s'\n",pkg, pkg);
    error("package not found error");
else
fprintf("adding %s to path\n", pkg); % remove after debugging
addpath(pkg_path)
end
end

% function below searches th
function path = find_pkg(pkg_nm, pkg_list)
[~,pkgs] = size(pkg_list);
for ii=1:pkgs
    n = string(pkg_list(ii).name);
    if strcmp(n,pkg_nm)
        path = pkg_list(ii).installdir;
        return
    else
        path = "Not present";
    end
end
end

