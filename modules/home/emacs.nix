{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).emacs or { };
  enabled = cfg.enable or false;
  emacsPkg = cfg.package or pkgs.emacs-pgtk;

  windmoveEnabled = enabled && (cfg.windmove.enable or true);
  eventListenerEnabled = enabled && (cfg.eventListener.enable or true);
  scratchpadEnabled = enabled && (cfg.scratchpad.enable or true);
  everywhereEnabled = enabled && (cfg.everywhere.enable or true);
  orgProtocolEnabled = enabled && (cfg.orgProtocol.enable or true);

  needsElispPkg = windmoveEnabled || eventListenerEnabled;

  windmoveEl = ''
    ;;; marchyo-windmove.el --- Cross-WM windmove for Hyprland -*- lexical-binding: t -*-
    (require 'windmove)

    (defun marchyo--hyprctl (&rest args)
      "Run hyprctl ARGS; return t on success."
      (eq 0 (apply #'call-process "hyprctl" nil nil nil args)))

    ;;;###autoload
    (defun marchyo/windmove-or-hypr (dir)
      "Try `windmove-DIR' first; on edge, hand focus to Hyprland.
    DIR is one of `left', `right', `up', `down'."
      (let ((fn (intern (format "windmove-%s" dir)))
            (hypr (pcase dir ('left "l") ('right "r") ('up "u") ('down "d"))))
        (condition-case _
            (funcall fn)
          (user-error (marchyo--hyprctl "dispatch" "movefocus" hypr)))))

    ;;;###autoload
    (defun marchyo/move-window-or-hypr (dir)
      "Like `marchyo/windmove-or-hypr' but swap windows."
      (let ((fn (intern (format "windmove-swap-states-%s" dir)))
            (hypr (pcase dir ('left "l") ('right "r") ('up "u") ('down "d"))))
        (condition-case _
            (funcall fn)
          (user-error (marchyo--hyprctl "dispatch" "swapwindow" hypr)))))

    (provide 'marchyo-windmove)
    ;;; marchyo-windmove.el ends here
  '';

  hyprEventsEl = ''
    ;;; marchyo-hypr-events.el --- Subscribe to Hyprland IPC events -*- lexical-binding: t -*-
    (defvar marchyo-hypr-event-process nil)
    (defvar marchyo-hypr-event-hook nil
      "Hook run for every Hyprland event.
    Each function receives one cons cell (EVENT-NAME . DATA-STRING).")

    (defun marchyo-hypr--socket-path ()
      (let ((sig (getenv "HYPRLAND_INSTANCE_SIGNATURE"))
            (run (getenv "XDG_RUNTIME_DIR")))
        (when (and sig run)
          (format "%s/hypr/%s/.socket2.sock" run sig))))

    (defun marchyo-hypr--filter (proc string)
      "Buffer PROC output until newline-terminated lines arrive, then dispatch."
      (let* ((pending (or (process-get proc 'marchyo-pending) ""))
             (full (concat pending string))
             (parts (split-string full "\n"))
             (last (car (last parts)))
             (lines (butlast parts)))
        (process-put proc 'marchyo-pending last)
        (dolist (line lines)
          (when (string-match "\\`\\([^>]+\\)>>\\(.*\\)\\'" line)
            (run-hook-with-args 'marchyo-hypr-event-hook
                                (cons (match-string 1 line)
                                      (match-string 2 line)))))))

    ;;;###autoload
    (defun marchyo-hypr-event-start ()
      "Connect to the Hyprland event socket."
      (interactive)
      (let ((path (marchyo-hypr--socket-path)))
        (unless path
          (user-error "Hyprland sockets not available (HYPRLAND_INSTANCE_SIGNATURE unset)"))
        (when (process-live-p marchyo-hypr-event-process)
          (delete-process marchyo-hypr-event-process))
        (setq marchyo-hypr-event-process
              (make-network-process
               :name "marchyo-hypr-events"
               :family 'local
               :service path
               :filter #'marchyo-hypr--filter
               :noquery t))))

    ;;;###autoload
    (defun marchyo-hypr-event-stop ()
      "Disconnect from the Hyprland event socket."
      (interactive)
      (when (process-live-p marchyo-hypr-event-process)
        (delete-process marchyo-hypr-event-process)
        (setq marchyo-hypr-event-process nil)))

    (provide 'marchyo-hypr-events)
    ;;; marchyo-hypr-events.el ends here
  '';

  perspEl = ''
    ;;; marchyo-persp.el --- Follow Hyprland workspaces with perspective.el -*- lexical-binding: t -*-
    (require 'marchyo-hypr-events)
    (autoload 'persp-switch "perspective" nil t)

    (defun marchyo-persp--on-event (event)
      (pcase event
        (`("workspace" . ,name)
         (when (fboundp 'persp-switch)
           (persp-switch (format "ws%s" name))))))

    ;;;###autoload
    (defun marchyo-persp-enable ()
      "Subscribe to Hyprland events and mirror them onto perspective.el."
      (interactive)
      (add-hook 'marchyo-hypr-event-hook #'marchyo-persp--on-event)
      (marchyo-hypr-event-start))

    ;;;###autoload
    (defun marchyo-persp-disable ()
      "Stop mirroring Hyprland workspaces onto perspective.el."
      (interactive)
      (remove-hook 'marchyo-hypr-event-hook #'marchyo-persp--on-event))

    (provide 'marchyo-persp)
    ;;; marchyo-persp.el ends here
  '';

  elispSrc = pkgs.runCommand "marchyo-hypr-elisp-src" { } ''
    mkdir -p $out
    ${lib.optionalString windmoveEnabled ''
      install -m644 ${pkgs.writeText "marchyo-windmove.el" windmoveEl} $out/marchyo-windmove.el
    ''}
    ${lib.optionalString eventListenerEnabled ''
      install -m644 ${pkgs.writeText "marchyo-hypr-events.el" hyprEventsEl} $out/marchyo-hypr-events.el
      install -m644 ${pkgs.writeText "marchyo-persp.el" perspEl} $out/marchyo-persp.el
    ''}
  '';

  windmoveScript = pkgs.writeShellApplication {
    name = "marchyo-cross-windmove";
    runtimeInputs = [
      pkgs.jq
      pkgs.hyprland
      pkgs.procps
      emacsPkg
    ];
    text = ''
      mode="''${1:-focus}"
      dir="''${2:-}"
      case "$dir" in l|r|u|d) ;; *) echo "usage: $0 <focus|move> <l|r|u|d>" >&2; exit 2 ;; esac

      case "$dir" in
        l) elisp_dir=left ;;
        r) elisp_dir=right ;;
        u) elisp_dir=up ;;
        d) elisp_dir=down ;;
      esac

      class="$(hyprctl activewindow -j | jq -r '.class // ""')"

      case "$class" in
        Emacs|emacs)
          if pgrep -u "$USER" -x emacs >/dev/null 2>&1; then
            case "$mode" in
              focus)
                emacsclient -e "(marchyo/windmove-or-hypr '$elisp_dir)" >/dev/null 2>&1 \
                  || hyprctl dispatch movefocus "$dir"
                ;;
              move)
                emacsclient -e "(marchyo/move-window-or-hypr '$elisp_dir)" >/dev/null 2>&1 \
                  || hyprctl dispatch swapwindow "$dir"
                ;;
            esac
          else
            case "$mode" in
              focus) hyprctl dispatch movefocus "$dir" ;;
              move)  hyprctl dispatch swapwindow "$dir" ;;
            esac
          fi
          ;;
        *)
          case "$mode" in
            focus) hyprctl dispatch movefocus "$dir" ;;
            move)  hyprctl dispatch swapwindow "$dir" ;;
          esac
          ;;
      esac
    '';
  };

  scratchpadScript = pkgs.writeShellApplication {
    name = "marchyo-emacs-scratchpad";
    runtimeInputs = [
      pkgs.hyprland
      emacsPkg
    ];
    text = ''
      # Ask the Emacs daemon whether the named frame already exists, and only
      # spawn one if not. Querying the frame list directly is more reliable
      # than parsing `hyprctl clients` because the user can change the
      # scratchpad buffer (and therefore the window title) without Emacs
      # renaming the frame.
      have_frame=$(emacsclient -e \
        "(if (member \"emacs-scratchpad\" (mapcar (lambda (f) (frame-parameter f 'name)) (frame-list))) t nil)" \
        2>/dev/null || echo nil)
      if [ "$have_frame" != "t" ]; then
        emacsclient -c -n \
          -F '((name . "emacs-scratchpad") (title . "emacs-scratchpad"))' \
          -e '(scratch-buffer)' >/dev/null 2>&1 || true
      fi
      hyprctl dispatch togglespecialworkspace magic
    '';
  };

  # pgtk reports the Wayland app-id as lowercase `emacs`; X11/native uses
  # uppercase `Emacs`. Match both so the rules apply regardless of build.
  hyprWindowRules = lib.optionals enabled [
    "float on, match:class ^(Emacs|emacs)$, match:title ^(emacs-scratchpad)$"
    "workspace special:magic silent, match:class ^(Emacs|emacs)$, match:title ^(emacs-scratchpad)$"
    "float on, match:class ^(Emacs|emacs)$, match:title ^(emacs-everywhere)$"
    "size 800 500, match:class ^(Emacs|emacs)$, match:title ^(emacs-everywhere)$"
    "center on, match:class ^(Emacs|emacs)$, match:title ^(emacs-everywhere)$"
  ];

  hyprBindd =
    lib.optionals enabled [
      "SUPER SHIFT, E, New Emacs frame, exec, emacsclient -c -n"
    ]
    ++ lib.optionals windmoveEnabled [
      "SUPER ALT, H, Focus window (Emacs-aware) left,  exec, ${windmoveScript}/bin/marchyo-cross-windmove focus l"
      "SUPER ALT, L, Focus window (Emacs-aware) right, exec, ${windmoveScript}/bin/marchyo-cross-windmove focus r"
      "SUPER ALT, K, Focus window (Emacs-aware) up,    exec, ${windmoveScript}/bin/marchyo-cross-windmove focus u"
      "SUPER ALT, J, Focus window (Emacs-aware) down,  exec, ${windmoveScript}/bin/marchyo-cross-windmove focus d"
      "SUPER ALT SHIFT, H, Swap window (Emacs-aware) left,  exec, ${windmoveScript}/bin/marchyo-cross-windmove move l"
      "SUPER ALT SHIFT, L, Swap window (Emacs-aware) right, exec, ${windmoveScript}/bin/marchyo-cross-windmove move r"
      "SUPER ALT SHIFT, K, Swap window (Emacs-aware) up,    exec, ${windmoveScript}/bin/marchyo-cross-windmove move u"
      "SUPER ALT SHIFT, J, Swap window (Emacs-aware) down,  exec, ${windmoveScript}/bin/marchyo-cross-windmove move d"
    ]
    ++ lib.optionals scratchpadEnabled [
      "SUPER, Z, Emacs scratchpad, exec, ${scratchpadScript}/bin/marchyo-emacs-scratchpad"
    ]
    ++ lib.optionals everywhereEnabled [
      "SUPER CTRL, E, Emacs everywhere, exec, emacsclient -ne '(emacs-everywhere)'"
    ]
    ++ lib.optionals orgProtocolEnabled [
      "SUPER SHIFT, C, Org capture, exec, emacsclient -c -n -e '(org-capture)'"
    ];
in
{
  config = lib.mkIf enabled {
    programs.emacs = {
      enable = true;
      package = emacsPkg;
      # Ship the integration as a real Emacs package so the autoload cookies
      # on `marchyo/windmove-or-hypr` & co. are registered at daemon
      # startup — no manual `(require)` from the user's init.el needed.
      extraPackages =
        epkgs:
        let
          marchyoElisp = epkgs.trivialBuild {
            pname = "marchyo-hypr";
            version = "0.1.0";
            src = elispSrc;
          };
        in
        (lib.optional needsElispPkg marchyoElisp)
        ++ (lib.optional everywhereEnabled epkgs.emacs-everywhere)
        ++ (lib.optional eventListenerEnabled epkgs.perspective);
    };

    services.emacs = {
      enable = true;
      defaultEditor = lib.mkDefault false;
      # `services.emacs.client.enable` installs `emacsclient.desktop`, which
      # both the editor MIME registration (modules/home/xdg.nix) and the
      # org-protocol URL handler resolve to. Without it those handlers point
      # at a missing desktop file.
      client.enable = lib.mkDefault true;
    };

    home.packages = lib.mkIf everywhereEnabled (
      with pkgs;
      [
        wl-clipboard
        wtype
      ]
    );

    wayland.windowManager.hyprland.settings = {
      windowrule = lib.mkAfter hyprWindowRules;
      bindd = lib.mkAfter hyprBindd;
    };
  };
}
