# Neovim configuration using nixvim
# Provides a fully-featured Neovim setup with LSP, Treesitter, and modern plugins
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  cfg = config.marchyo;
in
{
  # Enable Neovim by default when desktop or development features are enabled
  config = mkIf (cfg.desktop.enable || cfg.development.enable) {
    programs.nixvim = {
      enable = mkDefault true;

      # Use Catppuccin Mocha theme for a modern, pleasant aesthetic
      colorschemes.catppuccin = {
        enable = true;
        settings = {
          flavour = "mocha";
        };
      };

      # Core editor settings
      opts = {
        # Line numbers
        number = true;
        relativenumber = true;

        # Indentation
        tabstop = 2;
        shiftwidth = 2;
        softtabstop = 2;
        expandtab = true;
        autoindent = true;
        smartindent = true;

        # Search
        ignorecase = true;
        smartcase = true;

        # UI improvements
        termguicolors = true;
        signcolumn = "yes";
        cursorline = true;
        scrolloff = 8;
        wrap = false;

        # Mouse support
        mouse = "a";

        # System clipboard integration
        clipboard = "unnamedplus";

        # Backups
        swapfile = false;
        backup = false;
        undofile = true;
      };

      # Global settings
      globals = {
        # Set leader key to space
        mapleader = " ";
        maplocalleader = " ";
      };

      # Key mappings
      keymaps = [
        # Telescope fuzzy finder
        {
          mode = "n";
          key = "<leader>ff";
          action = "<cmd>Telescope find_files<cr>";
          options.desc = "Find files";
        }
        {
          mode = "n";
          key = "<leader>fg";
          action = "<cmd>Telescope live_grep<cr>";
          options.desc = "Live grep";
        }
        {
          mode = "n";
          key = "<leader>fb";
          action = "<cmd>Telescope buffers<cr>";
          options.desc = "Find buffers";
        }
        {
          mode = "n";
          key = "<leader>fh";
          action = "<cmd>Telescope help_tags<cr>";
          options.desc = "Help tags";
        }

        # File explorer
        {
          mode = "n";
          key = "<leader>e";
          action = "<cmd>NvimTreeToggle<cr>";
          options.desc = "Toggle file explorer";
        }

        # Comment toggle (handled by Comment.nvim via <leader>/)
        {
          mode = "n";
          key = "<leader>/";
          action = "<cmd>lua require('Comment.api').toggle.linewise.current()<cr>";
          options.desc = "Toggle comment";
        }
        {
          mode = "v";
          key = "<leader>/";
          action = "<esc><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<cr>";
          options.desc = "Toggle comment";
        }

        # Better window navigation
        {
          mode = "n";
          key = "<C-h>";
          action = "<C-w>h";
          options.desc = "Move to left window";
        }
        {
          mode = "n";
          key = "<C-j>";
          action = "<C-w>j";
          options.desc = "Move to bottom window";
        }
        {
          mode = "n";
          key = "<C-k>";
          action = "<C-w>k";
          options.desc = "Move to top window";
        }
        {
          mode = "n";
          key = "<C-l>";
          action = "<C-w>l";
          options.desc = "Move to right window";
        }

        # Buffer navigation
        {
          mode = "n";
          key = "<S-l>";
          action = "<cmd>bnext<cr>";
          options.desc = "Next buffer";
        }
        {
          mode = "n";
          key = "<S-h>";
          action = "<cmd>bprevious<cr>";
          options.desc = "Previous buffer";
        }
      ];

      # Plugin configuration
      plugins = {
        # LSP Configuration
        lsp = {
          enable = true;
          servers = {
            # Nix language server
            nil-ls = {
              enable = true;
              settings = {
                formatting = {
                  command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
                };
              };
            };

            # Bash language server
            bashls.enable = true;
          };
        };

        # Auto-completion
        cmp = {
          enable = true;
          autoEnableSources = true;
          settings = {
            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-d>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<C-e>" = "cmp.mapping.close()";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            };
            sources = [
              { name = "nvim_lsp"; }
              { name = "path"; }
              { name = "buffer"; }
            ];
          };
        };

        # Treesitter for enhanced syntax highlighting
        treesitter = {
          enable = true;
          settings = {
            highlight.enable = true;
            indent.enable = true;
          };
        };

        # Telescope fuzzy finder
        telescope = {
          enable = true;
          keymaps = {
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
            "<leader>fb" = "buffers";
            "<leader>fh" = "help_tags";
          };
          extensions = {
            fzf-native.enable = true;
          };
        };

        # Which-key for keybinding help
        which-key = {
          enable = true;
          settings = {
            spec = [
              {
                __unkeyed-1 = "<leader>f";
                group = "Find";
              }
              {
                __unkeyed-1 = "<leader>g";
                group = "Git";
              }
              {
                __unkeyed-1 = "<leader>l";
                group = "LSP";
              }
            ];
          };
        };

        # File explorer
        nvim-tree = {
          enable = true;
          autoClose = false;
          git.enable = true;
          diagnostics.enable = true;
        };

        # Status line
        lualine = {
          enable = true;
          settings = {
            options = {
              theme = "catppuccin";
              component_separators = {
                left = "|";
                right = "|";
              };
              section_separators = {
                left = "";
                right = "";
              };
            };
          };
        };

        # Comment toggling
        comment = {
          enable = true;
        };

        # Git integration
        gitsigns = {
          enable = true;
          settings = {
            current_line_blame = false;
            signs = {
              add.text = "+";
              change.text = "~";
              delete.text = "_";
              topdelete.text = "‾";
              changedelete.text = "~";
            };
          };
        };

        # Better syntax highlighting
        nvim-colorizer = {
          enable = true;
          userDefaultOptions = {
            names = false;
          };
        };

        # Auto-pairs for brackets
        nvim-autopairs.enable = true;

        # Indent guides
        indent-blankline = {
          enable = true;
          settings = {
            scope.enabled = true;
          };
        };
      };

      # Extra packages available in Neovim
      extraPackages = with pkgs; [
        # LSP servers
        nil
        bash-language-server

        # Formatters
        nixfmt-rfc-style

        # Additional tools
        ripgrep
        fd
      ];
    };
  };
}
