clear

addpath(fullfile(fileparts(mfilename), '..'))

%% test install

% Does not work
% mpm install export_fig -u http://www.mathworks.com/matlabcentral/fileexchange/23629-export-fig
% mpm install matlab2tikz -t 1.0.0

% Works
% mpm install export_fig -u https://github.com/altmany/export_fig.git --force
% mpm install matlab2tikz --force

mpm install colorbrewer --force


install_dir = fullfile(fileparts(mfilename('fullpath')), '..', ...
    'mpm-packages', 'colorbrewer');

% test that the directory has been created
% that the file is there and has been added to the path
assert(exist(install_dir, 'dir')==7); 

cd(install_dir)
assert(exist(fullfile(pwd, 'brewermap.m'), 'file')==2)

assert(isequal(which('brewermap'), fullfile(pwd, 'brewermap.m')))


%% test uninstall

mpm uninstall colorbrewer --force

% test that everything is removed
assert(exist(install_dir, 'dir')==0); 
assert(exist(fullfile(pwd, 'brewermap.m'), 'file')==0)
assert(isequal(which('brewermap'), ''))



