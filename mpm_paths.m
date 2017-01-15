function mpm_paths(install_dir)
% function mpm_paths(install_dir)
% 
% adds directories listed inside mpm.json file to path
%   install_dir (default) = MPM_INSTALL_DIR from config.m
% 
    if nargin < 2
        opts = mpm_opts();
        install_dir = opts.MPM_INSTALL_DIR;
    end
    mpmfile = fullfile(install_dir, 'mpm.json');
    if ~exist(mpmfile, 'file')
        return;
    end
    ps = loadjson_internal(mpmfile);
    nmsAdded = {};
    for ii = 1:numel(ps)
        p = ps{ii};
        nmsAdded = [nmsAdded p.name];
        if exist(p.mdir, 'dir')
            addpath(p.mdir);
        end
    end
    if opts.HANDLE_ALL_PATHS_IN_INSTALL_DIR
        mpm_all_paths(install_dir, nmsAdded);
    end
end

function mpm_all_paths(installDir, nmsAlreadyAdded)
% function mpm_all_paths(install_dir, nmsAlreadyAdded)
% 
% adds all directories inside install_dir to path
%   ignoring those already added
% 

    fs = dir(installDir); % get names of everything in install dir
    fs = {fs([fs.isdir]).name}; % keep directories only
    fs = fs(~strcmp(fs, '.') & ~strcmp(fs, '..')); % ignore '.' and '..'
    for ii = 1:numel(fs)
        f = fs{ii};
        if ~ismember(f, nmsAlreadyAdded)
            addpath(fullfile(installDir, f));
        end
    end
%     fs = cellfun(@(f) fullfile(installDir, f), fs, 'uni', 0); % full path
%     addpath(fs{:}); % adds all folders to path

end
