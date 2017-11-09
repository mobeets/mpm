function mpm(action, varargin)
% function mpm(action, varargin)
% 
% positional arguments:
%   action [required]:
%       - init: add all installed packages in default install directory to
%       path
%       - install: installs a package by name
%       - uninstall: installs a package by name
%       - search: finds a url for a package by name (searches Github and
%       - freeze: list all installed packages (optional: in installdir)
%       File Exchange)
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
%   --nopaths: do not add anything to path after installing
% 
    
    % parse and validate command line args
    [pkg, opts] = setDefaultOpts();
    [pkg, opts] = parseArgs(pkg, opts, action, varargin);
    validateArgs(pkg, opts);
    if opts.debug
        warning(['Debug mode. No packages will actually be installed, ' ...
            'or added to metadata or paths.']);
    end
    
    % installing from requirements
    if ~isempty(opts.infile)
        % read filename, and call mpm2 for all lines in this file
        readRequirementsFile(opts.infile, opts);
        return;        
    end
    
    % load metadata
    [opts.metadata, opts.metafile] = getMetadata(opts);
    
    % mpm init
    if strcmpi(opts.action, 'init')
        opts.update_mpm_paths = true;
        pkg.addpath = false; % ignore dummy pkg
        updatePaths(pkg, opts);
        return;
    end
    
    % mpm freeze
    if strcmpi(opts.action, 'freeze')
        listPackages(opts);
        return;
    end
    
    % mpm uninstall
    if strcmpi(opts.action, 'uninstall')
        removePackage(pkg, opts);
        return;
    end
    
    % mpm search OR mpm install
    findAndSetupPackage(pkg, opts);
end

