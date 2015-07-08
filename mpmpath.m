% 0. make sure the environment variable MPM_MATLABPATH is defined in ~/.bash_profile
% 1. place this script somewhere in your Matlab's search path
% 2. call this script in your Matlab startup.m file
%       as well as after installing new packages with 'mpm'
%

[~,mpmenv] = system('source ~/.bash_profile; echo $MPM_MATLABPATH');
mpm_install_dir = mpmenv(1:end-1);
addpath(genpath(mpm_install_dir));
