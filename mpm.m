function mpm(action, varargin)
%MPM Matlab Package Manager
% function mpm(ACTION, varargin)
% 
% ACTION can be any of the following:
%   'init'      add all installed packages in default install directory to
%       path
%   'search'    finds a url for a package by name (searches Github and File Exchange)
%   'install'   installs a package by name
%   'uninstall' installs a package by name
%   'freeze'    list all installed packages (optional: in installdir)
%   'set'       change options for an already installed package
%
% If ACTION is one of 'search', 'install', or 'uninstall', then you must
% provide a package NAME as the next argument (e.g., 'matlab2tikz')
%
%
% Examples:
%
%   % Search for a package called 'test' on Matlab File Exchange
%   mpm search test
% 
%   % Install a package called 'test'
%   mpm install test
% 
%   % Uninstall a package called 'test'
%   mpm uninstall test
%
%   % List all installed packages
%   mpm freeze
%
%   % Add all installed packages to the path (e.g., run this at startup)
%   mpm init
%   
%   % Change the folder added to the path in an already installed package
%   mpm set test -n folder_name_to_add
%
% To modify the default behavior of the above commands,
% the following optional arguments are available: 
%
% name-value arguments:
%   url (-u): optional; if does not exist, must search
%   infile (-i): if set, will run mpm on all packages listed in file
%   installdir (-d): where to install package
%   query (-q): if name is different than query
%   release_tag (-t): if url is found on github, this lets user set release tag
%   internaldir (-n): lets user set which directories inside package to add to path
%   collection (-c): override mpm's default package collection ("default")
%   by specifying a custom collection name
%
% arguments that are true if passed (otherwise they are false):
%   --githubfirst (-g): check github for url before matlab fileexchange
%   --force (-f): install package even if name already exists in InstallDir
%   --debug: do not install anything or update paths; just pretend
%   --nopaths: no paths are added after installing (default if -c is specified)
%   --allpaths: add path to all subfolders in package
%   --local: url is a path to a local directory to install (add '-e' to not copy)
% 
% For more help, or to report an issue, see <a href="matlab: 
% web('https://github.com/mobeets/mpm')">the mpm Github page</a>.
%

    % print help info if no arguments were provided
    if nargin < 1
        run('help(''mpm'')');
        return;
    end
    
    % parse and validate command line args
    [pkg, opts] = setDefaultOpts();
    [pkg, opts] = parseArgs(pkg, opts, action, varargin);
    validateArgs(pkg, opts);
    if opts.debug
        warning(['Debug mode. No packages will actually be installed, ' ...
            'or added to metadata or paths.']);
    end
    disp(['Using collection "' opts.collection '"']);
    
    % installing from requirements
    if ~isempty(opts.infile)
        % read filename, and call mpm for all lines in this file
        readRequirementsFile(opts.infile, opts);
        return;        
    end
    
    % load metadata
    [opts.metadata, opts.metafile] = getMetadata(opts);
    
    % mpm init
    if strcmpi(opts.action, 'init')
        opts.update_mpm_paths = true;
        updatePaths(opts);
        return;
    end
    
    % mpm freeze
    if strcmpi(opts.action, 'freeze')
        listPackages(opts);
        return;
    end
    
    % mpm set
    if strcmpi(opts.action, 'set')
        changePackageOptions(pkg, opts);
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
    if ~opts.force && ~strcmpi(opts.action, 'search') && ...
            ~isempty(indexInMetadata(pkg, opts.metadata.packages))
        warning(['   Package already exists. ' ...
            'Re-run with --force to overwrite.']);
        success = false;
        return;
    end    
    
    % find url if not set
    if isempty(pkg.url)
        pkg.url = findUrl(pkg, opts);
    end
    
    % download package and add to metadata
    if ~isempty(pkg.url) && strcmpi(opts.action, 'install')
        if ~opts.local_install
            disp(['   Downloading ' pkg.url '...']);
        else
            disp(['   Installing local package ' pkg.url '...']);
        end
        [pkg, isOk] = installPackage(pkg, opts);
        if ~isempty(pkg) && isOk
            opts = addToMetadata(pkg, opts);
            if ~opts.nopaths
                disp('Updating paths...');
                updatePath(pkg, opts);
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
        
        % check for uninstall file
        pth = fullfile(pkg.installdir, pkg.mdir);
        checkForFileAndRun(pth, 'uninstall.m', opts);
        
        if exist(pkg.installdir, 'dir')
            % remove old directory
            if ~pkg.no_rmdir_on_uninstall
                rmdir(pkg.installdir, 's');
            else
                disp(['Not removing directory because ' ...
                    'it was pre-existing before install: "' ...
                    pkg.installdir '"']);
            end
        end
    end
    
    % write new metadata to file
    packages = pkgs(~ix);
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
    
    disp('Uninstallation complete.');
