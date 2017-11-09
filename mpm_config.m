function opts = mpm_config()

    opts = struct();
    
    % set default directory to install packages
    curdir = fileparts(mfilename('fullpath'));
    opts.DEFAULT_INSTALL_DIR = fullfile(curdir, 'mpm-packages');
    
    % search github before searching Matlab File Exchange?
    opts.DEFAULT_CHECK_GITHUB_FIRST = false;
    
    % update all paths on each install?
    opts.update_mpm_paths = false;    

end
