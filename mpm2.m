function mpm2(action, varargin)
% function mpm2(action, varargin)
% 
% positional arguments:
%   action [required]: either 'install' or 'search'
%   name [optional]: name of package (e.g., 'matlab2tikz')
% 
% name-value arguments:
%   url (-u): optional; if does not exist, must search
%   infile (-i): if set, will run mpm2 on all packages listed in file
%   installdir (-d): where to install package
%   internaldir (-n): lets user set which directories inside package to add to path
%   release_tag (-t): if url is found on github, this lets user set release tag
% 
% arguments that are true if passed (otherwise they are false):
%   --githubfirst (-g): check github for url before matlab fileexchange
%   --force (-f): install package even if name already exists in InstallDir
%   --debug: do not install anything or update paths; just pretend
% 
    
    % parse and validate command line args
    [pkg, opts] = setDefaultOpts();
    [pkg, opts] = parseArgs(pkg, opts, action, varargin);
    validateArgs(pkg, opts);
    if opts.debug
        warning(['Debug mode. No packages will actually be installed, ' ...
            'or added to metadata or paths.']);
    end    
    if ~isempty(opts.infile)
        error('Installing from filename not yet supported.');
        % need to read filename, and call mpm2 for all lines in this file
    end
    
    % check metadata
    [opts.metadata, opts.metafile] = getMetadata(opts);
    % todo: update metadata by removing folders that no longer exist    
    
    % handle package
    success = findAndSetupPackage(pkg, opts, true);
end

