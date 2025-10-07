# Neovim configuration
# Provides a fully-featured Neovim setup with LSP, Treesitter, and modern plugins
# Note: This uses Home Manager's programs.neovim with Lua configuration
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault getExe;
in
{
  # Enable Neovim by default when development tools are enabled
  # Neovim is the preferred terminal editor for Nix and general development
  config = mkIf (config.marchyo.development.enable or false) {
    programs.neovim = {
      enable = mkDefault true;
      defaultEditor = mkDefault true;
      viAlias = true;
      vimAlias = true;

      # Install plugins
      plugins = with pkgs.vimPlugins; [
        # Theme
        catppuccin-nvim

        # LSP and completion
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path

        # Treesitter for syntax highlighting
        (nvim-treesitter.withPlugins (
          plugins: with plugins; [
            nix
            bash
            lua
            vim
            json
            yaml
            toml
            markdown
          ]
        ))

        # Fuzzy finder
        telescope-nvim
        telescope-fzf-native-nvim

        # File explorer
        nvim-tree-lua

        # Status line
        lualine-nvim

        # Which-key for keybinding help
        which-key-nvim

        # Comment toggling
        comment-nvim

        # Git integration
        gitsigns-nvim

        # Color highlighter
        nvim-colorizer-lua

        # Auto-pairs
        nvim-autopairs

        # Indent guides
        indent-blankline-nvim

        # Icons (required by nvim-tree and lualine)
        nvim-web-devicons
      ];

      # Neovim configuration in Lua
      extraLuaConfig = ''
        -- Core editor settings
        vim.opt.number = true
        vim.opt.relativenumber = true

        -- Indentation
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.softtabstop = 2
        vim.opt.expandtab = true
        vim.opt.autoindent = true
        vim.opt.smartindent = true

        -- Search
        vim.opt.ignorecase = true
        vim.opt.smartcase = true

        -- UI improvements
        vim.opt.termguicolors = true
        vim.opt.signcolumn = "yes"
        vim.opt.cursorline = true
        vim.opt.scrolloff = 8
        vim.opt.wrap = false

        -- Mouse support
        vim.opt.mouse = "a"

        -- System clipboard integration
        vim.opt.clipboard = "unnamedplus"

        -- Backups
        vim.opt.swapfile = false
        vim.opt.backup = false
        vim.opt.undofile = true

        -- Leader key
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        -- Catppuccin theme
        require("catppuccin").setup({
          flavour = "mocha",
          transparent_background = false,
        })
        vim.cmd.colorscheme "catppuccin"

        -- LSP Configuration
        local lspconfig = require('lspconfig')
        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        -- Nix LSP
        lspconfig.nil_ls.setup({
          capabilities = capabilities,
          settings = {
            ['nil'] = {
              formatting = {
                command = { "${getExe pkgs.nixfmt-rfc-style}" },
              },
            },
          },
        })

        -- Bash LSP
        lspconfig.bashls.setup({
          capabilities = capabilities,
        })

        -- Auto-completion setup
        local cmp = require('cmp')
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<C-d>'] = cmp.mapping.scroll_docs(-4),
            ['<C-f>'] = cmp.mapping.scroll_docs(4),
            ['<C-e>'] = cmp.mapping.close(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
            ['<Tab>'] = cmp.mapping.select_next_item(),
            ['<S-Tab>'] = cmp.mapping.select_prev_item(),
          }),
          sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'path' },
            { name = 'buffer' },
          }),
        })

        -- Treesitter configuration
        require('nvim-treesitter.configs').setup({
          highlight = {
            enable = true,
          },
          indent = {
            enable = true,
          },
        })

        -- Telescope setup
        require('telescope').setup({
          extensions = {
            fzf = {
              fuzzy = true,
              override_generic_sorter = true,
              override_file_sorter = true,
              case_mode = "smart_case",
            }
          }
        })
        require('telescope').load_extension('fzf')

        -- Telescope keymaps
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })

        -- Which-key setup
        require("which-key").setup()

        -- Register which-key groups
        require("which-key").add({
          { "<leader>f", group = "Find" },
          { "<leader>g", group = "Git" },
          { "<leader>l", group = "LSP" },
        })

        -- File explorer setup
        require("nvim-tree").setup({
          git = {
            enable = true,
          },
          diagnostics = {
            enable = true,
          },
        })

        -- File explorer keymaps
        vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'Toggle file explorer' })

        -- Status line setup
        require('lualine').setup({
          options = {
            theme = 'catppuccin',
            component_separators = { left = '|', right = '|' },
            section_separators = { left = ${"''"}, right = ${"''"} },
          },
        })

        -- Comment plugin setup
        require('Comment').setup()

        -- Comment keymaps
        vim.keymap.set('n', '<leader>/', function()
          require('Comment.api').toggle.linewise.current()
        end, { desc = 'Toggle comment' })
        vim.keymap.set('v', '<leader>/', "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>", { desc = 'Toggle comment' })

        -- Gitsigns setup
        require('gitsigns').setup({
          current_line_blame = false,
          signs = {
            add          = { text = '+' },
            change       = { text = '~' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
          },
        })

        -- Colorizer setup
        require('colorizer').setup({
          user_default_options = {
            names = false,
          },
        })

        -- Auto-pairs setup
        require('nvim-autopairs').setup()

        -- Indent blankline setup
        require('ibl').setup({
          scope = {
            enabled = true,
          },
        })

        -- Window navigation keymaps
        vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
        vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom window' })
        vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to top window' })
        vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

        -- Buffer navigation keymaps
        vim.keymap.set('n', '<S-l>', ':bnext<CR>', { desc = 'Next buffer' })
        vim.keymap.set('n', '<S-h>', ':bprevious<CR>', { desc = 'Previous buffer' })
      '';

      # Extra packages available to Neovim
      extraPackages = with pkgs; [
        # LSP servers
        nil
        bash-language-server

        # Formatters
        nixfmt-rfc-style

        # Additional tools for telescope
        ripgrep
        fd
      ];
    };
  };
}
