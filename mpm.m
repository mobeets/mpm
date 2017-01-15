function mpm(varargin)
% function mpm(varargin)
% 
% calls mpm.py with arguments specified in varargin
% 
% example:
%   >> mpm mASD https://github.com/mobeets/mASD.git
% 
% Make sure to pass absolute paths!
%   e.g. Instead of mpm('-r', 'requirements.txt')
%       try mpm('-r', which('requirements.txt'))
% 
    
    [MPM_INSTALL_DIR, PYTHON_EXE] = mpmprefs;
    args = strjoin(varargin, ' ');
    args = addArgsIfNecessary(args, MPM_INSTALL_DIR, PYTHON_EXE);
    curdir = fileparts(mfilename('fullpath')); % curdir of this file    
    cmd = [PYTHON_EXE ' ' fullfile(curdir, 'mpm.py') ' ' args];
    disp(cmd);
    [~, output] = system(cmd);
    disp(output);
    parseOutputsAndAddToPath(output);

end

function args = addArgsIfNecessary(args, MPM_INSTALL_DIR, PYTHON_EXE)
% function args = addArgsIfNecessary(args)
% 
% if user does not pass installdir, uses MPM_INSTALL_DIR
%   as defined in config.m
% specifies path to Python interpreter
% 

    args = [args ' --pythonexe ' PYTHON_EXE];
    if ~isempty(strfind(args, '-o')) || ...
            ~isempty(strfind(args, '--installdir'))
        return;
    end
    args = [args ' --installdir ' MPM_INSTALL_DIR];
end

function parseOutputsAndAddToPath(output)

    lines = strsplit(output, '\n');
    
    % errors: print in red
    ix0 = cellfun(@(f) ~isempty(strfind(f, 'ERROR: ')), lines);
    errPs = lines(ix0);
    for p = errPs
        warning(p{1}); % check to make sure url is correct
    end        
    
    % already installed: add path again just in case
    ix2 = cellfun(@(f) ~isempty(strfind(f, 'already exists at')), lines);
    oldPs = lines(ix2);
    for p = oldPs
       cs = strsplit(p{1}, ' at ');
       ds = strsplit(cs{1}, '"');
       disp(['Re-adding path for "' ds{2} '": ' cs{2}]);
       addpath(cs{2});
    end
    
    % new installs: add path
    ix1 = cellfun(@(f) ~isempty(strfind(f, 'Installed ')), lines);
    newPs = lines(ix1);
    for p = newPs
        cs = strsplit(p{1}, ' to ');
        ds = strsplit(cs{1}, '"');
        disp(['Added path for "' ds{2} '": ' cs{2}]);
        addpath(cs{2});
    end
end
