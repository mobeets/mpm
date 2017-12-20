function opts = mpm_config()

    opts = struct();

    % override environment base directory
    opts.DEFAULT_ENVIRONMENT_BASE = '';

    % search github before searching Matlab File Exchange?
    opts.DEFAULT_CHECK_GITHUB_FIRST = false;

    % update all paths on each install?
    opts.update_mpm_paths = false;

end
