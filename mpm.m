function mpm(varargin)
% function mpm(varargin)
% 
% calls mpm.py with arguments specified in varargin
% 
% example:
%   >> mpm mASD -e https://github.com/mobeets/mASD.git
% OR
%   >> mpm('mASD', '-e', 'https://github.com/mobeets/mASD.git');
% 
% Make sure to pass absolute paths!
%   e.g. Instead of mpm('-r', 'requirements.txt')
%       try mpm('-r', which('requirements.txt'))
% 
    
    args = strjoin(varargin, ' ');
    args = checkToUseDefaultInstallDir(args);
    curdir = fileparts(mfilename('fullpath'));
    output = ['python ' fullfile(curdir, 'mpm.py') ' ' args];
    [~, commandOut] = system(output);
    disp(commandOut);
%     mpmpaths;

end

function args = checkToUseDefaultInstallDir(args)
% args = checkToUseDefaultInstallDir(args)
% 
% if user does not pass installdir, uses MPM_INSTALL_DIR
%   as defined in mpm_config.m
% 

    if ~isempty(strfind(args, '-o')) || ...
            ~isempty(strfind(args, '--installdir'))
        return;
    end
    MPM_INSTALL_DIR = mpmInstallDir();
    args = [args ' --installdir ' MPM_INSTALL_DIR];
end
