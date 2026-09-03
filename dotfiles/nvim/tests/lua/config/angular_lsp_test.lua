local angular_lsp = require('config.angular_lsp')
local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set

local T = new_set()

T['find_root() requires an Angular workspace marker'] = function()
    local original_root = vim.fs.root
    local received
    vim.fs.root = function(...)
        received = { ... }
        return '/tmp/angular'
    end
    eq(angular_lsp.find_root(7), '/tmp/angular')
    eq(received, { 7, { 'angular.json', 'nx.json' } })
    vim.fs.root = original_root
end

T['core_version() reads and normalizes @angular/core'] = function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    vim.fn.writefile({ '{"dependencies":{"@angular/core":"^20.2.1"}}' }, root .. '/package.json')
    eq(angular_lsp.core_version(root), '20.2.1')
    vim.fn.delete(root, 'rf')
end

T['command() supplies both probe families and the Angular version'] = function()
    local original_node_modules = angular_lsp.node_modules
    local original_core_version = angular_lsp.core_version
    angular_lsp.node_modules = function()
        return { '/tmp/project/node_modules' }
    end
    angular_lsp.core_version = function()
        return '20.2.1'
    end

    eq(angular_lsp.command('/tmp/project'), {
        'ngserver',
        '--stdio',
        '--tsProbeLocations',
        '/tmp/project/node_modules',
        '--ngProbeLocations',
        '/tmp/project/node_modules/@angular/language-server/node_modules',
        '--angularCoreVersion',
        '20.2.1',
    })

    angular_lsp.node_modules = original_node_modules
    angular_lsp.core_version = original_core_version
end

return T
