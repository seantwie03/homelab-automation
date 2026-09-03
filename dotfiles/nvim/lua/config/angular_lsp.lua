local M = {}

local fs, fn, uv = vim.fs, vim.fn, vim.uv

function M.find_root(bufnr)
    return fs.root(bufnr, { 'angular.json', 'nx.json' })
end

function M.node_modules(root_dir)
    local results = {}
    local project_node = fs.joinpath(root_dir, 'node_modules')
    if uv.fs_stat(project_node) then
        table.insert(results, project_node)
    end

    local mason_node = fs.normalize(fs.joinpath(vim.fn.stdpath('data'), 'mason/packages/angular-language-server/node_modules'))
    if uv.fs_stat(mason_node) then
        table.insert(results, mason_node)
    end
    return results
end

function M.core_version(root_dir)
    local package_json = fs.joinpath(root_dir, 'package.json')
    if not uv.fs_stat(package_json) then
        return ''
    end

    local ok, content = pcall(fn.readblob, package_json)
    if not ok or not content then
        return ''
    end

    local decoded, json = pcall(vim.json.decode, content)
    if not decoded or not json then
        return ''
    end
    local version = (json.dependencies or {})['@angular/core']
        or (json.devDependencies or {})['@angular/core']
        or ''
    return version:match('%d+%.%d+%.%d+') or ''
end

function M.command(root_dir)
    local node_paths = M.node_modules(root_dir)
    local ng_paths = vim.iter(node_paths):map(function(path)
        return fs.joinpath(path, '@angular/language-server/node_modules')
    end):totable()
    return {
        'ngserver',
        '--stdio',
        '--tsProbeLocations',
        table.concat(node_paths, ','),
        '--ngProbeLocations',
        table.concat(ng_paths, ','),
        '--angularCoreVersion',
        M.core_version(root_dir),
    }
end

return M
