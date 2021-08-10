function mpm(action, varargin)
%MPM Matlab Package Manager
% function mpm(ACTION, varargin)
% 
% ACTION can be any of the following:
%   'init'      add all installed packages in default install directory to path
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
%   % Add all installed packages to the path (e.g. to be run at startup)
%   mpm init
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
        warning(i18n('debug_message'));
    end
    disp(i18n('setup_log', opts.collection));

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
    disp(i18n('setup_start', package.name));

    % check if exists
    if (                                                                    ...
        ~opts.force                                                         ...
        && ~strcmpi(opts.action, 'search')                                  ...
        && ~isempty(indexInMetadata(package, opts.metadata.packages))       ...
    )
        warning(i18n('package_collision'));
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
            disp(i18n('setup_download', package.url));
        else
            disp(i18n('setup_install'));
        end
        [package, isOk] = installPackage(package, opts);
        if ~isempty(package) && isOk
            opts = addToMetadata(package, opts);
            if ~opts.noPaths
                disp(i18n('setup_updating'));
                updatePath(package, opts);
            end
        end
    end
end

function removePackage(package, opts)
    packages = opts.metadata.packages;
    [~, ix] = indexInMetadata(package, packages);
    if ~any(ix)
        disp(i18n('remove_404', package.name));
        return;
    end

    % delete package directories if they exist
    removalQueue = packages(ix);
    disp(i18n('remove_start', num2str(sum(ix)), package.name));
    if ~opts.force
        reply = input(i18n('confirm'), 's');
        if isempty(reply)
            reply = i18n('confirm_yes');
        end
        if ~strcmpi(reply(1), i18n('confirm_yes'))
            disp(i18n('confirm_nvm'));
            return;
        end
    end
    for ii = 1:numel(removalQueue)
        package = removalQueue(ii);

        % check for uninstall file
        dirPath = fullfile(package.installDir, package.mdir);
        checkForFileAndRun(dirPath, 'uninstall.m', opts);

        if exist(package.installDir, 'dir')
            % remove old directory
            if ~package.noRmdirOnUninstall
                rmdir(package.installDir, 's');
            else
                installDir = package.installDir;
                disp(i18n('remove_preexist', installDir));
            end
        end
    end

    % write new metadata to file
    packages = packages(~ix);
    if ~opts.debug        
        save(opts.metafile, 'packages');
    end

    disp();
end

function dispTree(name)
    folderNames = dir(name);
    folderNames = {folderNames([folderNames.isdir] == 1).name};
    for i = 1:length(folderNames)
        if i == length(folderNames)
            disp([char(9492) char(9472) char(9472) char(9472) folderNames{i}])
        elseif ~endsWith(folderNames{i}, '.')
            disp([char(9500) char(9472) char(9472) char(9472) folderNames{i}])
        end
    end
end