end

function changePackageOptions(pkg, opts)
    % find existing package
    pkgs = opts.metadata.packages;
    [~, ix] = indexInMetadata(pkg, pkgs);
    if ~any(ix)
        warning(['   No previous versions of ''' pkg.name ...
            ''' installed by mpm were found.']);
        return;
    end
    assert(sum(ix) == 1, ...
        'internal error: multiple packages found by name');
    old_pkg = pkgs(ix);
    
    % update options
    if opts.nopaths
        disp(['Updating "' pkg.name '" so that no paths will be added.']);
        old_pkg.addpath = false;
    end
    if pkg.add_all_dirs_to_path
        disp(['Updating "' pkg.name ...
            '" so that all internal directories will be added to the path.']);
        old_pkg.add_all_dirs_to_path = true;
        if ~old_pkg.addpath
            disp(['Paths were previously not being added for this' ...
                ' package. Now they will be.']);
            old_pkg.addpath = true;
        end
    end
    if ~isempty(pkg.internaldir)        
        if exist(fullfile(old_pkg.installdir, pkg.internaldir), 'dir')
            old_pkg.mdir = pkg.internaldir;
            old_pkg.internaldir = pkg.internaldir;
            disp(['Updating "' pkg.name ...
                '" so that the internal directory "' pkg.internaldir ...
                '" will be added to the path.']);
            if ~old_pkg.addpath
                disp(['Paths were previously not being added for this' ...
                    ' package. Now they will be.']);
                old_pkg.addpath = true;
            end
        else
            fldrs = dir(old_pkg.installdir);
            fldrs = {fldrs([fldrs.isdir] == 1).name};
            if numel(fldrs) == 0
                warning(['Ignoring internaldir because ' ...
                    'there are no internal folders to add']);
            else
                warning(['Ignoring internaldir because ' ...
                    'it did not exist in package. Valid options are:']);
                disp(fldrs);
            end
        end
    end
    
    % write new metadata to file
    pkgs(ix) = old_pkg;
    packages = pkgs;
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
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
        out = ['- ' nm ' (' pkg.date_downloaded ')'];
        cdir = fileparts(pkg.installdir);
        if ~strcmpi(cdir, opts.installdir)
            out = [out ': ' pkg.installdir];
        end
        disp(out);
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
    pkg.local_install = false;
    pkg.no_rmdir_on_uninstall = false;
    pkg.add_all_dirs_to_path = false;
    pkg.collection = 'default';
    
    opts = mpm_config(); % load default opts from config file
    opts.installdir = opts.DEFAULT_INSTALL_DIR;
    opts.metadir = opts.DEFAULT_INSTALL_DIR;
    opts.searchgithubfirst = opts.DEFAULT_CHECK_GITHUB_FIRST;
    opts.update_mpm_paths = false;    
    opts.update_all_paths = false;    
    opts.local_install = false;
    opts.local_install_uselocal = false;
    opts.add_all_dirs_to_path = false;
    
    opts.infile = '';    
    opts.force = false;
    opts.debug = false;
    opts.nopaths = false;
    opts.collection = pkg.collection;    
end

function url = handleCustomUrl(url)
    
    % if .git url, must remove and add /zipball/master
    inds = strfind(url, '.git');
    if isempty(inds)
        inds = strfind(url, '?download=true');
        if isempty(inds)
            url = [url '?download=true'];            
        end
        return;
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

    query = pkg.query;
    if isempty(query)
        query = pkg.name;
    end
    
    % query file exchange
    base_url = 'http://www.mathworks.com/matlabcentral/fileexchange/';
    html = webread(base_url, 'term', query);
    
    % extract all hrefs from '<a href="*" class="results_title">'
    expr = 'class="results_title"[^>]*href="([^"]*)"[^>]*|href="([^"]*)"[^>]*class="results_title"';
    tokens = regexp(html, expr, 'tokens');
    
    % return first result
    if ~isempty(tokens)
        url = tokens{1}{1};
        url = [url '?download=true'];
%         url_format = @(aid, ver) ['https://www.mathworks.com/' ...
%             'matlabcentral/mlc-downloads/downloads/submissions/' aid ...
%             '/versions/' version '/download/zip'];
%         url = url_format(aid, '101'); % 101 works for all? we'll see
    else
        url = '';
    end
end

function url = findUrlOnGithub(pkg)
% searches github for matlab repositories
%   - if release_tag is set, get url of release that matches
%   - otherwise, get url of most recent release
%   - and if no releases exist, get url of most recent commit
%

    url = '';
    query = pkg.query;
    if isempty(query)
        query = pkg.name;
    end
    
    % query github for matlab repositories
    % https://developer.github.com/v3/search/#search-repositories
    % ' ' will be replaced by '+', which seems necessary
    % ':' for search qualifiers can be sent encoded on the other hand
    q_url = 'https://api.github.com/search/repositories';
    q_req = [query, ' language:matlab'];
    html = webread(q_url, 'q', q_req);
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

function [pkg, isOk] = installPackage(pkg, opts)
% install package by downloading url, unzipping, and finding paths to add    
    
    if opts.debug
        isOk = false;
        return;
    end
    isOk = true;
    
    % check for previous package
    if exist(pkg.installdir, 'dir') && ~opts.force
        warning(['   Could not install because folder already exists.', ...
            ' Try adding "-f" to force.']);
        isOk = false;
        return;
    elseif exist(pkg.installdir, 'dir')
        % remove old directory
        disp('   Removing previous version from disk.');
        rmdir(pkg.installdir, 's');
    end
    
    if ~opts.local_install && ~isempty(strfind(pkg.url, '.git')) && ...
            isempty(strfind(pkg.url, 'github.com'))
        % install with git clone because not on github
        isOk = checkoutFromUrl(pkg);
        if ~isOk
            warning('Error using git clone');
        end
    elseif ~opts.local_install
        % download zip
        pkg.url = handleCustomUrl(pkg.url);
        [isOk, pkg] = unzipFromUrl(pkg);
        if ~isOk && ~isempty(strfind(pkg.url, 'github.com')) && ...
            isempty(strfind(pkg.url, '.git'))
            warning(['If you were trying to install a github repo, ', ...
                'try adding ".git" to the end.']);
        elseif ~isOk
            warning('Error downloading zip.');
        end
    else % local install (using pre-existing local directory)
        % make sure path exists
        if ~exist(pkg.url, 'dir')
            warning(['Provided path to local directory does not ' ...
                'exist: "' pkg.url '"']);
            isOk = false; return;
        end
        
        % copy directory to installdir
        if ~opts.local_install_uselocal
            if ~exist(pkg.url, 'dir')
                warning(['Could not find directory: "' ...
                    pkg.url '." Try providing absolute path.']);
                isOk = false; return;
            end
            mkdir(pkg.installdir);
            isOk = copyfile(pkg.url, pkg.installdir);
            if ~isOk
                warning('Error copying directory.');
            end
        else % no copy; just track the provided path
            % make sure we have absolute path
            if ~isempty(strfind(pkg.url, pwd))
                abspath = pkg.url;
            else % try making it ourselves
                abspath = fullfile(pwd, pkg.url);
            end
            if ~exist(abspath, 'dir')
                warning(['Could not find directory: "' ...
                    abspath '." Try providing absolute path.']);
                isOk = false; return;
            else
                pkg.installdir = abspath;
            end
        end
    end
    if ~isOk
        warning('   Could not install.');
        return;
    end
    pkg.date_downloaded = datestr(datetime);
    pkg.mdir = findMDirOfPackage(pkg);
    
    if isOk
        % check for install.m and run after confirming
        pth = fullfile(pkg.installdir, pkg.mdir);
        checkForFileAndRun(pth, 'install.m', opts);
    end
    
end

function isOk = checkoutFromUrl(pkg)
% git checkout from url to installdir
    isOk = true;
    flag = system(['git clone ', pkg.url, ' "', pkg.installdir, '"']);
    
    if (flag ~= 0)
        isOk = false;
        warning(['git clone of URL ', pkg.url, ' failed.' ...
            ' (Is ''git'' is installed on your system?)']);
    end
end

function [isOk, pkg] = unzipFromUrl(pkg)
% download from url to installdir
    isOk = true;
    
    zipfnm = [tempname '.zip'];
    try
        zipfnm = websave(zipfnm, pkg.url);
    catch ME
        % handle 404 from File Exchange for getting updated download url
        ps = strsplit(ME.message, 'for URL');
        if numel(ps) < 2
            isOk = false; return;
        end
        ps = strsplit(ps{2}, 'github_repo.zip');
        pkg.url = ps{1}(2:end);
        zipfnm = websave(zipfnm, pkg.url);
    end
    try
        unzip(zipfnm, pkg.installdir);
    catch
        isOk = false; return;
    end

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
        try
            movefile(fullfile(drnm, '*'), pkg.installdir);
        catch % hack for handling packages like cbrewer 34087
            movefile(fullfile(drnm, pkg.name, '*'), pkg.installdir);
        end
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
            mdir = pkg.internaldir;
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
    warning(['Could not find folder with .m files, ' ...
        'so nothing will be added to the path.']);
    disp(sprintf([...
        'You can manually specify which folder to add to ' ...
        'the path by running: \n' ...
        '   >> mpm set ' pkg.name ' -n [foldername]\n' ...
        'The following are internal folder names that ' ...
        'you can add with this command: ']));
    fldrs = dir(pkg.installdir);
    foldernames = {fldrs([fldrs.isdir] == 1).name};
    foldernames
    mdir = '';
end

function [m, metafile] = getMetadata(opts)

    metafile = fullfile(opts.metadir, 'mpm.mat');
    if exist(metafile, 'file')
        m = load(metafile);
    else
        m = struct();
    end
    if ~isfield(m, 'packages')
        m.packages = [];
    end
    pkgs = m.packages;
    default_pkg = setDefaultOpts();
    allfnms = fieldnames(default_pkg);
    
    clean_pkgs = [];
    for ii = 1:numel(pkgs)
        pkg = pkgs(ii);
        
        % set any missing fields to default value
        missing_fields = setdiff(allfnms, fieldnames(pkg));
        for jj = 1:numel(missing_fields)
            cfld = missing_fields{jj};
            pkg.(cfld) = default_pkg.(cfld);
        end

        % handle manually-deleted packages by skipping if dir doesn't exist
        pth = fullfile(pkg.installdir, pkg.mdir);
        if exist(pth, 'dir')
            clean_pkgs = [clean_pkgs pkg];
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

function updatePaths(opts)
% read metadata file and add all paths listed
    
    % add mdir to path for each package in metadata (optional)
    nmsAdded = {};
    if opts.update_mpm_paths
        pkgs = opts.metadata.packages;
        for ii = 1:numel(pkgs)
            success = updatePath(pkgs(ii), opts);
            if success
                nmsAdded = [nmsAdded pkgs(ii).name];
            end
        end
    end
    if numel(pkgs) == 0
        disp('   No packages found in collection.');
    else
        disp(['   Added paths for ' num2str(numel(nmsAdded)) ...
            ' package(s).']);
    end
    
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
        
        % add all folders to path
        if pkg.add_all_dirs_to_path
            disp('   Also adding paths to all sub-folders (--allpaths).');
            addpath(genpath(pth));
            
        else % check for pathlist.m file
            pathfile = fullfile(pth, 'pathlist.m');
            paths_to_add = checkForPathlistAndGenpath(pathfile, pth);
            if numel(paths_to_add) > 0 && ~opts.debug
                disp('   Also adding paths found in pathlist.m');
                addpath(paths_to_add);
            end
        end
    else
        warning(['Path to package does not exist: ' pth]);
        return;
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
    validActions = {'install', 'search', 'uninstall', 'init', ...
        'freeze', 'set'};
    checkAction = @(x) any(validatestring(x, validActions));
    addRequired(q, 'action', checkAction);
    defaultName = '';
    addOptional(q, 'remainingargs', defaultName);
    parse(q, action, varargin{:});
    opts.action = q.Results.action;
    remainingArgs = q.Results.remainingargs;
    
    allParams = {'url', 'infile', 'installdir', 'internaldir', ...
        'release_tag', '--githubfirst', '--force', ...
        '--nopaths', '--allpaths', '--local', '-e', 'collection', '-c', ...
        '-u', '-q', '-i', '-d', '-n', '-t', '-g', '-f', '--debug'};
    
    % no additional args
    if numel(remainingArgs) == 0
        if strcmpi(opts.action, 'freeze') || strcmpi(opts.action, 'init')
            pkg.query = '';
            return;
        else
            error('You must specify a package name or a filename.');
        end
    end
    
    % if first arg is not a param name, it's the package name
    nextArg = remainingArgs{1};
    if ~ismember(lower(nextArg), lower(allParams))
        pkg.name = nextArg;
        pkg.query = '';
        remainingArgs = remainingArgs(2:end);
    else
        pkg.name = '';
        pkg.query = '';
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
        elseif strcmpi(curArg, 'Query') || strcmpi(curArg, '-q')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            pkg.query = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'Infile') || strcmpi(curArg, '-i')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.infile = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'InstallDir') || strcmpi(curArg, '-d')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.installdir = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'Collection') || strcmpi(curArg, '-c')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.collection = nextArg;
            pkg.collection = nextArg;
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
        elseif strcmpi(curArg, '--allpaths')
            pkg.add_all_dirs_to_path = true;
            opts.add_all_dirs_to_path = true;
        elseif strcmpi(curArg, '--local')
            opts.local_install = true;
            pkg.local_install = true;
        elseif strcmpi(curArg, '-e')
            opts.local_install_uselocal = true;
            pkg.no_rmdir_on_uninstall = true;
        else
            error(['Did not recognize argument ''' curArg '''.']);
        end
    end
    
    % update metadir, if collection was set
    if ~strcmpi(opts.collection, 'default')
        opts.metadir = fullfile(opts.metadir, 'mpm-collections', ...
            opts.collection);
        opts.installdir = opts.metadir;
        if strcmpi(opts.action, 'install')
            opts.nopaths = true;
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
        assert(isempty(pkg.query), ...
            'Cannot specify query if uninstalling');
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
        assert(isempty(pkg.query), ...
            'Cannot specify query when running ''freeze''');
        assert(isempty(pkg.internaldir), ...
            'Cannot specify internaldir when running ''freeze''');
        assert(isempty(pkg.release_tag), ...
            'Cannot specify release_tag when running ''freeze''');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst when running ''freeze''');
    end
    if strcmpi(opts.action, 'set')
        assert(~opts.force, 'Nothing to force when running ''set''.');
        assert(isempty(pkg.url), ...
            'Cannot specify url when running ''set''');
        assert(isempty(pkg.query), ...
            'Cannot specify query when running ''set''');
        assert(isempty(pkg.release_tag), ...
            'Cannot specify release_tag when running ''set''');
        assert(~opts.searchgithubfirst, ...
            'Cannot set searchgithubfirst when running ''set''');
    end
    if opts.local_install
        assert(~isempty(pkg.url), ...
            'Must specify local path with -u when running ''--local''');
    end
    if opts.local_install_uselocal
        assert(opts.local_install, ...
            'Can only specify -e when running ''--local''');
    end
