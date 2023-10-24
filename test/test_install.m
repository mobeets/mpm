% cd test/
% result = runtests('test_install')
% table(result)
clear
warning('off','backtrace')

GITHUB_SEARCH_RATELIMIT = 6;

mpm_dir = fileparts(pwd);
cd(mpm_dir)
addpath(mpm_dir)

%% Test API Install - using GitHub api (no url)

%%% Test install api latest
mpm install export_fig --force
export_fig_dir = fullfile(mpm_dir, 'mpm-packages', 'export_fig');
assert(exist(fullfile(export_fig_dir, 'export_fig.m'), 'file')==2)
assert(~isempty(which('export_fig')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api tag
mpm install matlab2tikz -t 0.4.7 --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api branch
mpm install matlab2tikz -t develop --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api commit hash
mpm install matlab2tikz -t ca56d9f --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%% Test URL Install - using URL with .git file extension

%%% Test install url default branch
mpm install matlab2tikz -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'src/matlab2tikz.m'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url tag
mpm install matlab2tikz -t 0.4.7 -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url branch
mpm install matlab2tikz -t develop -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url commit hash
mpm install matlab2tikz -t ca56d9f -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);



%% Test Git Clone Install - using non-GitHub URL with .git file extension

%%% Test install git clone default branch
mpm install hello -u https://bitbucket.org/dhoer/mpm_test.git --force
mpm_test_dir = fullfile(mpm_dir, 'mpm-packages', 'hello');
assert(exist(fullfile(mpm_test_dir, 'hello.m'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install git clone tag
mpm install hello -t v1.0.0 -u https://bitbucket.org/dhoer/mpm_test.git --force
mpm_test_dir = fullfile(mpm_dir, 'mpm-packages', 'hello');
assert(exist(fullfile(mpm_test_dir, 'v1.0.0'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install git clone branch
mpm install hello -t develop -u https://bitbucket.org/dhoer/mpm_test.git --force
mpm_test_dir = fullfile(mpm_dir, 'mpm-packages', 'hello');
assert(exist(fullfile(mpm_test_dir, 'v2.0.0'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% not working - bitbucket clone of branch using hash not supported
%%% Test install git clone commit hash
%mpm install hello -t 36967c34800121b957a2855b8fcf4491dd13866c -u https://bitbucket.org/dhoer/mpm_test.git --force
% mpm_test_dir = fullfile(mpm_dir, 'mpm-packages', 'hello');
% assert(exist(fullfile(mpm_test_dir, 'v1.1.0'), 'file')==2)
% assert(~isempty(which('hello')))



%%% Test install FileExchange
mpm install covidx -u https://www.mathworks.com/matlabcentral/fileexchange/76213-covidx --force
covidx_dir = fullfile(mpm_dir, 'mpm-packages', 'covidx');
assert(exist(fullfile(covidx_dir, 'covidx.m'), 'file')==2)
assert(~isempty(which('covidx')))

pause(GITHUB_SEARCH_RATELIMIT);



%%% Test uninstall
mpm install colorbrewer --force
mpm uninstall colorbrewer --force
colorbrewer_dir = fullfile(mpm_dir, 'mpm-packages', 'colorbrewer');
assert(exist(colorbrewer_dir, 'dir')==0)
assert(exist(fullfile(colorbrewer_dir, 'brewermap.m'), 'file')==0)
assert(isempty(which('brewermap')))



%%% Test freeze
if ~exist('contains', 'builtin')
    contains = @(x,y) ~isempty(strfind(x,y));
end
results = evalc('mpm freeze');
assert(contains(results,'export_fig'))
assert(contains(results,'matlab2tikz==ca56d9f'))
assert(contains(results,'covidx'))



%%% Test search
results = evalc('mpm search export_fig');
assert(contains(results, ...
    'Found url: https://www.mathworks.com/matlabcentral/fileexchange/23629-export_fig?download=true'))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test infile
mpm install --approve --force -i requirements-example.txt
assert(~isempty(which('export_fig')))
assert(~isempty(which('matlab2tikz')))
assert(~isempty(which('brewermap')))
mpm uninstall colorbrewer --force
mpm uninstall covidx --force
mpm uninstall export_fig --force
mpm uninstall hello --force
mpm uninstall matlab2tikz --force