function changePackageOptions(package, opts)
    % find existing package
    packageMetadata = opts.metadata.packages;
    [~, ix] = indexInMetadata(package, packageMetadata);
    if ~any(ix)
        warning(i18n('update_404', package.name));
        return;
    end
    assert(sum(ix) == 1, i18n('options_conflict'));
    oldPackage = packageMetadata(ix);

    % update options
    if opts.noPaths
        disp(i18n('update_nopaths', package.name));
        oldPackage.addPath = false;
    end
    if package.addAllDirsToPath
        disp(i18n('update_pathdirs', package.name));
        oldPackage.addAllDirsToPath = true;
        if ~oldPackage.addPath
            disp(i18n('update_addpath'));
            oldPackage.addPath = true;
        end
    end
    if ~isempty(package.internalDir)        
        if exist(fullfile(oldPackage.installDir, package.internalDir), 'dir')
            oldPackage.mdir = package.internalDir;
            oldPackage.internalDir = package.internalDir;
            disp(i18n('update_package', package.name, package.internalDir));
            if ~oldPackage.addPath
                disp(i18n('update_addpath'));
                oldPackage.addPath = true;
            end
        else
            if numel(folderNames) == 0
                warning(i18n('internal_no_dirs'));
            else
                warning(i18n('internal_nosuchdir'));
                dispTree(oldPackage.installDir);
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
        disp(i18n('list_404', opts.installDir));
        return;
    end
    disp(i18n('list_current', opts.installDir));
    for ii = 1:numel(packages)
        package = packages(ii);
        packageName = package.name;
        if ~isempty(package.releaseTag)
            packageName = [packageName '==' package.releaseTag]; %#ok<*AGROW>
        end
        out = [' - ' packageName ' (' package.downloadDate ')'];
        cdir = fileparts(package.installDir);
        if ~strcmpi(cdir, opts.installDir)
            out = [out ' : ' package.installDir];
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
        disp(i18n('url_404'));
    else
        disp(i18n('url_found', url));
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
%             'matlabcentral/mlc-downloads/downloads/submissions/' aid      ...
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
        warning(i18n('install_conflict'));
        isOk = false;
        return;
    elseif exist(package.installDir, 'dir')
        % remove old directory
        disp(i18n('install_remove_previous'));
        rmdir(package.installDir, 's');
    end

    if (                                                                    ...
        ~opts.localInstall                                                  ...
        && ~isempty(strfind(package.url, '.git'))                           ...
        && isempty(strfind(package.url, 'github.com'))                      ...
    )
        % install with git clone because not on github
        isOk = checkoutFromUrl(package);
        if ~isOk
            warning(i18n('install_git_error'));
        end
    elseif ~opts.localInstall
        % download zip
        package.url = handleCustomUrl(package.url, package.releaseTag);
        [isOk, package] = unzipFromUrl(package);
        if (                                                                ...
            ~isOk                                                           ...
            && ~isempty(strfind(package.url, 'github.com'))                 ...
            && isempty(strfind(package.url, '.git'))                        ...
        )
            warning(i18n('install_add_git_ext'));
        elseif ~isOk
            warning(i18n('install_download_error'));
        end
    else % local install (using pre-existing local directory)
        % make sure path exists
        if ~exist(package.url, 'dir')
            warning(i18n('install_nosuchdir', package.url));
            isOk = false; return;
        end

        % copy directory to installDir
        if ~opts.localInstallUseLocal
            if ~exist(package.url, 'dir')
                warning(i18n('install_404', package.url));
                isOk = false; return;
            end
            mkdir(package.installDir);
            isOk = copyfile(package.url, package.installDir);
            if ~isOk
                warning(i18n('install_error_local'));
            end
        else % no copy; just track the provided path
            % make sure we have absolute path
            if ~isempty(strfind(package.url, pwd))
                absPath = package.url;
            else % try making it ourselves
                absPath = fullfile(pwd, package.url);
            end
            if ~exist(absPath, 'dir')
                warning(i18n('install_404', absPath));
                isOk = false; return;
            else
                package.installDir = absPath;
            end
        end
    end
    if ~isOk
        warning(i18n('install_error', package.name));
        return;
    end
    package.downloadDate = datestr(datetime);
    package.mdir = findMDirOfPackage(package);

    if isOk
        % check for install.m and run after confirming
        dirPath = fullfile(package.installDir, package.mdir);
        checkForFileAndRun(dirPath, 'install.m', opts);
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
        warning(i18n('checkout_error', package.url));
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
        folderNames = folderNames([folderNames.isdir]);
        fldr = folderNames(end).name;
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
            warning(i18n('internal_nosuchdir'));
            dispTree(package.installDir);
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
    warning(i18n('mdir_404'));
    disp(i18n('mdir_help', package.name));
    dispTree(package.installDir);
    tree 
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
        dirPath = fullfile(package.installDir, package.mdir);
        if exist(dirPath, 'dir')
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
        disp(i18n('metadata_replace_op', opts.metafile));
    else
        disp(i18n('metadata_add_op', opts.metafile));
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
        disp(i18n('updatepaths_404'));
    else
        disp(i18n('updatepaths_success', num2str(numel(packages))));
    end

    % also add all folders listed in install-dir (optional)
    if opts.updateAllPaths
        c = updateAllPaths(opts, namesAdded);
        disp(i18n('updatepaths_all', num2str(c)));
    end
end

