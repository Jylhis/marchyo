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
  # Enable VS Code when development tools are enabled
  # VS Code is a popular editor for Nix and general development
  programs.vscode = mkIf cfg.development.enable {
    enable = mkDefault true;

    # Install VS Code extensions for Nix, Git, and general development
    extensions = with pkgs.vscode-extensions; [
      # Nix language support
      jnoortheen.nix-ide # Advanced Nix IDE with LSP support (nil)
      arrterian.nix-env-selector # Nix environment selector for projects
      bbenoist.nix # Nix syntax highlighting (fallback/additional)

      # Development tools
      mkhl.direnv # Direnv integration for automatic environment loading
      esbenp.prettier-vscode # Code formatter for web technologies
      eamodio.gitlens # Enhanced Git integration and history
      github.copilot # AI pair programming assistant (optional)

      # Theme
      catppuccin.catppuccin-vsc # Catppuccin theme (Mocha variant)
    ];

    # User settings for VS Code
    userSettings = {
      # Editor appearance
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', 'monospace'";
      "editor.fontSize" = 14;
      "editor.fontLigatures" = true;

      # Theme
      "workbench.colorTheme" = "Catppuccin Mocha";
      "catppuccin.accentColor" = "mauve";

      # Editor behavior
      "editor.formatOnSave" = true;
      "editor.tabSize" = 2;
      "editor.insertSpaces" = true;
      "editor.trimAutoWhitespace" = true;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "files.trimFinalNewlines" = true;

      # Nix IDE settings (using nil LSP server)
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = lib.getExe pkgs.nil;
      "nix.serverSettings" = {
        "nil" = {
          "formatting" = {
            "command" = [ (lib.getExe pkgs.nixfmt-rfc-style) ];
          };
        };
      };

      # Git settings
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;

      # GitLens settings (reduce visual clutter)
      "gitlens.currentLine.enabled" = false;
      "gitlens.codeLens.enabled" = false;

      # Direnv integration
      "direnv.restart.automatic" = true;

      # File explorer
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;

      # Terminal
      "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
      "terminal.integrated.fontSize" = 13;

      # Telemetry (privacy)
      "telemetry.telemetryLevel" = "off";
      "redhat.telemetry.enabled" = false;
    };

    # Custom keybindings
    keybindings = [
      # Format document with Ctrl+Shift+F
      {
        key = "ctrl+shift+f";
        command = "editor.action.formatDocument";
        when = "editorHasDocumentFormattingProvider && editorTextFocus && !editorReadonly";
      }
      # Override default find in files (now Ctrl+Shift+H)
      {
        key = "ctrl+shift+h";
        command = "workbench.action.findInFiles";
      }
      {
        key = "ctrl+shift+f";
        command = "-workbench.action.findInFiles";
      }
    ];
  };
}
