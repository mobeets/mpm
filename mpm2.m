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
    
    opts = setDefaultOpts();
    opts = parseArgs(opts, action, varargin);
    if opts.debug
        warning(['Debug mode. No packages will be installed, ' ...
            'or added to metadata or paths.']);
    end
    validateArgs(opts);
    if ~isempty(opts.infile)
        error('Installing from filename not yet supported.');
        % need to read filename, and call mpm2 for all lines in this file
    end
    opts.metadata = getMetadata(opts);
    isOk = checkMetadata(opts);
    if ~isOk
        return;
    end
    if isempty(opts.url)
        % find url if not set
        opts.url = findUrl(opts);
    end
    if ~isempty(opts.url) && strcmpi(opts.action, 'install')
        % download package and add to metadata
        pkg = installPackage(opts);
        if ~isempty(pkg)
            updateMetadata(opts, pkg);
            updatePaths(opts);
        end
    end
end

function opts = setDefaultOpts()
% load opts from config file, and then set additional defaults
    opts = mpm_opts(); % load default opts from config file

    opts.url = '';
    opts.infile = '';
    opts.installdir = opts.MPM_INSTALL_DIR;
    opts.internaldir = '';
    opts.releasetag = '';
    opts.searchgithubfirst = false;
    opts.force = false;
    opts.debug = false;
end

function url = findUrl(opts)
% find url by searching matlab fileexchange and github given opts.name
    url = ''; % must search here
    if ~isempty(opts.releasetag) % tag set, so search github only
        url = findUrlOnGithub(opts);
    elseif opts.searchgithubfirst
        url = findUrlOnGithub(opts);
        if isempty(url) % if nothing found, try file exchange
            url = findUrlOnFileExchange(opts);
        end
    else
        url = findUrlOnFileExchange(opts);
        if isempty(url) % if nothing found, try github
            url = findUrlOnGithub(opts);
        end
    end
    if isempty(url)
        disp(['Could not find url for package named ''' opts.name '''.']);
    else
        disp(['For package named ''' opts.name ''', found url: ' opts.url]);
    end
end

function url = findUrlOnFileExchange(opts)
% search file exchange, and return first search result

    % query file exchange
    base_url = 'http://www.mathworks.com/matlabcentral/fileexchange/';
    html = webread(base_url, 'term', opts.name);
    
    % extract all hrefs from '<a href="*" class="results_title">'
    expr = 'class="results_title"[^>]*href="([^"]*)"[^>]*|href="([^"]*)"[^>]*class="results_title"';
    tokens = regexp(html, expr, 'tokens');
    
    % return first result
    if ~isempty(tokens)
        url = tokens{1};
    else
        url = '';
    end
end

function url = findUrlOnGithub(opts)
    url = '';
end

function pkg = installPackage(opts)
% install package by downloading url, unzipping, and finding paths to add    

    pkg.name = opts.name;
    pkg.url = opts.url;
    pkg.date_downloaded = datestr(datetime);
    pkg.mdir = '';
    
    if opts.debug
        return;
    end
    
    % todo: download url
    % todo: unzip
    % todo: find mdir (folder containing .m files that we will add to path)
    
end

function m = getMetadata(opts)
    metafile = fullfile(opts.installdir, 'mpm.mat');
    if exist(metafile, 'file')
        m = load(metafile);
    else
        m = struct();
    end
    if ~isfield(m, 'packages')
        m.packages = [];
    end
end

function isOk = checkMetadata(opts)
    isOk = true;
    pkgs = opts.metadata.packages;
    ix = ismember({pkgs.name}, opts.name);
    dpkgs = pkgs(ix);
    for ii = 1:numel(dpkgs)
        if opts.force
            disp(['Package named ''' opts.name ...
                ''' already exists. Overwriting.']);
        else
            warning(['Package named ''' opts.name ...
                ''' already exists. Will not download.']);
            isOk = false;
        end
    end
end

function updateMetadata(opts, pkg)
% update metadata file to track all packages installed
    packages = [opts.metadata.packages pkg];
    if ~opts.debug
        save(metafile, 'packages');
    end
end

function updatePaths(opts)
% read metadata file and add all paths listed
    pkgs = opts.metadata.packages;
    disp(['Found ' num2str(numel(pkgs)) ' package(s) in metadata.']);
    
    % add mdir to path for each packages in metadata
    nmsAdded = {};
    for ii = 1:numel(pkgs)
        pkg = pkgs(ii);
        if exist(pkg.mdir, 'dir')
            if ~opts.debug
                addpath(pkg.mdir);
            end
            nmsAdded = [nmsAdded pkg.name];
        end
    end
    disp(['Added paths for ' num2str(numel(nmsAdded)) ' package(s).']);
    
    % also add all folders listed in install_dir
    if opts.HANDLE_ALL_PATHS_IN_INSTALL_DIR
        c = updateAllPaths(opts, nmsAdded);
        disp(['Added ' num2str(c) ' additional package(s).']);
    end
end

function c = updateAllPaths(opts, nmsAlreadyAdded)
% adds all directories inside installdir to path
%   ignoring those already added
% 
    c = 0;
    fs = dir(opts.installdir); % get names of everything in install dir
    fs = {fs([fs.isdir]).name}; % keep directories only
    fs = fs(~strcmp(fs, '.') & ~strcmp(fs, '..')); % ignore '.' and '..'
    for ii = 1:numel(fs)
        f = fs{ii};
        if ~ismember(f, nmsAlreadyAdded)
            if ~opts.debug
                addpath(fullfile(opts.installdir, f));
            end
            c = c + 1;
        end
    end
end

function opts = parseArgs(opts, action, varargin)
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
    opts.action = q.Results.action;
    remainingArgs = q.Results.remainingargs;
    allParams = {'url', 'infile', 'installdir', 'internaldir', ...
        'releasetag', 'searchgithubfirst', 'force', '-u', '-i', '-d', ...
        '-n', '-t', '-g', '-f', 'debug'};
    
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
        elseif strcmpi(curArg, 'debug')
            opts.debug = true;
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

function isOk = validateArgs(opts)
    isOk = true;
    if isempty(opts.name) && isempty(opts.infile)
        error('You must specify a package name or a filename.');
    end
    if ~isempty(opts.infile)
        assert(isempty(opts.name), ...
            'Cannot specify package name if installing from filename');
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
