clear
warning('off','backtrace')

mpm_dir = fullfile(pwd, '..');
addpath(mpm_dir)


%
% Test Install - using GitHub api (no url)
%

%% Test install of latest release
mpm install export_fig --force
export_fig_dir = fullfile(mpm_dir, 'mpm-packages', 'export_fig');
assert(exist(fullfile(export_fig_dir, 'export_fig.m'), 'file')==2)
assert(~isempty(which('export_fig')))

%% Test install of specific tag
mpm install matlab2tikz -t 0.4.7 --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

%% Test install of specific branch
mpm install matlab2tikz -t develop --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

%% Test install of specific commit hash
mpm install matlab2tikz -t ca56d9f --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))


%
% Test Install - using URL with .git file extension
%

%% Test install of default branch (master)
mpm install matlab2tikz -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'src/matlab2tikz.m'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

%% Test install of specific tag
mpm install matlab2tikz -t 0.4.7 -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

%% Test install of specific branch
mpm install matlab2tikz -t develop -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

%% Test install of specific commit hash
mpm install matlab2tikz -t ca56d9f -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz');
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))


%
% Test Install - using MathWorks FileExchange
%

%% Test download directly from fileexchange
mpm install covidx -u https://www.mathworks.com/matlabcentral/fileexchange/76213-covidx --force
covidx_dir = fullfile(mpm_dir, 'mpm-packages', 'covidx');
assert(exist(fullfile(covidx_dir, 'covidx.m'), 'file')==2)
assert(~isempty(which('covidx')))


%
% Test Uninstall
%

%% Test that everything is removed
mpm install colorbrewer --force
mpm uninstall colorbrewer --force
colorbrewer_dir = fullfile(mpm_dir, 'mpm-packages', 'colorbrewer');
assert(exist(colorbrewer_dir, 'dir')==0)
assert(exist(fullfile(colorbrewer_dir, 'brewermap.m'), 'file')==0)
assert(isempty(which('brewermap')))


%
% Test Freeze
%

%% Test freeze returns 3 installed packages
results = evalc('mpm freeze');
assert(contains(results,'export_fig'))
assert(contains(results,'matlab2tikz==ca56d9f'))
assert(contains(results,'covidx'))


%
% Test Search
%

%% Test search returns proper
results = evalc('mpm search export_fig');
assert(contains(results,'Found url: https://api.github.com/repos/altmany/export_fig/zipball/v3.'))
