function mpm2(action, varargin)
% function mpm2(action, varargin)
% 
% positional arguments:
% - action [required]: accept 'install' or 'search' for now; see #30
% - name [optional]: name of package (e.g., 'matlab2tikz')
% 
% name-value arguments:
% - url (-u): optional; if does not exist, must search
% - Infile (-i): if set, will run mpm2 on all packages in requirements file
% - InstallDir (-d): where to install package
% - InternalDir (-n): lets user set which directories inside package to add to path
% - ReleaseTag (-t): if url is found on github, this lets user set release tag

% arguments, if passed, are true:
% - SearchGithubFirst (-g): check github for url before matlab fileexchange
% - Force (-f): install package even if name already exists in InstallDir
% 
    opts = parseArgs(action, varargin);
    validateArgs(opts);
    if isempty(opts.url) && isempty(opts.infile)
        opts.url = findUrl(opts);
        disp(['For ''' opts.name ''', found url: ' opts.url]);
    end
    if strcmpi(opts.action, 'install')
        installPackages(opts);
        updatePaths(opts);
        updateMetadata(opts);
    end
end

function url = findUrl(opts)
    url = ''; % must search here
end

function installPackages(opts)
end

function updatePaths(opts)
end

function updateMetadata(opts)
end

function opts = parseArgs(action, varargin)
% function p = parseArgs(action, varargin)
% 

    % init matlab's input parser and read action
    q = inputParser;
    validActions = {'install', 'search'};
    checkAction = @(x) any(validatestring(x, validActions));
    addRequired(q, 'action', checkAction);
    defaultName = '';
    addOptional(q, 'remainingargs', defaultName);
    parse(q, action, varargin{:});
    
    % 
    opts = q.Results;
    remainingArgs = q.Results.remainingargs;
    opts = rmfield(opts, 'remainingargs');
    allParams = {'url', 'infile', 'installdir', 'internaldir', ...
        'releasetag', 'searchgithubfirst', 'force', '-u', '-i', '-d', ...
        '-n', '-t', '-g', '-f'};
    
    % no additional args
    if numel(remainingArgs) == 0
        error('You must specify a package name or a filename.');
    end
    
    % if first arg is not a param name, it's the package name
    nextArg = remainingArgs{1};
    if ~ismember(lower(nextArg), lower(allParams))
        opts.name = nextArg;
        remainingArgs = remainingArgs(2:end);
    else
        opts.name = '';
    end
    
    % check for parameters, passed as name-value pairs
    opts = setDefaultArgs(opts);
    usedNextArg = false;
    for ii = 1:numel(remainingArgs)
        curArg = remainingArgs{ii};
        if usedNextArg
            usedNextArg = false;
            continue;
        end        
        usedNextArg = false;
        if strcmpi(curArg, 'url') || strcmpi(curArg, '-u')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.url = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'Infile') || strcmpi(curArg, '-i')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.infile = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'InstallDir') || strcmpi(curArg, '-d')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.installdir = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'InternalDir') || strcmpi(curArg, '-n')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.internaldir = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'ReleaseTag') || strcmpi(curArg, '-t')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.releasetag = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'SearchGithubFirst') || ...
                strcmpi(curArg, '-g')
            opts.searchgithubfirst = true;
        elseif strcmpi(curArg, 'Force') || strcmpi(curArg, '-f')
            opts.force = true;
        else
            error(['Did not recognize argument ''' curArg '''.']);
        end
    end 
end

function nextArg = getNextArg(remainingArgs, ii, curArg)
    if numel(remainingArgs) <= ii
        error(['No value was given for ''' curArg ...
            '''. Name-value pair arguments require a name followed by ' ...
            'a value.']);
    end
    nextArg = remainingArgs{ii+1};
end

function opts = setDefaultArgs(opts)
    opts.url = '';
    opts.infile = '';
    opts.installdir = '';
    opts.internaldir = '';
    opts.releasetag = '';
    opts.searchgithubfirst = false;
    opts.force = false;    
end

function isOk = validateArgs(opts)
    isOk = true;
    if isempty(opts.name) && isempty(opts.infile)
        error('You must specify a package name or a filename.');
    end
    if ~isempty(opts.infile)
        assert(isempty(opts.name), ...
            'Cannot specify name if installing from filename');
        assert(isempty(opts.url), ...
            'Cannot specify url if installing from filename');
        assert(isempty(opts.internaldir), ...
            'Cannot specify internaldir if installing from filename');
        assert(isempty(opts.releasetag), ...
            'Cannot specify releasetag if installing from filename');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst if installing from filename');
    end
end