function success = findAndSetupPackage(pkg, opts)    
    success = true;
    pkg.installdir = fullfile(opts.installdir, pkg.name);
    disp(['Collecting ''' pkg.name '''...']);
    
    % check if exists
    if ~opts.force && ...
            ~isempty(indexInMetadata(pkg, opts.metadata.packages))
        warning(['   Package already exists. ' ...
            'Re-run with --force to overwrite.']);
        success = false;
        return;
    end    
    
    % find url if not set
    if isempty(pkg.url)
        pkg.url = findUrl(pkg, opts);
    else
        pkg.url = handleCustomUrl(pkg.url);
    end
    
    % download package and add to metadata
    if ~isempty(pkg.url) && strcmpi(opts.action, 'install')        
        disp(['   Downloading ' pkg.url '...']);
        pkg = installPackage(pkg, opts);
        if ~isempty(pkg)
            opts = addToMetadata(pkg, opts);
            if pkg.addpath
                disp('Updating paths...');
                updatePaths(pkg, opts);
            end
        end
    end
end

function removePackage(pkg, opts)
    pkgs = opts.metadata.packages;
    [~, ix] = indexInMetadata(pkg, pkgs);
    if ~any(ix)
        disp(['   No previous versions of ''' pkg.name ...
            ''' installed by mpm were found.']);
        return;
    end
    
    % delete package directories if they exist
    pkgsToRm = pkgs(ix);
    disp(['   Removing ' num2str(sum(ix)) ' package(s) named ''' ...
        pkg.name '''.']);
    if ~opts.force
        reply = input('   Confirm (y/n)? ', 's');
        if isempty(reply)
            reply = 'y';
        end
        if ~strcmpi(reply(1), 'y')
            disp('   Forget I asked.');
            return;
        end
    end
    for ii = 1:numel(pkgsToRm)
        pkg = pkgsToRm(ii);
        if exist(pkg.installdir, 'dir')
            % remove old directory
            rmdir(pkg.installdir, 's');
        end
    end
    
    % write new metadata to file
    packages = pkgs(~ix);
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
    
    disp('Uninstallation complete.');
end

function listPackages(opts)
    pkgs = opts.metadata.packages;
    if isempty(pkgs)
        disp(['No packages currently installed to ' opts.installdir]);
        return;
    end
    disp(['Packages currently installed to ' opts.installdir ':']);
    for ii = 1:numel(pkgs)
        pkg = pkgs(ii);
        nm = pkg.name;
        if ~isempty(pkg.release_tag)
            nm = [nm '==' pkg.release_tag];
        end
        disp(['- ' nm]);
    end
end

function [pkg, opts] = setDefaultOpts()
% load opts from config file, and then set additional defaults    

    % empty package
    pkg.name = '';
    pkg.url = '';    
    pkg.internaldir = '';
    pkg.release_tag = '';
    pkg.addpath = true;
    
    opts = mpm_config(); % load default opts from config file
    opts.installdir = opts.DEFAULT_INSTALL_DIR;
%     opts.update_mpm_paths = false; % set in mpm_config
    opts.searchgithubfirst = opts.DEFAULT_CHECK_GITHUB_FIRST;
    opts.update_all_paths = false;    
    
    opts.infile = '';    
    opts.force = false;
    opts.debug = false;
    opts.nopaths = false;
end

function url = handleCustomUrl(url)
    
    % if .git url, must remove and add /zipball/master
    inds = strfind(url, '.git');
    if isempty(inds)
        inds = strfind(url, '?download=true');
        if isempty(inds)
            url = [url '?download=true'];
            return;
        end
    end
    ind = inds(end);
    url = [url(1:ind-1) '/zipball/master' url(ind+4:end)];
    
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
        warning('   Could not install because folder already exists.');
        return;
    elseif exist(pkg.installdir, 'dir')
        % remove old directory
        disp('   Removing previous version from disk.');
        rmdir(pkg.installdir, 's');
    end
    
    isOk = unzipFromUrl(pkg);
    if ~isOk
        warning('   Could not install.');
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
% find mdir (folder containing .m files that we will add to path)
    
    if ~pkg.addpath
        mdir = '';
        return;
    end
    if ~isempty(pkg.internaldir)
        if exist(fullfile(pkg.installdir, pkg.internaldir), 'dir')
            mdir = opts.internaldir;
            return;
        else
            warning(['Ignoring internaldir because ' ...
                'it did not exist in package.']);
        end
    end
    
	fnms = dir(fullfile(pkg.installdir, '*.m'));
    if ~isempty(fnms)
        mdir = ''; % all is well; *.m files exist in base directory
        return;
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

function [ind, ix] = indexInMetadata(pkg, pkgs)
    if isempty(pkgs)
        ind = []; ix = [];
        return;
    end
    ix = ismember({pkgs.name}, pkg.name);
    ind = find(ix, 1, 'first');
end

function opts = addToMetadata(pkg, opts)
% update metadata file to track all packages installed

    pkgs = opts.metadata.packages;
    [~, ix] = indexInMetadata(pkg, pkgs);
    if any(ix)
        pkgs = pkgs(~ix);
        disp(['   Replacing previous version in metadata in  ' ...
            opts.metafile]);
    else
        disp(['   Adding package to metadata in ' opts.metafile]);
    end
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
    if opts.update_mpm_paths
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
    if opts.update_all_paths
        c = updateAllPaths(opts, nmsAdded);
        disp(['   Added paths for ' num2str(c) ' additional package(s).']);
    end
end

function success = updatePath(pkg, opts)
    success = false;
    if ~pkg.addpath
        return;
    end
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
    validActions = {'install', 'search', 'uninstall', 'init', 'freeze'};
    checkAction = @(x) any(validatestring(x, validActions));
    addRequired(q, 'action', checkAction);
    defaultName = '';
    addOptional(q, 'remainingargs', defaultName);
    parse(q, action, varargin{:});
    opts.action = q.Results.action;
    remainingArgs = q.Results.remainingargs;
    
    if strcmpi(opts.action, 'init')
        if ~isempty(remainingArgs)
            error('If running ''init'', no other arguments are needed.');
        end
        return;
    end
    
    allParams = {'url', 'infile', 'installdir', 'internaldir', ...
        'release_tag', '--githubfirst', '--force', '--nopaths', ...
        '-u', '-i', '-d', '-n', '-t', '-g', '-f', '--debug'};
    
    % no additional args
    if numel(remainingArgs) == 0
        if strcmpi(opts.action, 'freeze')
            return;
        else
            error('You must specify a package name or a filename.');
        end
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
        elseif strcmpi(curArg, '--nopaths')
            pkg.addpath = false;
            opts.nopaths = true;
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
    if strcmpi(opts.action, 'init')
        return;
    end
    if isempty(pkg.name) && isempty(opts.infile)
        if ~strcmpi(opts.action, 'freeze')
            error('You must specify a package name or a filename.');
        end
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
    if strcmpi(opts.action, 'uninstall')
        assert(isempty(pkg.url), ...
            'Cannot specify url if uninstalling');
        assert(isempty(pkg.internaldir), ...
            'Cannot specify internaldir if uninstalling');
        assert(isempty(pkg.release_tag), ...
            'Cannot specify release_tag if uninstalling');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst if uninstalling');
    end
    if strcmpi(opts.action, 'search')
        assert(~opts.force, 'Nothing to force when searching.');
    end
    if strcmpi(opts.action, 'freeze')
        assert(~opts.force, 'Nothing to force when running ''freeze''.');
        assert(isempty(pkg.url), ...
            'Cannot specify url when running ''freeze''');
        assert(isempty(pkg.internaldir), ...
            'Cannot specify internaldir when running ''freeze''');
        assert(isempty(pkg.release_tag), ...
            'Cannot specify release_tag when running ''freeze''');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst when running ''freeze''');
    end
end

function readRequirementsFile(fnm, opts)
    txt = fileread(fnm);
    lines = strsplit(txt, '\n');
    
    % build list of commands to run
    % and check for illegal params (note spaces)
    illegalParams = {' -i ', ' infile ', ' installdir '};
    cmds = {};    
    for ii = 1:numel(lines)
        line = lines{ii};
        for jj = 1:numel(illegalParams)
            if ~isempty(strfind(line, illegalParams{jj}))
                error(['Line ' num2str(ii) ...
                    ' in infile cannot contain ''' illegalParams{jj} ...
                    '''. (Illegal arguments: ''-i'',' ...
                    '''infile'',  ''installdir''.)']);
            end
        end
        if opts.force && (~isempty(strfind(line, ' --force')) || ...
                ~isempty(strfind(line, ' -f')))
            error('Cannot set --force because it is in infile.');
        end
        if opts.nopaths && ~isempty(strfind(line, ' --nopaths'))
            error('Cannot set --nopaths because it is in infile.');
        end
        if ~isempty(line)
            cmd = [line ' installdir ' opts.installdir];
            if opts.force
                cmd = [cmd ' --force'];
            end
            if opts.nopaths
                cmd = [cmd ' --nopaths'];
            end
            cmds = [cmds cmd];
        end
    end
    
    % verify
    disp('About to run the following commands: ');
    for ii = 1:numel(cmds)
        disp(['   mpm ' opts.action ' ' cmds{ii}]);
    end
    reply = input('Confirm (y/n)? ', 's');
    if isempty(reply)
        reply = 'y';
    end
    if ~strcmpi(reply(1), 'y')
        disp('I saw nothing.');
        return;
    end
    
    % run all
    for ii = 1:numel(cmds)
        cmd = strsplit(cmds{ii});
        mpm(opts.action, cmd{:});
    end
end
