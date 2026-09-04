---@brief
---Pre-alpha official Kotlin support for Visual Studio Code and an implementation of Language Server Protocol for the Kotlin language.
---
---The server is based on IntelliJ IDEA and the IntelliJ IDEA Kotlin Plugin implementation.

--- The presence of one of these files indicates a project root directory
--
--  These are configuration files for the various build systems supported by
--  Kotlin.

local diagnostic_group = vim.api.nvim_create_augroup('my.kotlin_lsp', { clear = true })

local function refresh_diagnostics(client, bufnr)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    client:request('textDocument/diagnostic', {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
    }, nil, bufnr)
end

local function attach_diagnostic_refresh(client, bufnr)
    if vim.api.nvim_get_autocmds({ buffer = bufnr, group = diagnostic_group })[1] then
        return
    end

    vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        group = diagnostic_group,
        buffer = bufnr,
        callback = function()
            refresh_diagnostics(client, bufnr)
        end,
        desc = 'Refresh Kotlin diagnostics',
    })

    -- The alpha Kotlin server can finish project import without prompting
    -- Neovim to repeat its initial diagnostic pull.
    vim.defer_fn(function()
        if client.attached_buffers[bufnr] then
            refresh_diagnostics(client, bufnr)
        end
    end, 5000)
end

---@type vim.lsp.Config
return {
    filetypes = { 'kotlin' },
    cmd = { 'intellij-server', '--stdio' },
    root_markers = {
        'settings.gradle', -- Gradle (multi-project)
        'settings.gradle.kts', -- Gradle (multi-project)
        'pom.xml', -- Maven
        'build.gradle', -- Gradle
        'build.gradle.kts', -- Gradle
        'workspace.json', -- Used to integrate your own build system
    },
    on_attach = attach_diagnostic_refresh,
}
