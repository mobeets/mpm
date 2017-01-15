function [MPM_INSTALL_DIR, PYTHON_EXE] = mpmprefs()
    curdir = fileparts(mfilename('fullpath'));
    run(fullfile(curdir, 'config.m')); % loads MPM_INSTALL_DIR
    if ~exist('MPM_INSTALL_DIR', 'var')
        error('MPM_INSTALL_DIR was not defined in config.m');
    end
    if ispc
        % do nothing
    else
        MPM_INSTALL_DIR = strrep(MPM_INSTALL_DIR, ':', '');
    end
    if ~exist('PYTHON_EXE', 'var')
        PYTHON_EXE = 'python';
    end
end