end

function readRequirementsFile(fnm, opts)
    txt = fileread(fnm);
    lines = strsplit(txt, '\n');
    
    % build list of commands to run
    % and check for illegal params (note spaces)
    illegalParams = {' -i ', ' infile ', ' installdir ', ' -c '};
    cmds = {};    
    for ii = 1:numel(lines)
        line = lines{ii};
        for jj = 1:numel(illegalParams)
            if ~isempty(strfind(line, illegalParams{jj}))
                error(['Line ' num2str(ii) ...
                    ' in infile cannot contain ''' illegalParams{jj} ...
                    '''. (Illegal arguments: ''-i'',' ...
                    '''infile'',  ''installdir'', ''-c''.)']);
            end
        end
        
        % if args are specified inside file, don't allow specifying w/ opts
        if opts.force && (~isempty(strfind(line, ' --force')) || ...
                ~isempty(strfind(line, ' -f')))
            error('Cannot set --force because it is in infile.');
        end
        if opts.nopaths && ~isempty(strfind(line, ' --nopaths'))
            error('Cannot set --nopaths because it is in infile.');
        end
        if opts.add_all_dirs_to_path && ~isempty(strfind(line, ' --allpaths'))
            error('Cannot set --allpaths because it is in infile.');
        end
        if opts.local_install && ~isempty(strfind(line, ' --local'))
            error('Cannot set --local because it is in infile.');
        end
        if opts.local_install_uselocal && ~isempty(strfind(line, ' -e'))
            error('Cannot set -e because it is in infile.');
        end
        
        % now append opts as globals for each line in file
        if ~isempty(line)
            cmd = [line ' -d ' opts.installdir ' -c ' opts.collection];
            if opts.force
                cmd = [cmd ' --force'];
            end
            if opts.nopaths
                cmd = [cmd ' --nopaths'];
            end
            if opts.add_all_dirs_to_path
                cmd = [cmd ' --allpaths'];
            end
            if opts.local_install
                cmd = [cmd ' --local'];
            end
            if opts.local_install_uselocal
                cmd = [cmd ' -e'];
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

function checkForFileAndRun(installdir, fnm, opts)
    fpath = fullfile(installdir, fnm);
    
    % check for install file and read comments at top
    fid = fopen(fpath);
    if fid == -1
        return;
    end
    lines = {};
    line = '%';
    while ~isnumeric(line) && numel(line) > 0 && strcmpi(line(1), '%')
        line = fgetl(fid);
        if ~isnumeric(line) && numel(line) > 0 && strcmpi(line(1), '%')
            lines = [lines line];
        end
    end
    if fid ~= -1
        fclose(fid);
    end
    
    % verify
    disp([fnm ' file found at ' fpath]);
    if numel(lines) > 0
        disp('Showing first lines of comments:');
        disp(strjoin(lines, '\n'));
    end
    if ~opts.force
        reply = input(['Run ' fnm ' (y/n)? '], 's');
        if isempty(reply)
            reply = 'y';
        end
        if ~strcmpi(reply(1), 'y')
            disp(['Skipping ' fnm '.']);
            return;
        end
        disp(['Running ' fnm ' ...']);
    else
        disp(['Running ' fnm ' (--force was on)...']);
    end
    
    % run
    run(fpath);
end

function pathlist = checkForPathlistAndGenpath(fpath, basedir)
    
    pathlist = '';
    
    fid = fopen(fpath);
    if fid == -1
        return;
    end

    line = '';
    while ~isnumeric(line)
        line = fgetl(fid);
        if ~isnumeric(line) && numel(line) > 0
            if strcmpi(line(end), '*')
                % e.g., etc/* => etc/x:
                curpath = genpath(fullfile(basedir, line(1:end-1)));
            else
                % add just this one dir
                curpath = [fullfile(basedir, line) ':'];
            end
            pathlist = [pathlist curpath];
        end
    end
    
    if fid ~= -1
        fclose(fid);
    end
end
