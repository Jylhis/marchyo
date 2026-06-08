_: {
  config = {
    services.vicinae = {
      enable = true;
      settings = {
        # TUI aesthetic — opaque, sharp corners
        window = {
          opacity = 1.0;
          rounding = 0;
        };

        font = {
          size = 14;
        };
      };
    };
  };
}
