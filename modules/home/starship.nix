# Starship prompt — Jylhis Design System
# Uses ANSI color names so the terminal palette (tokens.json ANSI 16) applies.
# ANSI 11 (yellow) = brand copper — intentional override.
_: {
  config = {
    programs.starship = {
      enable = true;
      settings = {
        format = "$directory$git_branch$git_status$nix_shell$cmd_duration\n$character";
        add_newline = false;

        character = {
          success_symbol = "[\\u00bb](yellow)";
          error_symbol = "[\\u00bb](red)";
        };

        directory = {
          style = "yellow";
          truncation_length = 3;
          truncate_to_repo = true;
          home_symbol = "~";
        };

        git_branch = {
          format = " on [$branch]($style)";
          style = "green";
          symbol = "";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style)";
          style = "yellow";
          conflicted = "=";
          ahead = " \u2191\${count}";
          behind = " \u2193\${count}";
          diverged = " \u2195\${ahead_count}/\${behind_count}";
          untracked = " ?";
          stashed = " *";
          modified = " \u2717";
          staged = " \u271a";
          renamed = " \u00bb";
          deleted = " \u2716";
        };

        nix_shell = {
          format = " [(nix)]($style)";
          style = "cyan";
          impure_msg = "";
          pure_msg = "";
        };

        cmd_duration = {
          format = " [took $duration](bright-black)";
          min_time = 2000;
        };

        time = {
          disabled = false;
          format = "[$time](bright-black)";
          time_format = "%H:%M";
        };
      };
    };
  };
}
