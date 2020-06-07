clear
mpm_dir = fullfile(pwd, '..');
addpath(mpm_dir)

% test install zip - default master branch
mpm install matlab2tikz -u https://github.com/matlab2tikz/matlab2tikz.git --force
matlab2tikz_dir = fullfile(mpm_dir, 'mpm-packages', 'matlab2tikz')
assert(exist(fullfile(matlab2tikz_dir, 'src/matlab2tikz.m'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

% test install zip - specific tag
mpm install matlab2tikz -t 0.4.7 -u https://github.com/matlab2tikz/matlab2tikz.git --force
assert(exist(fullfile(matlab2tikz_dir, 'version-0.4.7'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

% test install zip - specific branch
mpm install matlab2tikz -t develop -u https://github.com/matlab2tikz/matlab2tikz.git --force
assert(exist(fullfile(matlab2tikz_dir, 'test/suites/ACID.Octave.4.2.0.md5'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

% test install zip - specific commit hash
mpm install matlab2tikz -t ca56d9f -u https://github.com/matlab2tikz/matlab2tikz.git --force
assert(exist(fullfile(matlab2tikz_dir, 'version-0.3.3'), 'file')==2)
assert(~isempty(which('matlab2tikz')))

% Does not work
% mpm install export_fig -u http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
% mpm install matlab2tikz -t 1.0.0

% Works
% mpm install export_fig -u https://github.com/altmany/export_fig.git --force
% mpm install matlab2tikz --force

mpm install colorbrewer --force
colorbrewer_dir = fullfile(mpm_dir, 'mpm-packages', 'colorbrewer');

% test that the directory has been created
% that the file is there and has been added to the path
assert(exist(colorbrewer_dir, 'dir')==7)
assert(exist(fullfile(colorbrewer_dir, 'brewermap.m'), 'file')==2)
assert(~isempty(which('brewermap')))

%% test uninstall
mpm uninstall colorbrewer --force

% test that everything is removed
assert(exist(colorbrewer_dir, 'dir')==0)
assert(exist(fullfile(colorbrewer_dir, 'brewermap.m'), 'file')==0)
assert(isempty(which('brewermap')))