function success = updatePath(package, opts)
    success = false;
    if ~package.addPath
        return;
    end
    dirPath = fullfile(package.installDir, package.mdir);
    if exist(dirPath, 'dir')
        success = true;
        if ~opts.debug
            disp(i18n('updatepath_op', dirPath));
            addpath(dirPath);
        end

        % add all folders to path
        if package.addAllDirsToPath
            disp(i18n('updatepath_all'));
            addpath(genpath(dirPath));

        else % check for pathList.m file
            pathfile = fullfile(dirPath, 'pathList.m');
            pathsToAdd = checkForPathlistAndGenpath(pathfile, dirPath);
            if numel(pathsToAdd) > 0 && ~opts.debug
                disp(i18n('updatepath_pathlist'));
                addpath(pathsToAdd);
            end
        end
    else
        warning(i18n('updatepath_404', dirPath));
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
                dirPath = fullfile(opts.installDir, f);
                disp(mpm_config('updatepath_op', dirPath));
                addpath(dirPath);
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
    actions = {                                                             ...
        'init',                                                             ...
        'search',                                                           ...
        'install',                                                          ...
        'uninstall',                                                        ...
        'freeze',                                                           ...
        'set'                                                               ...
    };
    checkAction = @(x) any(validatestring(x, actions));
    addRequired(q, 'action', checkAction);
    defaultName = '';
    addOptional(q, 'remainingargs', defaultName);
    parse(q, action, varargin{:});
    opts.action = q.Results.action;
    remainingArgs = q.Results.remainingargs;

    params = { ...
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
        '--force', '-f', ...
        '--no-paths', ...
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
            error(i18n('parseargs_noargin'));
        end
    end

    % if first arg is not a param name, it's the package name
    nextArg = remainingArgs{1};
    if ~ismember(lower(nextArg), lower(params))
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
            opts.noPaths = true;
        elseif strcmpi(curArg, '--all-paths')
            package.addAllDirsToPath = true;
            opts.addAllDirsToPath = true;
        elseif strcmpi(curArg, '--local')
            opts.localInstall = true;
            package.localInstall = true;
        elseif strcmpi(curArg, '--use-local') || strcmpi(curArg, '-e')
            opts.localInstallUseLocal = true;
            package.noRmdirOnUninstall = true;
        else
            error(['Did not recognize argument ''' curArg '''.']);
        end
    end

    % update metadir, if collection was set
    if ~strcmpi(opts.collection, 'default')
        opts.metadir = fullfile(opts.metadir, 'mpm-collections',            ...
            opts.collection);
        opts.installDir = opts.metadir;
        if strcmpi(opts.action, 'install')
            opts.noPaths = true;
        end
    end
end

function nextArg = getNextArg(remainingArgs, ii, curArg)
    if numel(remainingArgs) <= ii
        error(i18n('getnextarg_noargin', curArg));
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
            error(i18n('parseargs_noargin'));
        end
    end
    if ~isempty(opts.inFile)
        assert(isempty(package.name), i18n('validateargs_infile_name'));
        assert(isempty(package.url), i18n('validateargs_infile_url'));
        assert(isempty(package.internalDir), i18n('validateargs_infile_internal_dir'));
        assert(isempty(package.releaseTag), i18n('validateargs_infile_release_tag'));
        assert(~opts.searchGithubFirst, i18n('validateargs_infile_github_first'));
    else
        assert(~opts.approve, i18n('validateargs_infile_approve'));
    end
    if strcmpi(opts.action, 'uninstall')
        assert(isempty(package.url), i18n('validateargs_url', 'uninstall'));
        assert(isempty(package.query), i18n('validateargs_query', 'uninstall'));
        assert(isempty(package.internalDir), i18n('validateargs_internal_dir', 'uninstall'));
        assert(isempty(package.releaseTag), i18n('validateargs_release_tag', 'uninstall'));
        assert(~opts.searchGithubFirst, i18n('validateargs_github_first', 'uninstall'));
    end
    if strcmpi(opts.action, 'search')
        assert(~opts.force, i18n('validateargs_force_combination', 'search'));
    end
    if strcmpi(opts.action, 'freeze')
        assert(~opts.force, i18n('validateargs_force_combination', 'freeze'));
        assert(isempty(package.url), i18n('validateargs_url', 'freeze'));
        assert(isempty(package.query), i18n('validateargs_query', 'freeze'));
        assert(isempty(package.internalDir), i18n('validateargs_internal_dir', 'freeze'));
        assert(isempty(package.releaseTag), i18n('validateargs_release_tag', 'freeze'));
        assert(~opts.searchGithubFirst, i18n('validateargs_github_first', 'freeze'));
    end
    if strcmpi(opts.action, 'set')
        assert(~opts.force, i18n('validateargs_force_combination', 'set'));
        assert(isempty(package.url), i18n('validateargs_url', 'set'));
        assert(isempty(package.query), i18n('validateargs_query', 'set'));
        assert(isempty(package.releaseTag), i18n('validateargs_release_tag', 'set'));
        assert(~opts.searchGithubFirst, i18n('validateargs_github_first', 'set'));
    end
    if opts.localInstall
        assert(~isempty(package.url, i18n('validateargs_localinstall_nourl')));
    end
    if opts.localInstallUseLocal
        assert(opts.localInstall, i18n('validateargs_uselocal_local'));
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
                error(i18n('', num2str(ii), illegalParams{jj}));
            end
        end

        % if args are specified inside file, don't allow specifying w/ opts
        if (                                                                ...
            opts.force                                                      ...
            && (...
                ~isempty(strfind(line, ' --force'))                         ...
                || ~isempty(strfind(line, ' -f'))                           ...
            )                                                               ...
        )
            error(i18n('requirements_infile_conflict', 'force'));
        end
        if opts.noPaths && ~isempty(strfind(line, ' --no-paths'))
            error(i18n('requirements_infile_conflict', 'no-paths'));
        end
        if opts.addAllDirsToPath && ~isempty(strfind(line, ' --all-paths'))
            error(i18n('requirements_infile_conflict', 'all-paths'));
        end
        if opts.localInstall && ~isempty(strfind(line, ' --local'))
            error(i18n('requirements_infile_conflict', 'local'));
        end
        if (                                                                ...
            opts.localInstallUseLocal ...
            && (                                                            ...
                ~isempty(strfind(line, '--use-local'))                      ...
                || ~isempty(strfind(line, ' -e'))                           ...
            )                                                               ...
        )
            error(i18n('requirements_infile_conflict', 'use-local'));
        end

        % check if installDir set on line
        if ~isempty(strfind(line, ' -d')) || ~isempty(strfind(line, ' InstallDir '))
            % warn if user also provided this line globally
            if opts.installDirOverride
                warning(i18n('requirements_installdir_override', num2str(ii)));
            end
        elseif ~isempty(line)
            cmd = [cmd ' -d ' opts.installDir];
        end

        % check if collection set on line
        if ~isempty(strfind(line, ' -c')) || ~isempty(strfind(line, ' Collection '))
            % warn if user also provided this line globally
            if ~strcmpi(opts.collection, 'default')
                warning(i18n(                                               ...
                    'requirements_collection_global',                       ...
                    opts.collection, num2str(ii)                            ...
                ));
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
                cmd = [cmd ' --use-local'];
            end
            cmds = [cmds cmd];
        end
    end

    % verify
    disp(i18n('requirements_command_list'));
    for ii = 1:numel(cmds)
        disp(i18n('requirements_command', opts.action, cmds{ii}));
    end
    if ~opts.approve % otherwise, auto-approve the below
        reply = input(i18n('confirm'), 's');
        if isempty(reply)
            reply = i18n('confirm_yes');
        end
        if ~strcmpi(reply(1), i18n('confirm_yes'))
            disp(i18n('confirm_nvm'));
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
    disp(i18n('checkfilerun_200', fileName, fpath));
    if numel(lines) > 0
        disp(i18n('checkfilerun_help'));
        disp(strjoin(lines, '\n'));
    end
    if ~opts.force
        reply = input(['Run ' fileName ' (Y/N)? '], 's');
        if isempty(reply)
            reply = i18n('confirm_yes');
        end
        if ~strcmpi(reply(1), i18n('confirm_yes'))
            disp(i18n('checkfilerun_skip', fileName));
            return;
        end
        disp(i18n('checkfilerun_running', fileName));
    else
        disp(i18n('checkfilerun_run_force', fileName));
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

function str = i18n(key, varargin)
    persistent locale nls
    locale = char(regexp(get(0, 'Language'), '^[a-zA-Z]+', 'match'));
    load mpm_nls.mat nls;

    %% Check if message key exists.
    if isfield(nls, locale)
        data = nls.(locale);
    else
        data = nls.en;
    end
    
    if ~ischar(key)
        if (                                                                ...
            ~isfield(nls, locale)                                           ...
            || ~isfield(nls.(locale), 'unexpected_key')                     ...
        )
            error(nls.en.unexpected_key, class(key));
        else
            error(nls.(locale).unexpected_key, class(key));
        end
    end

    if (                                                                    ...
        ~isfield(data, key)                                                 ...
        && strcmp(locale, 'en')                                             ...
        || ~isfield(nls.en, key)                                            ...
    )
        error(nls.en.undefined_key, key);
    end

    %% Get the localised message.
    if isfield(data, key)
        str = data.(key);
    else
        str = sprintf(nls.en.(key), string(varargin{:}));
    end

    %% Variable argument substitution.
    if nargin == 2
        return;
    end

    str = sprintf(str, varargin{:});
end
