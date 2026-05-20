_: {
  config = {
    services.vicinae = {
      enable = true;
      settings = {
        # Jylhis Design System — no transparency, paper metaphor
        window = {
          opacity = 1.0;
          rounding = 4;
        };

        font = {
          size = 14;
        };
      };
    };
  };
}
