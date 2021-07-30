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
%   'freeze'    list all installed packages (optional: in install-dir)
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
%   in-file (-i): if set, will run mpm on all packages listed in file
%   install-dir (-d): where to install package
%   query (-q): if name is different than query
%   release-tag (-t): if url is found on github, this lets user set release tag
%   internal-dir (-n): lets user set which directories inside package to add to path
%   collection (-c): override mpm's default package collection ("default")
%     by specifying a custom collection name
%
% arguments that are true if passed (otherwise they are false):
%   --github-first (-gh): check github for url before matlab fileexchange
%   --force (-f): install package even if name already exists in InstallDir
%   --approve: when using -i, auto-approve the installation without confirming
%   --debug: do not install anything or update paths; just pretend
%   --no-paths: no paths are added after installing (default if -c is specified)
%   --all-paths: add path to all subfolders in package
%   --local: url is a path to a local directory to install (add '-e' to not copy)
%   --use-local (-e): skip copy operation during local install
% 
% For more help, or to report an issue, see <a href="matlab: 
% web('https://github.com/mobeets/mpm')">the mpm Github page</a>.
%

    % print help info if no arguments were provided
    if nargin < 1
        help mpm;
        return;
    end

    % parse and validate command line args
    [package, opts] = setDefaultOpts();
    [package, opts] = parseArgs(package, opts, action, varargin);
    validateArgs(package, opts);
    if opts.debug
        warning('Debug mode. No packages will actually be installed, or added to metadata or paths.');
    end
    disp(['Using collection ''' opts.collection '''.']);

    % installing from requirements
    if ~isempty(opts.inFile)
        % read filename, and call mpm for all lines in this file
        readRequirementsFile(opts.inFile, opts);
        return;        
    end

    % load metadata
    [opts.metadata, opts.metafile] = getMetadata(opts);

    % mpm init
    if strcmpi(opts.action, 'init')
        opts.updateMpmPaths = true;
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
        changePackageOptions(package, opts);
        return;
    end

    % mpm uninstall
    if strcmpi(opts.action, 'uninstall')
        removePackage(package, opts);
        return;
    end

    % mpm search OR mpm install
    findAndSetupPackage(package, opts);
end

function success = findAndSetupPackage(package, opts)    
    success = true;
    package.installDir = fullfile(opts.installDir, package.name);
    disp(['Collecting ''' package.name '''...']);

    % check if exists
    if ~opts.force && ~strcmpi(opts.action, 'search') && ~isempty(indexInMetadata(package, opts.metadata.packages))
        warning('   Package already exists. Re-run with --force to overwrite.');
        success = false;
        return;
    end    

    % find url if not set
    if isempty(package.url)
        package.url = findUrl(package, opts);
    end

    % download package and add to metadata
    if ~isempty(package.url) && strcmpi(opts.action, 'install')
        if ~opts.localInstall
            disp(['   Downloading ' package.url '...']);
        else
            disp(['   Installing local package ' package.url '...']);
        end
        [package, isOk] = installPackage(package, opts);
        if ~isempty(package) && isOk
            opts = addToMetadata(package, opts);
            if ~opts.noPaths
                disp('Updating paths...');
                updatePath(package, opts);
            end
        end
    end
end

function removePackage(package, opts)
    packages = opts.metadata.packages;
    [~, ix] = indexInMetadata(package, packages);
    if ~any(ix)
        disp(['   No previous versions of ''' package.name ''' installed by mpm were found.']);
        return;
    end

    % delete package directories if they exist
    removalQueue = packages(ix);
    disp(['   Removing ' num2str(sum(ix)) ' package(s) named ''' package.name '''.']);
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
    for ii = 1:numel(removalQueue)
        package = removalQueue(ii);

        % check for uninstall file
        pth = fullfile(package.installDir, package.mdir);
        checkForFileAndRun(pth, 'uninstall.m', opts);

        if exist(package.installDir, 'dir')
            % remove old directory
            if ~package.noRmdirOnUninstall
                rmdir(package.installDir, 's');
            else
                installDir = package.installDir;
                disp(['Not removing directory because  it was pre-existing before install: ''' installDir '''']);
            end
        end
    end

    % write new metadata to file
    packages = packages(~ix);
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end

    disp('Uninstallation complete.');
end

function changePackageOptions(package, opts)
    % find existing package
    packageMetadata = opts.metadata.packages;
    [~, ix] = indexInMetadata(package, packageMetadata);
    if ~any(ix)
        packageName = package.name;
        warning(['   No previous versions of ''' packageName ''' installed by mpm were found.']);
        return;
    end
    assert(sum(ix) == 1, 'internal error: multiple packages found by name');
    oldPackage = packageMetadata(ix);

    % update options
    if opts.nopaths
        disp(['Updating ''' package.name ''' so that no paths will be added.']);
        oldPackage.addPath = false;
    end
    if package.addAllDirsToPath
        disp(['Updating ''' package.name ''' so that all internal directories will be added to the path.']);
        oldPackage.addAllDirsToPath = true;
        if ~oldPackage.addPath
            disp('Paths were previously not being added for this package. Now they will be.');
            oldPackage.addPath = true;
        end
    end
    if ~isempty(package.internalDir)        
        if exist(fullfile(oldPackage.installDir, package.internalDir), 'dir')
            oldPackage.mdir = package.internalDir;
            oldPackage.internalDir = package.internalDir;
            disp(['Updating ''' package.name ''' so that the internal directory ''' package.internalDir ''' will be added to the path.']);
            if ~oldPackage.addPath
                disp('Paths were previously not being added for this package. Now they will be.');
                oldPackage.addPath = true;
            end
        else
            fldrs = dir(oldPackage.installDir);
            fldrs = {fldrs([fldrs.isdir] == 1).name};
            if numel(fldrs) == 0
                warning('Ignoring internal-dir because there are no internal folders to add');
            else
                warning('Ignoring internal-dir because it did not exist in package. Valid options are:');
                disp(fldrs);
            end
        end
    end

    % write new metadata to file
    packageMetadata(ix) = oldPackage;
    packages = packageMetadata;
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
end

function listPackages(opts)
    packages = opts.metadata.packages;
    if isempty(packages)
        disp(['No packages currently installed to ' opts.installDir]);
        return;
    end
    disp(['Packages currently installed to ' opts.installDir ':']);
    for ii = 1:numel(packages)
        package = packages(ii);
        packageName = package.name;
        if ~isempty(package.releaseTag)
            packageName = [packageName '==' package.releaseTag]; %#ok<*AGROW>
        end
        out = ['- ' packageName ' (' package.downloadDate ')'];
        cdir = fileparts(package.installDir);
        if ~strcmpi(cdir, opts.installDir)
            out = [out ': ' package.installDir];
        end
        disp(out);
    end
end

function [package, opts] = setDefaultOpts()
% load opts from config file, and then set additional defaults    

    % empty package
    package.name = '';
    package.url = '';
    package.internalDir = '';
    package.releaseTag = '';
    package.addPath = true;
    package.localInstall = false;
    package.noRmdirOnUninstall = false;
    package.addAllDirsToPath = false;
    package.collection = 'default';

    opts = mpm_config(); % load default opts from config file
    opts.installDir = opts.DEFAULT_INSTALL_DIR;
    opts.metadir = opts.DEFAULT_INSTALL_DIR;
    opts.searchGithubFirst = opts.DEFAULT_CHECK_GITHUB_FIRST;
    opts.updateMpmPaths = false;    
    opts.updateAllPaths = false;    
    opts.localInstall = false;
    opts.localInstallUseLocal = false;
    opts.addAllDirsToPath = false;
    opts.installDirOverride = false; % true if user sets using -d

    opts.inFile = '';    
    opts.force = false;
    opts.approve = false;
    opts.debug = false;
    opts.noPaths = false;
    opts.collection = package.collection;    
end

function url = handleCustomUrl(url, releaseTag)

    % if .git url, must remove and add /zipball/master
    inds = strfind(url, '.git'); % want to match this
    inds = setdiff(inds, strfind(url, '.github')); % ignore matches to '.github'
    if isempty(inds)
        inds = strfind(url, '?download=true');
        if isempty(inds) %#ok<*STREMP>
           url = [url '?download=true'];
        end
        return;
    end
    ind = inds(end);
    if ~isempty(releaseTag)
        release = ['/zipball/', releaseTag];
    else
        release = '/zipball/master';
    end
    url = [url(1:ind-1) release url(ind+4:end)];

end

function url = findUrl(package, opts)
% find url by searching matlab fileexchange and github given opts.name

    if ~isempty(package.releaseTag) % tag set, so search github only
        url = findUrlOnGithub(package);
    elseif opts.searchGithubFirst
        url = findUrlOnGithub(package);
        if isempty(url) % if nothing found, try file exchange
            url = findUrlOnFileExchange(package);
        end
    else
        url = findUrlOnFileExchange(package);
        if isempty(url) % if nothing found, try github
            url = findUrlOnGithub(package);
        end
    end
    if isempty(url)
        disp('   Could not find url.');
    else
        disp(['   Found url: ' url]);
    end
end

function url = findUrlOnFileExchange(package)
% search file exchange, and return first search result

    query = package.query;
    if isempty(query)
        query = package.name;
    end

    % query file exchange
    baseUrl = 'http://www.mathworks.com/matlabcentral/fileexchange/';
    html = webread(baseUrl, 'term', query);

    % extract all hrefs from '<h3><a href="/matlabcentral/fileexchange/">'
    expr = '<h3>[^<]*<a href="/matlabcentral/fileexchange/([^"]*)">([^"]*)</a>';
    tokens = regexp(html, expr, 'tokens');

    % if any packages contain package name exactly, return that one
    for ii = 1:numel(tokens) 
        curName = lower(strrep(strrep(tokens{ii}{2}, '<mark>', ''), '</mark>', ''));
        if ~isempty(strfind(curName, lower(query)))
            url = [baseUrl tokens{ii}{1} '&download=true'];
            return;
        end
    end

    % return first result
    if ~isempty(tokens)
        url = tokens{1}{1};
        url = [baseUrl url '&download=true'];
%         urlFormat = @(aid, ver) [ ...
%             'https://www.mathworks.com/' ...
%             'matlabcentral/mlc-downloads/downloads/submissions/' aid ...
%             '/versions/' version '/download/zip' ...
%         ];
%         url = urlFormat(aid, '101'); % 101 works for all? we'll see
    else
        url = '';
    end
end

function url = findUrlOnGithub(package)
% searches github for matlab repositories
%   - if releaseTag is set, get url of release that matches
%   - otherwise, get url of most recent release
%   - and if no releases exist, get url of most recent commit
%

    url = '';
    query = package.query;
    if isempty(query)
        query = package.name;
    end

    % query github for matlab repositories
    % https://developer.github.com/v3/search/#search-repositories
    % ' ' will be replaced by '+', which seems necessary
    % ':' for search qualifiers can be sent encoded on the other hand
    qUrl = 'https://api.github.com/search/repositories';
    qReq = [query, ' language:matlab'];
    html = webread(qUrl, 'q', qReq);
    if isempty(html) || ~isfield(html, 'items') || isempty(html.items)
        return;
    end

    % take first repo
    item = html.items(1);

    if ~isempty(package.releaseTag)
        % if release tag set, return the release matching this tag
        url = [item.url '/zipball/' package.releaseTag];
    else
        relUrl = [item.url '/releases/latest'];
        try
            res = webread(relUrl);
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

function [package, isOk] = installPackage(package, opts)
% install package by downloading url, unzipping, and finding paths to add    

    if opts.debug
        isOk = false;
        return;
    end
    isOk = true;

    % check for previous package
    if exist(package.installDir, 'dir') && ~opts.force
        warning(['   Could not install because folder already exists.', ' Try adding "-f" to force.']);
        isOk = false;
        return;
    elseif exist(package.installDir, 'dir')
        % remove old directory
        disp('   Removing previous version from disk.');
        rmdir(package.installDir, 's');
    end

    if ~opts.localInstall && ~isempty(strfind(package.url, '.git')) && isempty(strfind(package.url, 'github.com'))
        % install with git clone because not on github
        isOk = checkoutFromUrl(package);
        if ~isOk
            warning('Error using git clone');
        end
    elseif ~opts.localInstall
        % download zip
        package.url = handleCustomUrl(package.url, package.releaseTag);
        [isOk, package] = unzipFromUrl(package);
        if ~isOk && ~isempty(strfind(package.url, 'github.com')) && isempty(strfind(package.url, '.git'))
            warning('If you were trying to install a github repo, try adding ".git" to the end.');
        elseif ~isOk
            warning('Error downloading zip.');
        end
    else % local install (using pre-existing local directory)
        % make sure path exists
        if ~exist(package.url, 'dir')
            warning(['Provided path to local directory does not exist: ''' package.url '''']);
            isOk = false; return;
        end

        % copy directory to installDir
        if ~opts.localInstallUseLocal
            if ~exist(package.url, 'dir')
                warning(['Could not find directory: ''' package.url '." Try providing absolute path.']);
                isOk = false; return;
            end
            mkdir(package.installDir);
            isOk = copyfile(package.url, package.installDir);
            if ~isOk
                warning('Error copying directory.');
            end
        else % no copy; just track the provided path
            % make sure we have absolute path
            if ~isempty(strfind(package.url, pwd))
                abspath = package.url;
            else % try making it ourselves
                abspath = fullfile(pwd, package.url);
            end
            if ~exist(abspath, 'dir')
                warning(['Could not find directory: ''' abspath '." Try providing absolute path.']);
                isOk = false; return;
            else
                package.installDir = abspath;
            end
        end
    end
    if ~isOk
        warning('   Could not install.');
        return;
    end
    package.downloadDate = datestr(datetime);
    package.mdir = findMDirOfPackage(package);

    if isOk
        % check for install.m and run after confirming
        pth = fullfile(package.installDir, package.mdir);
        checkForFileAndRun(pth, 'install.m', opts);
    end

