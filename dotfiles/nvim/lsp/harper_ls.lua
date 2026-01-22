---@type vim.lsp.Config
return {
    cmd = { 'harper-ls', '--stdio' },
    filetypes = {
        'asciidoc',
        'c',
        'cpp',
        'cs',
        'gitcommit',
        'go',
        'html',
        'java',
        'javascript',
        'lua',
        'markdown',
        'nix',
        'python',
        'ruby',
        'rust',
        'swift',
        'toml',
        'typescript',
        'typescriptreact',
        'haskell',
        'cmake',
        'typst',
        'php',
        'dart',
        'clojure',
        'sh',
    },
    root_markers = { '.harper-dictionary.txt', '.git' },
    settings = {
        linters = {
            SpellCheck = true,
            SpelledNumbers = false,
            AnA = true,
            SentenceCapitalization = true,
            UnclosedQuotes = true,
            WrongQuotes = false,
            LongSentences = true,
            RepeatedWords = true,
            Spaces = true,
            Matcher = true,
            CorrectNumberSuffix = true
        },
        markdown = {
            IgnoreLinkTitle = false
        },
    }
}
