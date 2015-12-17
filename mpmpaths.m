function mpmpaths(installDir)
% function mpmpaths(installDir)
% 
% adds all directories inside installDir to path
%   installDir (default) = MPM_INSTALL_DIR from config.m
% 

    if nargin < 2
        MPM_INSTALL_DIR = mpmInstallDir();
        installDir = MPM_INSTALL_DIR;
    end

    fs = dir(installDir); % get names of everything in install dir
    fs = {fs([fs.isdir]).name}; % keep directories only
    fs = fs(~strcmp(fs, '.') & ~strcmp(fs, '..')); % ignore '.' and '..'
    fs = cellfun(@(f) fullfile(installDir, f), fs, 'uni', 0); % full path
    addpath(fs{:}); % adds all folders to path

end