end

function isOk = checkoutFromUrl(package)
% git checkout from url to installDir
    isOk = true;
    if ~isempty(package.releaseTag)
        flag = system(['git clone --depth 1 --branch ', package.releaseTag, ' ', package.url, ' ''', package.installDir, '''']);
    else
        flag = system(['git clone --depth 1 ', package.url, ' ''', package.installDir, '''']);
    end
    if (flag ~= 0)
        isOk = false;
        warning(['git clone of URL ', package.url, ' failed. (Is ''git'' is installed on your system?)']);
    end
end

function [isOk, package] = unzipFromUrl(package)
% download from url to installDir
    isOk = true;

    zipFileName = [tempname '.zip'];
    try
        zipFileName = websave(zipFileName, package.url);
    catch ME
        % handle 404 from File Exchange for getting updated download url
        ps = strsplit(ME.message, 'for URL');
        if numel(ps) < 2
            isOk = false; return;
        end
        ps = strsplit(ps{2}, 'github_repo.zip');
        package.url = ps{1}(2:end);
        zipFileName = websave(zipFileName, package.url);
    end
    try
        unzip(zipFileName, package.installDir);
    catch
        isOk = false; return;
    end

    folderNames = dir(package.installDir);
    numFolderNames = numel(folderNames);
    ndirs = sum([folderNames.isdir]);
    if ...
        ((numFolderNames == 3) && (ndirs == 3)) ...
        || ((numFolderNames == 4) && (ndirs == 3) ...
        && strcmpi(folderNames(~[folderNames.isdir]).name, 'license.txt'))
        % only folders are '.', '..', and package folder (call it dirName)
        %       and then maybe a license file, 
        %       so copy the subtree of dirName and place inside installDir
        fldrs = folderNames([folderNames.isdir]);
        fldr = fldrs(end).name;
        dirName = fullfile(package.installDir, fldr);
        try
            movefile(fullfile(dirName, '*'), package.installDir);
        catch % hack for handling packages like cbrewer 34087
            movefile(fullfile(dirName, package.name, '*'), package.installDir);
        end
        rmdir(dirName, 's');
    end
end

function mdir = findMDirOfPackage(package)
% find mdir (folder containing .m files that we will add to path)

    if ~package.addPath
        mdir = '';
        return;
    end
    if ~isempty(package.internalDir)
        if exist(fullfile(package.installDir, package.internalDir), 'dir')
            mdir = package.internalDir;
            return;
        else
            warning('Ignoring internal-dir because it did not exist in package.');
        end
    end

	folderNames = dir(fullfile(package.installDir, '*.m'));
    if ~isempty(folderNames)
        mdir = ''; % all is well; *.m files exist in base directory
        return;
    else
        M_DIR_ORDER = {'bin', 'src', 'lib', 'code'};
        for ii = 1:numel(M_DIR_ORDER)
            folderNames = dir(fullfile(package.installDir, M_DIR_ORDER{ii}, '*.m'));
            if ~isempty(folderNames)
                mdir = M_DIR_ORDER{ii};
                return;
            end
        end
    end    
    warning('Could not find folder with .m files. Nothing will be added to the path.');
    fprintf([ ...
        'You can manually specify which folder to add to ' ...
        'the path by running: \n' ...
        '   >> mpm set ' package.name ' -n [foldername]\n' ...
        'The following are internal folder names that ' ...
        'you can add with this command: \n']);
    fldrs = dir(package.installDir);
    foldernames = {fldrs([fldrs.isdir] == 1).name};
    disp(foldernames);
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
    packages = m.packages;
    defaultPkg = setDefaultOpts();
    allFieldNames = fieldnames(defaultPkg);

    cleanPackages = [];
    for ii = 1:numel(packages)
        package = packages(ii);

        % set any missing fields to default value
        missingFields = setdiff(allFieldNames, fieldnames(package));
        for jj = 1:numel(missingFields)
            cfld = missingFields{jj};
            package.(cfld) = defaultPkg.(cfld);
        end

        % handle manually-deleted packages by skipping if dir doesn't exist
        pth = fullfile(package.installDir, package.mdir);
        if exist(pth, 'dir')
            cleanPackages = [cleanPackages package];
        end
    end
    m.packages = cleanPackages;
end

function [ind, ix] = indexInMetadata(package, packageMetadata)
    if isempty(packageMetadata)
        ind = []; ix = [];
        return;
    end
    ix = ismember({packageMetadata.name}, package.name);
    ind = find(ix, 1, 'first');
end

function opts = addToMetadata(package, opts)
% update metadata file to track all packages installed

    packageMetadata = opts.metadata.packages;
    [~, ix] = indexInMetadata(package, packageMetadata);
    if any(ix)
        packageMetadata = packageMetadata(~ix);
        disp(['   Replacing previous version in metadata in  ' ...
            opts.metafile]);
    else
        disp(['   Adding package to metadata in ' opts.metafile]);
    end
    packageMetadata = [packageMetadata package];

    % write to file
    packages = packageMetadata;
    opts.metadata.packages = packages;
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end
end

function updatePaths(opts)
% read metadata file and add all paths listed

    % add mdir to path for each package in metadata (optional)
    namesAdded = {};
    if opts.updateMpmPaths
        packages = opts.metadata.packages;
        for ii = 1:numel(packages)
            success = updatePath(packages(ii), opts);
            if success
                namesAdded = [namesAdded packages(ii).name];
            end
        end
    end
    if numel(packages) == 0
        disp('   No packages found in collection.');
    else
        disp(['   Added paths for ' num2str(numel(namesAdded)) ...
            ' package(s).']);
    end

    % also add all folders listed in install-dir (optional)
    if opts.updateAllPaths
        c = updateAllPaths(opts, namesAdded);
        disp(['   Added paths for ' num2str(c) ' additional package(s).']);
    end
end

function success = updatePath(package, opts)
    success = false;
    if ~package.addPath
        return;
    end
    pth = fullfile(package.installDir, package.mdir);
    if exist(pth, 'dir')
        success = true;
        if ~opts.debug
            disp(['   Adding to path: ' pth]);
            addpath(pth);
        end

        % add all folders to path
        if package.addAllDirsToPath
            disp('   Also adding paths to all sub-folders (--all-paths).');
            addpath(genpath(pth));

        else % check for pathList.m file
            pathfile = fullfile(pth, 'pathList.m');
            pathsToAdd = checkForPathlistAndGenpath(pathfile, pth);
            if numel(pathsToAdd) > 0 && ~opts.debug
                disp('   Also adding paths found in pathList.m');
                addpath(pathsToAdd);
            end
        end
    else
        warning(['Path to package does not exist: ' pth]);
        return;
    end
end

function c = updateAllPaths(opts, namesAlreadyAdded)
% adds all directories inside installDir to path
%   ignoring those already added
% 
    c = 0;
    fs = dir(opts.installDir); % get names of everything in install dir
    fs = {fs([fs.isdir]).name}; % keep directories only
    fs = fs(~strcmp(fs, '.') & ~strcmp(fs, '..')); % ignore '.' and '..'
    for ii = 1:numel(fs)
        f = fs{ii};
        if ~ismember(f, namesAlreadyAdded)
            if ~opts.debug                
                pth = fullfile(opts.installDir, f);
                disp(['   Adding to path: ' pth]);
                addpath(pth);
            end
            c = c + 1;
        end
    end
end

function [package, opts] = parseArgs(package, opts, action, varargin)
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

    allParams = { ...
        'collection', '-c', ...
        'in-file', '-i', ...
        'install-dir', '-d', ...
        'internal-dir', '-n', ...
        'release-tag', '-t', ...
        'url', '-u', ...
        '--all-paths', ...
        '--approve' ...
        '--debug', ...
        '--use-local', '-e', ...
        '--force', '-f', '--no-paths', ...
        '--github-first', '-gh', ...
        '--local', ...
        '--query', '-q', ...
    };

    % no additional args
    if numel(remainingArgs) == 0
        if strcmpi(opts.action, 'freeze') || strcmpi(opts.action, 'init')
            package.query = '';
            return;
        else
            error('You must specify a package name or a filename.');
        end
    end

    % if first arg is not a param name, it's the package name
    nextArg = remainingArgs{1};
    if ~ismember(lower(nextArg), lower(allParams))
        package.name = nextArg;
        package.query = '';
        remainingArgs = remainingArgs(2:end);
    else
        package.name = '';
        package.query = '';
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
            package.url = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'query') || strcmpi(curArg, '-q')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            package.query = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'in-file') || strcmpi(curArg, '-i')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.inFile = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'install-dir') || strcmpi(curArg, '-d')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.installDir = nextArg;
            opts.installDirOverride = true;
            usedNextArg = true;
        elseif strcmpi(curArg, 'collection') || strcmpi(curArg, '-c')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            opts.collection = nextArg;
            package.collection = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'internal-dir') || strcmpi(curArg, '-n')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            package.internalDir = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, 'release-tag') || strcmpi(curArg, '-t')
            nextArg = getNextArg(remainingArgs, ii, curArg);
            package.releaseTag = nextArg;
            usedNextArg = true;
        elseif strcmpi(curArg, '--github-first') || ...
                strcmpi(curArg, '-g')
            opts.searchGithubFirst = true;
        elseif strcmpi(curArg, '--force') || strcmpi(curArg, '-f')
            opts.force = true;
        elseif strcmpi(curArg, '--approve')
            opts.approve = true;
        elseif strcmpi(curArg, '--debug')
            opts.debug = true;
        elseif strcmpi(curArg, '--no-paths')
            package.addPath = false;
            opts.nopaths = true;
        elseif strcmpi(curArg, '--all-paths')
            package.addAllDirsToPath = true;
            opts.addAllDirsToPath = true;
        elseif strcmpi(curArg, '--local')
            opts.localInstall = true;
            package.localInstall = true;
        elseif strcmpi(curArg, '-use-local') || strcmpi(curArg, '-e')
            opts.localInstallUseLocal = true;
            package.noRmdirOnUninstall = true;
        else
            error(['Did not recognize argument ''' curArg '''.']);
        end
    end

    % update metadir, if collection was set
    if ~strcmpi(opts.collection, 'default')
        opts.metadir = fullfile(opts.metadir, 'mpm-collections', ...
            opts.collection);
        opts.installDir = opts.metadir;
        if strcmpi(opts.action, 'install')
            opts.noPaths = true;
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

function isOk = validateArgs(package, opts)
    isOk = true;
    if strcmpi(opts.action, 'init')
        return;
    end
    if isempty(package.name) && isempty(opts.inFile)
        if ~strcmpi(opts.action, 'freeze')
            error('You must specify a package name or a filename.');
        end
    end
    if ~isempty(opts.inFile)
        assert(isempty(package.name), ...
            'Cannot specify package name if installing from filename');
        assert(isempty(package.url), ...
            'Cannot specify url if installing from filename');
        assert(isempty(package.internalDir), ...
            'Cannot specify internal-dir if installing from filename');
        assert(isempty(package.releaseTag), ...
            'Cannot specify release-tag if installing from filename');
        assert(~opts.searchGithubFirst, ...
            'Cannot set github-first if installing from filename');
    else
        assert(~opts.approve, ...
            'Can only set approve if installing from filename');
    end
    if strcmpi(opts.action, 'uninstall')
        assert(isempty(package.url), ...
            'Cannot specify url if uninstalling');
        assert(isempty(package.query), ...
            'Cannot specify query if uninstalling');
        assert(isempty(package.internalDir), ...
            'Cannot specify internal-dir if uninstalling');
        assert(isempty(package.releaseTag), ...
            'Cannot specify release-tag if uninstalling');
        assert(~opts.searchGithubFirst, ...
            'Cannot set github-first if uninstalling');
    end
    if strcmpi(opts.action, 'search')
        assert(~opts.force, 'Nothing to force when searching.');
    end
    if strcmpi(opts.action, 'freeze')
        assert(~opts.force, 'Nothing to force when running ''freeze''.');
        assert(isempty(package.url), ...
            'Cannot specify url when running ''freeze''');
        assert(isempty(package.query), ...
            'Cannot specify query when running ''freeze''');
        assert(isempty(package.internalDir), ...
            'Cannot specify internal-dir when running ''freeze''');
        assert(isempty(package.releaseTag), ...
            'Cannot specify release-tag when running ''freeze''');
        assert(~opts.searchGithubFirst, ...
            'Cannot set github-first when running ''freeze''');
    end
    if strcmpi(opts.action, 'set')
        assert(~opts.force, 'Nothing to force when running ''set''.');
        assert(isempty(package.url), ...
            'Cannot specify url when running ''set''');
        assert(isempty(package.query), ...
            'Cannot specify query when running ''set''');
        assert(isempty(package.releaseTag), ...
            'Cannot specify release-tag when running ''set''');
        assert(~opts.searchGithubFirst, ...
            'Cannot set github-first when running ''set''');
    end
    if opts.localInstall
        assert(~isempty(package.url), ...
            'Must specify local path with -u when running ''--local''');
    end
    if opts.localInstallUseLocal
        assert(opts.localInstall, ...
            'Can only specify -e when running ''--local''');
    end
end

function readRequirementsFile(fileName, opts)
    txt = fileread(fileName);
    lines = strsplit(txt, '\n');

    % build list of commands to run
    % and check for illegal params (note spaces)
    illegalParams = {' -i ', ' in-file '};
    cmds = {};    
    for ii = 1:numel(lines)
        line = lines{ii};
        cmd = line;

        if isempty(strrep(cmd, ' ', ''))
            % ignore empty line
            continue;
        end
        if strcmpi(cmd(1), '%')
            % ignore comments
            continue;
        end

        for jj = 1:numel(illegalParams)
            if ~isempty(strfind(line, illegalParams{jj}))
                error(['Line ' num2str(ii) ' in in-file cannot contain ''' illegalParams{jj} '''. (Illegal arguments: ''-i'', ''in-file'',  ''install-dir'', ''-c''.)']);
            end
        end

        % if args are specified inside file, don't allow specifying w/ opts
        if opts.force && (~isempty(strfind(line, ' --force')) || ~isempty(strfind(line, ' -f')))
            error('Cannot set --force because it is in in-file.');
        end
        if opts.noPaths && ~isempty(strfind(line, ' --no-paths'))
            error('Cannot set --no-paths because it is in in-file.');
        end
        if opts.addAllDirsToPath && ~isempty(strfind(line, ' --all-paths'))
            error('Cannot set --all-paths because it is in in-file.');
        end
        if opts.localInstall && ~isempty(strfind(line, ' --local'))
            error('Cannot set --local because it is in in-file.');
        end
        if opts.localInstallUseLocal && (~isempty(strfind(line, ' -use-local')) || ~isempty(strfind(line, ' -e')))
            error('Cannot set -e because it is in in-file.');
        end

        % check if installDir set on line
        if ~isempty(strfind(line, ' -d')) || ~isempty(strfind(line, ' InstallDir '))
            % warn if user also provided this line globally
            if opts.installDirOverride
                warning([' install dir (-d) is set inside file (line ' ...
                    num2str(ii) '), over-riding default.']);
            end
        elseif ~isempty(line)
            cmd = [cmd ' -d ' opts.installDir];
        end

        % check if collection set on line
        if ~isempty(strfind(line, ' -c')) || ~isempty(strfind(line, ' Collection '))
            % warn if user also provided this line globally
            if ~strcmpi(opts.collection, 'default')
                warning([' collection (-c) is set inside file (line ' ...
                    num2str(ii) '), over-riding default.']);
            end
        elseif ~isempty(line)
            cmd = [cmd ' -c ' opts.collection];
        end

        % now append opts as globals for each line in file
        if ~isempty(line)
            if opts.force
                cmd = [cmd ' --force'];
            end
            if opts.noPaths
                cmd = [cmd ' --no-paths'];
            end
            if opts.addAllDirsToPath
                cmd = [cmd ' --all-paths'];
            end
            if opts.localInstall
                cmd = [cmd ' --local'];
            end
            if opts.localInstallUseLocal
                cmd = [cmd ' -use-local'];
            end
            cmds = [cmds cmd];
        end
    end

    % verify
    disp('About to run the following commands: ');
    for ii = 1:numel(cmds)
        disp(['   mpm ' opts.action ' ' cmds{ii}]);
    end
    if ~opts.approve % otherwise, auto-approve the below
        reply = input('Confirm (y/n)? ', 's');
        if isempty(reply)
            reply = 'y';
        end
        if ~strcmpi(reply(1), 'y')
            disp('I saw nothing.');
            return;
        end
    end

    % run all
    for ii = 1:numel(cmds)
        cmd = strsplit(cmds{ii});
        mpm(opts.action, cmd{:});
    end
end

function checkForFileAndRun(installDir, fileName, opts)
    fpath = fullfile(installDir, fileName);

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
    disp([fileName ' file found at ' fpath]);
    if numel(lines) > 0
        disp('Showing first lines of comments:');
        disp(strjoin(lines, '\n'));
    end
    if ~opts.force
        reply = input(['Run ' fileName ' (y/n)? '], 's');
        if isempty(reply)
            reply = 'y';
        end
        if ~strcmpi(reply(1), 'y')
            disp(['Skipping ' fileName '.']);
            return;
        end
        disp(['Running ' fileName ' ...']);
    else
        disp(['Running ' fileName ' (--force was on)...']);
    end

    % run
    run(fpath);
end

function pathList = checkForPathlistAndGenpath(fpath, basedir)

    pathList = '';

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
                curPath = genpath(fullfile(basedir, line(1:end-1)));
            else
                % add just this one dir
                curPath = [fullfile(basedir, line) ':'];
            end
            pathList = [pathList curPath];
        end
    end

    if fid ~= -1
        fclose(fid);
    end
end
