%% future unit tests here. 
% !!!! not currently functional !!!
mpm install imstack % install package
opts = mpm_config(); % load the options to get dirs.
metadata_f = fullfile(opts.DEFAULT_INSTALL_DIR, 'mpm.mat');
metadata = load(metadata_f);
metadata = metadata.packages;
[~,sz] = size(metadata);
for i=1:sz
    n = metadata(i).name;
    if strcmp(n,'imtools')     
    disp(n);
    end
end
