function opts = mpm_opts()
    curdir = fileparts(mfilename('fullpath'));
    run(fullfile(curdir, 'mpm_config.m')); % loads config preferences
    if ~exist('MPM_INSTALL_DIR', 'var')
        error('MPM_INSTALL_DIR was not defined in mpm_config.m');
    end
    if ~exist('PYTHON_EXE', 'var')
        error('PYTHON_EXE was not defined in mpm_config.m');
    end
    if ~exist('HANDLE_ALL_PATHS_IN_INSTALL_DIR', 'var')
        error('HANDLE_ALL_PATHS_IN_INSTALL_DIR was not defined in mpm_config.m');
    end
    if ispc
        % do nothing
    else
        MPM_INSTALL_DIR = strrep(MPM_INSTALL_DIR, ':', '');
    end
    opts = struct('PYTHON_EXE', PYTHON_EXE, ...
        'MPM_INSTALL_DIR', MPM_INSTALL_DIR, ...
        'HANDLE_ALL_PATHS_IN_INSTALL_DIR', HANDLE_ALL_PATHS_IN_INSTALL_DIR);
end
