% cd test/
% result = runtests('test_install')
% table(result)
clear
warning('off','backtrace')

GITHUB_SEARCH_RATELIMIT = 6;

mpi_dir = fileparts(pwd);
cd(mpi_dir)
addpath(mpi_dir)

%% Test API Install - using GitHub api (no url)

%%% Test install api latest
mpi install export_fig --force
export_fig_dir = fullfile(mpi_dir, 'mpi-packages', 'export_fig');
assert(exist(fullfile(export_fig_dir, 'export_fig.m'), 'file')==2)
assert(~isempty(which('export_fig')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api tag
mpi install matlab2tikz -t 0.4.7 --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api branch
mpi install matlab2tikz -t develop --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install api commit hash
mpi install matlab2tikz -t ca56d9f --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%% Test URL Install - using URL with .git file extension

%%% Test install url default branch
mpi install matlab2tikz -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'src/matlab2tikz.m'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url tag
mpi install matlab2tikz -t 0.4.7 -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url branch
mpi install matlab2tikz -t develop -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install url commit hash
mpi install matlab2tikz -t ca56d9f -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpi_dir, 'mpi-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

pause(GITHUB_SEARCH_RATELIMIT);



%% Test Git Clone Install - using non-GitHub URL with .git file extension

%%% Test install git clone default branch
mpi install hello -u https://bitbucket.org/dhoer/mpm_test.git --force
mpi_test_dir = fullfile(mpi_dir, 'mpi-packages', 'hello');
assert(exist(fullfile(mpi_test_dir, 'hello.m'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install git clone tag
mpi install hello -t v1.0.0 -u https://bitbucket.org/dhoer/mpm_test.git --force
mpi_test_dir = fullfile(mpi_dir, 'mpi-packages', 'hello');
assert(exist(fullfile(mpi_test_dir, 'v1.0.0'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test install git clone branch
mpi install hello -t develop -u https://bitbucket.org/dhoer/mpm_test.git --force
mpi_test_dir = fullfile(mpi_dir, 'mpi-packages', 'hello');
assert(exist(fullfile(mpi_test_dir, 'v2.0.0'), 'file')==2)
assert(~isempty(which('hello')))

pause(GITHUB_SEARCH_RATELIMIT);

%%% not working - bitbucket clone of branch using hash not supported
%%% Test install git clone commit hash
%mpi install hello -t 36967c34800121b957a2855b8fcf4491dd13866c -u https://bitbucket.org/dhoer/mpm_test.git --force
% mpi_test_dir = fullfile(mpi_dir, 'mpi-packages', 'hello');
% assert(exist(fullfile(mpi_test_dir, 'v1.1.0'), 'file')==2)
% assert(~isempty(which('hello')))



%%% Test install FileExchange
mpi install covidx -u https://www.mathworks.com/matlabcentral/fileexchange/76213-covidx --force
covidx_dir = fullfile(mpi_dir, 'mpi-packages', 'covidx');
assert(exist(fullfile(covidx_dir, 'covidx.m'), 'file')==2)
assert(~isempty(which('covidx')))

pause(GITHUB_SEARCH_RATELIMIT);



%%% Test uninstall
mpi install colorbrewer --force
mpi uninstall colorbrewer --force
colorbrewer_dir = fullfile(mpi_dir, 'mpi-packages', 'colorbrewer');
assert(exist(colorbrewer_dir, 'dir')==0)
assert(exist(fullfile(colorbrewer_dir, 'brewermap.m'), 'file')==0)
assert(isempty(which('brewermap')))



%%% Test freeze
if ~exist('contains', 'builtin')
    contains = @(x,y) ~isempty(strfind(x,y));
end
results = evalc('mpi freeze');
assert(contains(results,'export_fig'))
assert(contains(results,'matlab2tikz==ca56d9f'))
assert(contains(results,'covidx'))



%%% Test search
results = evalc('mpi search export_fig');
assert(contains(results, ...
    'Found url: https://www.mathworks.com/matlabcentral/fileexchange/23629-export_fig?download=true'))

pause(GITHUB_SEARCH_RATELIMIT);

%%% Test infile
mpi install --approve --force -i requirements-example.txt
assert(~isempty(which('export_fig')))
assert(~isempty(which('matlab2tikz')))
assert(~isempty(which('brewermap')))
mpi uninstall colorbrewer --force
mpi uninstall covidx --force
mpi uninstall export_fig --force
mpi uninstall hello --force
mpi uninstall matlab2tikz --force
