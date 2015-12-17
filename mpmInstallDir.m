function MPM_INSTALL_DIR = mpmInstallDir()
    curdir = fileparts(mfilename('fullpath'));
    run(fullfile(curdir, 'config.m')); % loads MPM_INSTALL_DIR
    if ~exist('MPM_INSTALL_DIR', 'var')
        error('MPM_INSTALL_DIR was not defined in config.m');
    end
    MPM_INSTALL_DIR = strrep(MPM_INSTALL_DIR, ':', '');
end