function success = findAndSetupPackage(pkg, opts, addPaths)    
    success = true;
    pkg.installdir = fullfile(opts.installdir, pkg.name);
    disp(['Collecting ''' pkg.name '''...']);
    
    % check if exists
    if ~opts.force && isInMetadata(pkg, opts);
        warning('   Package already exists. Will not download.');
        success = false;
        return;
    end    
    
    % find url if not set
    if isempty(pkg.url)
        pkg.url = findUrl(pkg, opts);
    end
    
    % download package and add to metadata
    if ~isempty(pkg.url) && strcmpi(opts.action, 'install')        
        disp(['   Downloading ' pkg.url '...']);
        pkg = installPackage(pkg, opts);
        if ~isempty(pkg)
            opts = addToMetadata(pkg, opts);
            if addPaths
                disp('Updating paths...');
                updatePaths(pkg, opts);
            end
        end
    end
end

function [pkg, opts] = setDefaultOpts()
% load opts from config file, and then set additional defaults    

    pkg.url = '';    
    pkg.internaldir = '';
    pkg.release_tag = '';
    
    opts = mpm_opts(); % load default opts from config file
%     opts.installdir = opts.MPM_INSTALL_DIR;
    cdir = fileparts(mfilename('fullpath'));
    opts.installdir = fullfile(cdir, 'site-packages');
    opts.infile = '';
    opts.searchgithubfirst = false;
    opts.update_all_paths = false;
    opts.force = false;
    opts.debug = false;
end

function url = findUrl(pkg, opts)
% find url by searching matlab fileexchange and github given opts.name

    if ~isempty(pkg.release_tag) % tag set, so search github only
        url = findUrlOnGithub(pkg);
    elseif opts.searchgithubfirst
        url = findUrlOnGithub(pkg);
        if isempty(url) % if nothing found, try file exchange
            url = findUrlOnFileExchange(pkg);
        end
    else
        url = findUrlOnFileExchange(pkg);
        if isempty(url) % if nothing found, try github
            url = findUrlOnGithub(pkg);
        end
    end
    if isempty(url)
        disp('   Could not find url.');
    else
        disp(['   Found url: ' url]);
    end
end

function url = findUrlOnFileExchange(pkg)
% search file exchange, and return first search result

    % query file exchange
    base_url = 'http://www.mathworks.com/matlabcentral/fileexchange/';
    html = webread(base_url, 'term', pkg.name);
    
    % extract all hrefs from '<a href="*" class="results_title">'
    expr = 'class="results_title"[^>]*href="([^"]*)"[^>]*|href="([^"]*)"[^>]*class="results_title"';
    tokens = regexp(html, expr, 'tokens');
    
    % return first result
    if ~isempty(tokens)
        url = tokens{1}{1};
        url = [url '?download=true'];
    else
        url = '';
    end
end

function url = findUrlOnGithub(pkg)
% searches github for matlab repositories
%   - if release_tag is set, get url of release that matches
%   - otherwise, get url ofmost recent release
%   - and if no releases exist, get url of most recent commit
%

    url = '';
    
    % query github for matlab repositories, sorted by stars
    q_url = 'https://api.github.com/search/repositories';
    html = webread(q_url, 'q', pkg.name, 'language', 'matlab', ...
        'sort', 'stars', 'order', 'desc');
    if isempty(html) || ~isfield(html, 'items') || isempty(html.items)
        return;
    end

    % take first repo
    item = html.items(1);
    
    if ~isempty(pkg.release_tag)
        % if release tag set, return the release matching this tag
        res = webread(item.tags_url);
        if isempty(res) || ~isfield(res, 'zipball_url')
            return;
        end
        ix = strcmpi({res.name}, pkg.release_tag);
        if sum(ix) == 0
            return;
        end
        ind = find(ix, 1, 'first');
        url = res(ind).zipball_url;
    else
        rel_url = [item.url '/releases/latest'];
        try
            res = webread(rel_url);
        catch
            url = [item.html_url '/zipball/master'];
            return;
        end
        if ~isempty(res) && isfield(res, 'zipball_url')
            url = res.zipball_url;
        else
            url = [item.html_url '/zipball/master']; % if no releases found
        end
    end
end

function pkg = installPackage(pkg, opts)
% install package by downloading url, unzipping, and finding paths to add    
    
    if opts.debug
        return;
    end
    
    % check for previous package
    if exist(pkg.installdir, 'dir') && ~opts.force
        warning(['   Could not install because package already exists.']);
        return;
    elseif exist(pkg.installdir, 'dir')
        % remove old directory
        disp('   Removing previous version from disk.');
        rmdir(pkg.installdir, 's');
    end
    
    isOk = unzipFromUrl(pkg);
    if ~isOk
        warning(['   Could not install.']);
        return;
    end
    pkg.date_downloaded = datestr(datetime);
    pkg.mdir = findMDirOfPackage(pkg);
    
end

function isOk = unzipFromUrl(pkg)
% download from url to installdir
    isOk = true;
    
    zipfnm = [tempname '.zip'];
    zipfnm = websave(zipfnm, pkg.url);
    unzip(zipfnm, pkg.installdir);

    fnms = dir(pkg.installdir);
    nfnms = numel(fnms);
    ndirs = sum([fnms.isdir]);
    if ((nfnms == 3) && (ndirs == 3)) || ...
            ((nfnms == 4) && (ndirs == 3) && ...
            strcmpi(fnms(~[fnms.isdir]).name, 'license.txt'))
        % only folders are '.', '..', and package folder (call it drnm)
        %       and then maybe a license file, 
        %       so copy the subtree of drnm and place inside installdir
        fldrs = fnms([fnms.isdir]);
        fldr = fldrs(end).name;
        drnm = fullfile(pkg.installdir, fldr);
        movefile(fullfile(drnm, '*'), pkg.installdir);
        rmdir(drnm, 's');
    end
end

function mdir = findMDirOfPackage(pkg)
% todo: find mdir (folder containing .m files that we will add to path)
    
    if ~isempty(pkg.internaldir)
        if exist(fullfile(pkg.installdir, pkg.internaldir), 'dir')
            mdir = opts.internaldir;
            return;
        else
            warning('Ignoring internaldir because it did not exist in package.');
        end
    end
    
	fnms = dir(fullfile(pkg.installdir, '*.m'));
    if ~isempty(fnms)
        mdir = ''; % all is well; *.m files exist in base directory
    else
        M_DIR_ORDER = {'bin', 'src', 'lib', 'code'};
        for ii = 1:numel(M_DIR_ORDER)
            fnms = dir(fullfile(pkg.installdir, M_DIR_ORDER{ii}, '*.m'));
            if ~isempty(fnms)
                mdir = M_DIR_ORDER{ii};
                return;
            end
        end
    end
    warning(['Could not find folder with .m files. ' ...
        'May need to manually add files to path.']);
    mdir = '';
end

function [m, metafile] = getMetadata(opts)
    metafile = fullfile(opts.installdir, 'mpm.mat');
    if exist(metafile, 'file')
        m = load(metafile);
    else
        m = struct();
    end
    if ~isfield(m, 'packages')
        m.packages = [];
    end
    pkgs = m.packages;
    clean_pkgs = [];
    for ii = 1:numel(pkgs)
        pth = fullfile(pkgs(ii).installdir, pkgs(ii).mdir);
        if exist(pth, 'dir')
            clean_pkgs = [clean_pkgs pkgs(ii)];
        end
    end
    m.packages = clean_pkgs;
end

function doQuit = isInMetadata(pkg, opts)
    doQuit = false;
    pkgs = opts.metadata.packages;
    if isempty(pkgs)
        return;
    end
    if any(ismember({pkgs.name}, pkg.name))
        doQuit = true;
    end
end

function opts = addToMetadata(pkg, opts)
% update metadata file to track all packages installed
    pkgs = opts.metadata.packages;
    if ~isempty(pkgs)
        ix = ismember({pkgs.name}, pkg.name);
    else
        ix = 0;
    end
    if sum(ix) > 0
        assert(sum(ix) == 1);
        ind = find(ix, 1, 'first');
        pkgs = [pkgs(1:(ind-1)) pkgs(ind+1:end)];
        disp(['   Removing previous version from metadata in  ' ...
            opts.metafile]);
    end
    disp(['   Adding package to metadata in ' opts.metafile]);
    pkgs = [pkgs pkg];
    
    % write to file
    packages = pkgs;
    opts.metadata.packages = packages;
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
end

function updatePaths(pkg, opts)
% read metadata file and add all paths listed
    
    % add mdir to path for current package
    nmsAdded = {};
    success = updatePath(pkg, opts);
    if success
        nmsAdded = [nmsAdded pkg.name];
    end
    
    % add mdir to path for each package in metadata (optional)
    if opts.update_all_paths
        pkgs = opts.metadata.packages;
        for ii = 1:numel(pkgs)
            success = updatePath(pkgs(ii), opts);
            if success
                nmsAdded = [nmsAdded pkgs(ii).name];
            end
        end
    end
    disp(['   Added paths for ' num2str(numel(nmsAdded)) ' package(s).']);
    
    % also add all folders listed in install_dir (optional)
    if opts.HANDLE_ALL_PATHS_IN_INSTALL_DIR
        c = updateAllPaths(opts, nmsAdded);
        disp(['   Added paths for ' num2str(c) ' additional package(s).']);
    end
end

function success = updatePath(pkg, opts)
    success = false;
    pth = fullfile(pkg.installdir, pkg.mdir);
    if exist(pth, 'dir')
        success = true;
        if ~opts.debug
            disp(['   Adding to path: ' pth]);
            addpath(pth);
        end
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
                pth = fullfile(opts.installdir, f);
                disp(['   Adding to path: ' pth]);
                addpath(pth);
            end
            c = c + 1;
        end
    end
end

function [pkg, opts] = parseArgs(pkg, opts, action, varargin)
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
        'release_tag', '--githubfirst', '--force', ...
        '-u', '-i', '-d', '-n', '-t', '-g', '-f', '--debug'};
    
    % no additional args
    if numel(remainingArgs) == 0
        error('You must specify a package name or a filename.');
    end
    
    % if first arg is not a param name, it's the package name
    nextArg = remainingArgs{1};
    if ~ismember(lower(nextArg), lower(allParams))
        pkg.name = nextArg;
        remainingArgs = remainingArgs(2:end);
    else
        pkg.name = '';
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
            pkg.url = nextArg;
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
            pkg.internaldir = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'release_tag') || strcmpi(curArg, '-t')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            pkg.release_tag = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, '--GithubFirst') || ...
                strcmpi(curArg, '-g')
            opts.searchgithubfirst = true;
        elseif strcmpi(curArg, '--force') || strcmpi(curArg, '-f')
            opts.force = true;
        elseif strcmpi(curArg, '--debug')
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

function isOk = validateArgs(pkg, opts)
    isOk = true;
    if isempty(pkg.name) && isempty(opts.infile)
        error('You must specify a package name or a filename.');
    end
    if ~isempty(opts.infile)
        assert(isempty(pkg.name), ...
            'Cannot specify package name if installing from filename');
        assert(isempty(pkg.url), ...
            'Cannot specify url if installing from filename');
        assert(isempty(pkg.internaldir), ...
            'Cannot specify internaldir if installing from filename');
        assert(isempty(pkg.release_tag), ...
            'Cannot specify release_tag if installing from filename');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst if installing from filename');
    end
end
