return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = {
        "mason-org/mason.nvim",
    },
    opts = {
        ensure_installed = {
            "ansible-language-server",
            "harper-ls",
            "jdtls",
            "kotlin-language-server",
            "lua-language-server",
            "pyright",
            "typescript-language-server",
            "yaml-language-server",
        },
    },
}
