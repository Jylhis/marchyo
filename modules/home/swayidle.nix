{
  services.swayidle = {
    enable = true;
    events = {
      before-sleep = "swaylock -f";
      after-resume = "niri msg action power-on-monitors";
    };
    timeouts = [
      {
        timeout = 150;
        command = "brightnessctl -s set 10";
        resumeCommand = "brightnessctl -r";
      }
      {
        timeout = 300;
        command = "swaylock -f";
      }
      {
        timeout = 330;
        command = "niri msg action power-off-monitors";
        resumeCommand = "niri msg action power-on-monitors";
      }
    ];
  };
}
