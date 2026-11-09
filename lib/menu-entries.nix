# The default command menu tree: a flat attrset keyed by dotted id. The parent
# of `a.b.c` is `a.b`; an id without a dot hangs off the root.
let
  sub =
    label: icon: order: extra:
    {
      inherit label icon order;
      action = "submenu";
    }
    // extra;

  exec =
    label: icon: order: target: extra:
    {
      inherit
        label
        icon
        order
        target
        ;
      action = "exec";
    }
    // extra;

  term =
    label: icon: order: target: extra:
    {
      inherit
        label
        icon
        order
        target
        ;
      action = "terminal";
    }
    // extra;

  provider =
    label: icon: order: name: extra:
    {
      inherit label icon order;
      action = "provider";
      provider = name;
    }
    // extra;

  # Runs after the menu closes, so a region selection does not grab the menu.
  delayed = cmd: "sleep 0.2; ${cmd}";

  statusOn = name: "test \"$(marchyo toggle ${name} --status)\" = on";

  toggle =
    name: label: order: extra:
    exec label "" order "marchyo toggle ${name}" ({ checked = statusOn name; } // extra);

  modes =
    prefix: cmd: pairs:
    builtins.listToAttrs (
      builtins.genList (
        i:
        let
          p = builtins.elemAt pairs i;
        in
        {
          name = "${prefix}.${builtins.elemAt p 0}";
          value = exec (builtins.elemAt p 1) "" (10 * (i + 1)) "${cmd} ${builtins.elemAt p 0}" { };
        }
      ) (builtins.length pairs)
    );
in
{
  apps = provider "Apps" "applications-all" 10 "apps" {
    aliases = [
      "applications"
      "launch"
    ];
  };

  capture = sub "Capture" "camera-photo" 20 {
    aliases = [
      "screen"
      "grab"
    ];
  };
  "capture.screenshot" = exec "Screenshot" "camera-photo" 10 (delayed "marchyo capture screenshot") {
    aliases = [
      "screen shot"
      "screengrab"
    ];
    description = "Select an area and save the screenshot";
  };
  "capture.annotate" =
    exec "Screenshot with annotation" "draw-freehand" 20 (delayed "marchyo capture screenshot --edit")
      {
        aliases = [
          "edit screenshot"
          "markup"
        ];
        description = "Take a screenshot and annotate it in satty";
      };
  "capture.record" = exec "Record screen" "media-record" 30 (delayed "marchyo capture record") {
    aliases = [
      "screen recording"
      "screencast"
    ];
    description = "Select an area and start recording";
    when = "! pgrep -f gpu-screen-recorder >/dev/null";
  };
  "capture.record-audio" =
    exec "Record screen with audio" "audio-input-microphone" 40
      (delayed "marchyo capture record --audio desktop")
      {
        description = "Select an area and record it with desktop audio";
        when = "! pgrep -f gpu-screen-recorder >/dev/null";
      };
  "capture.record-stop" = exec "Stop recording" "media-playback-stop" 50 "marchyo capture record" {
    aliases = [ "end recording" ];
    when = "pgrep -f gpu-screen-recorder >/dev/null";
  };
  "capture.ocr" = exec "Copy text from screen" "edit-find" 60 (delayed "marchyo capture ocr") {
    aliases = [
      "ocr"
      "text recognition"
    ];
  };
  "capture.color" = exec "Pick color" "color-select" 70 (delayed "marchyo capture color") {
    aliases = [
      "color picker"
      "eyedropper"
    ];
    description = "Copy the hex value of a screen pixel";
  };

  toggle = sub "Toggle" "preferences-system" 30 {
    aliases = [
      "switch"
      "settings"
    ];
  };
  "toggle.nightlight" = toggle "nightlight" "Night light" 10 {
    aliases = [
      "blue light"
      "hyprsunset"
    ];
  };
  "toggle.notifications" = toggle "notifications" "Notifications" 20 {
    aliases = [
      "do not disturb"
      "dnd"
    ];
  };
  "toggle.caffeine" = toggle "caffeine" "Caffeine" 30 {
    aliases = [
      "keep awake"
      "stay awake"
    ];
  };
  "toggle.idle" = toggle "idle" "Idle lock" 40 { aliases = [ "hypridle" ]; };
  "toggle.suspend" = toggle "suspend" "Automatic sleep" 50 { aliases = [ "auto suspend" ]; };
  "toggle.screensaver" = toggle "screensaver" "Screensaver" 60 { };
  "toggle.waybar" = toggle "waybar" "Top bar" 70 { aliases = [ "status bar" ]; };
  "toggle.gaps" = toggle "gaps" "Window gaps" 80 { };
  "toggle.transparency" = toggle "transparency" "Transparency" 90 { };
  "toggle.animations" = toggle "animations" "Animations" 100 { };
  "toggle.reduce-motion" = toggle "reduce-motion" "Reduce motion" 110 { aliases = [ "motion" ]; };
  "toggle.fullscreen-desktop" = toggle "fullscreen-desktop" "Fullscreen desktop" 120 { };
  "toggle.touchpad" = toggle "touchpad" "Touchpad" 130 { aliases = [ "trackpad" ]; };
  "toggle.touchscreen" = toggle "touchscreen" "Touchscreen" 140 { };
  "toggle.crash-capture" = toggle "crash-capture" "Crash capture" 150 { };

  appearance = sub "Appearance" "preferences-desktop-theme" 40 {
    aliases = [
      "look"
      "style"
    ];
  };
  "appearance.theme" = provider "Theme" "preferences-desktop-theme" 10 "themes" {
    aliases = [
      "colors"
      "color scheme"
    ];
  };
  "appearance.background" = sub "Background" "preferences-desktop-wallpaper" 20 {
    aliases = [ "wallpaper" ];
  };
  "appearance.background.wallpapers" = provider "Wallpapers" "image-x-generic" 10 "wallpapers" { };
  "appearance.background.next" = exec "Next background" "go-next" 20 "marchyo bg next" {
    aliases = [ "next wallpaper" ];
  };
  "appearance.font" = provider "Font" "preferences-desktop-font" 30 "fonts" {
    aliases = [ "typeface" ];
  };
  "appearance.transparency" = sub "Transparency" "" 40 { aliases = [ "opacity" ]; };
  "appearance.corners" = sub "Corners" "" 50 { aliases = [ "rounding" ]; };
  "appearance.gaps" = toggle "gaps" "Window gaps" 60 { };
  "appearance.motion" = toggle "reduce-motion" "Reduce motion" 70 { aliases = [ "animations" ]; };
}
// modes "appearance.transparency" "marchyo theme transparency" [
  [
    "opaque"
    "Opaque"
  ]
  [
    "transparent"
    "Transparent"
  ]
  [
    "glassy"
    "Glassy"
  ]
]
// modes "appearance.corners" "marchyo theme corners" [
  [
    "theme"
    "Theme default"
  ]
  [
    "sharp"
    "Sharp"
  ]
  [
    "rounded"
    "Rounded"
  ]
]
// {
  hardware = sub "Hardware" "computer" 50 { aliases = [ "devices" ]; };
  "hardware.audio" = exec "Audio" "audio-card" 10 "marchyo shell open audio" {
    aliases = [
      "sound"
      "volume"
    ];
  };
  "hardware.network" = exec "Network" "network-wireless" 20 "marchyo shell open network" {
    aliases = [
      "wifi"
      "wi-fi"
      "ethernet"
    ];
  };
  "hardware.bluetooth" = term "Bluetooth" "bluetooth" 30 "bluetui" { };
  "hardware.display" = exec "Display" "video-display" 40 "marchyo shell open display" {
    aliases = [
      "brightness"
      "screen"
    ];
  };
  "hardware.monitors" = term "Monitors" "video-display" 50 "hyprmon" {
    aliases = [
      "outputs"
      "resolution"
    ];
  };
  "hardware.power-profile" = provider "Power profile" "battery" 60 "power-profiles" {
    aliases = [
      "performance"
      "battery"
    ];
  };

  system = sub "System" "system-shutdown" 60 { aliases = [ "power" ]; };
  "system.lock" = exec "Lock" "system-lock-screen" 10 "marchyo lock" { aliases = [ "lock screen" ]; };
  "system.lock-suspend" =
    exec "Lock and suspend" "system-suspend" 20 "marchyo lock; marchyo suspend"
      { };
  "system.suspend" = exec "Suspend" "system-suspend" 30 "marchyo suspend" {
    aliases = [
      "sleep"
      "standby"
    ];
  };
  "system.hibernate" = exec "Hibernate" "system-suspend-hibernate" 40 "marchyo hibernate" {
    when = "test -e /etc/marchyo/hibernation";
  };
  "system.logout" = exec "Log out" "system-log-out" 50 "marchyo logout" {
    aliases = [
      "sign out"
      "exit session"
    ];
  };
  "system.reboot" = exec "Reboot" "system-reboot" 60 "marchyo reboot" { aliases = [ "restart" ]; };
  "system.firmware" = exec "Reboot to firmware" "cpu" 70 "marchyo reboot --firmware" {
    aliases = [
      "bios"
      "uefi"
    ];
  };
  "system.shutdown" = exec "Shutdown" "system-shutdown" 80 "marchyo shutdown" {
    aliases = [
      "power off"
      "turn off"
    ];
  };
  "system.restart-shell" = exec "Restart shell" "view-refresh" 90 "marchyo shell reload" {
    aliases = [ "reload shell" ];
  };
  "system.doctor" = term "Doctor" "dialog-information" 100 "marchyo doctor" {
    aliases = [
      "diagnose"
      "health check"
    ];
  };

  setup = sub "Setup" "preferences-other" 70 { aliases = [ "configure" ]; };
  "setup.language" = provider "Language" "preferences-desktop-locale" 10 "languages" { };
  "setup.agents" = provider "Agents" "applications-development" 20 "agents" {
    aliases = [ "ai" ];
  };
  "setup.keys" = {
    label = "Keyboard cheat sheet";
    icon = "input-keyboard";
    order = 30;
    action = "launcher";
    target = "keys";
    aliases = [
      "keybindings"
      "shortcuts"
      "hotkeys"
    ];
  };

  share = term "Share" "emblem-shared" 80 "marchyo share" {
    aliases = [
      "send file"
      "localsend"
    ];
  };
}
