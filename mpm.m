function mpm(varargin)
% function mpm(varargin)
% 
% calls mpm.py with arguments specified in varargin
% 
% example:
%   >> mpm export_fig
% 
% Make sure to always pass in absolute paths!
%   e.g., Instead of "mpm -r requirements.txt"
%       you might try "mpm('-r', which('requirements.txt'))"
% 
    
    opts = mpm_opts();
    args = strjoin(varargin, ' ');
    [args, opts] = addArgsAndUpdateIfNecessary(args, opts, varargin);
    curdir = fileparts(mfilename('fullpath')); % curdir of this file    
    cmd = [opts.PYTHON_EXE ' ' fullfile(curdir, 'mpm.py') ' ' args];
    [~, output] = system(cmd);    
    parseOutputsAndAddToPath(output, opts);

end

function [args, opts] = addArgsAndUpdateIfNecessary(args, opts, rawargs)
% function args = addArgsAndUpdateIfNecessary(args, opts, rawargs)
% 
% if user does not pass installdir, uses MPM_INSTALL_DIR
%   as defined in mpm_config.m
% specifies path to Python interpreter
% 

    args = [args ' --pythonexe ' opts.PYTHON_EXE];
    for ii = 1:numel(rawargs)
        v = rawargs{ii};
        if strcmpi(v, '--installdir') || strcmpi(v, '-i')
            opts.MPM_INSTALL_DIR = rawargs{ii+1};
            return;
        end
    end
    args = [args ' --installdir ' opts.MPM_INSTALL_DIR];
end

function parseOutputsAndAddToPath(output, opts)

    disp(output);
    lines = strsplit(output, '\n');
    
    % errors: print in red
    ix0 = cellfun(@(f) ~isempty(strfind(f, 'ERROR: ')), lines);
    errPs = lines(ix0);
    for p = errPs
        warning(p{1}); % check to make sure url is correct
    end
    
    % warnings: print in red
    ix0 = cellfun(@(f) ~isempty(strfind(f, 'WARNING: ')), lines);
    errPs = lines(ix0);
    for p = errPs
        warning(p{1}); % check to make sure url is correct
    end
        
    mpm_paths(opts.MPM_INSTALL_DIR);
    disp('Updated paths.');
    
%     % already installed: add path again just in case
%     ix2 = cellfun(@(f) ~isempty(strfind(f, 'already exists at')), lines);
%     oldPs = lines(ix2);
%     for p = oldPs
%        cs = strsplit(p{1}, ' at ');
%        ds = strsplit(cs{1}, '"');
%        disp(['Re-adding path for "' ds{2} '": ' cs{2}]);
%        addpath(cs{2});
%     end
%     
%     % new installs: add path
%     ix1 = cellfun(@(f) ~isempty(strfind(f, 'Installed ')), lines);
%     newPs = lines(ix1);
%     for p = newPs
%         cs = strsplit(p{1}, ' to ');
%         ds = strsplit(cs{1}, '"');
%         disp(['Added path for "' ds{2} '": ' cs{2}]);
%         addpath(cs{2});
%     end
end
