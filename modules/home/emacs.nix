{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).emacs or { };
  enabled = cfg.enable or false;

  windmoveEnabled = enabled && (cfg.windmove.enable or true);
  eventListenerEnabled = enabled && (cfg.eventListener.enable or true);
  scratchpadEnabled = enabled && (cfg.scratchpad.enable or true);
  everywhereEnabled = enabled && (cfg.everywhere.enable or true);
  orgProtocolEnabled = enabled && (cfg.orgProtocol.enable or true);

  windmoveScript = pkgs.writeShellApplication {
    name = "marchyo-cross-windmove";
    runtimeInputs = with pkgs; [
      jq
      hyprland
      procps
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

      if [ "$class" = "Emacs" ] && pgrep -u "$USER" -x emacs >/dev/null 2>&1; then
        case "$mode" in
          focus) emacsclient -e "(marchyo/windmove-or-hypr '$elisp_dir)" >/dev/null 2>&1 \
                   || hyprctl dispatch movefocus "$dir" ;;
          move)  emacsclient -e "(marchyo/move-window-or-hypr '$elisp_dir)" >/dev/null 2>&1 \
                   || hyprctl dispatch swapwindow "$dir" ;;
        esac
      else
        case "$mode" in
          focus) hyprctl dispatch movefocus "$dir" ;;
          move)  hyprctl dispatch swapwindow "$dir" ;;
        esac
      fi
    '';
  };

  scratchpadScript = pkgs.writeShellApplication {
    name = "marchyo-emacs-scratchpad";
    runtimeInputs = with pkgs; [
      hyprland
      jq
    ];
    text = ''
      # Spawn the named frame if it isn't already alive, then toggle the
      # `magic` special workspace it lives on.
      if ! hyprctl clients -j | jq -e '.[] | select(.title == "emacs-scratchpad")' >/dev/null; then
        emacsclient -c -n -F '((name . "emacs-scratchpad"))' -e '(scratch-buffer)' \
          >/dev/null 2>&1 || true
      fi
      hyprctl dispatch togglespecialworkspace magic
    '';
  };

  windmoveEl = ''
    ;;; marchyo-windmove.el --- Cross-WM windmove for Hyprland -*- lexical-binding: t -*-
    (require 'windmove)

    (defun marchyo/hyprctl (&rest args)
      "Run hyprctl ARGS; return t on success."
      (eq 0 (apply #'call-process "hyprctl" nil nil nil args)))

    (defun marchyo/windmove-or-hypr (dir)
      "Try `windmove-DIR' first; on edge, hand focus to Hyprland.
    DIR is one of `left', `right', `up', `down'."
      (let ((fn (intern (format "windmove-%s" dir)))
            (hypr (pcase dir ('left "l") ('right "r") ('up "u") ('down "d"))))
        (condition-case _
            (funcall fn)
          (user-error (marchyo/hyprctl "dispatch" "movefocus" hypr)))))

    (defun marchyo/move-window-or-hypr (dir)
      "Like `marchyo/windmove-or-hypr' but swap windows."
      (let ((fn (intern (format "windmove-swap-states-%s" dir)))
            (hypr (pcase dir ('left "l") ('right "r") ('up "u") ('down "d"))))
        (condition-case _
            (funcall fn)
          (user-error (marchyo/hyprctl "dispatch" "swapwindow" hypr)))))

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

    (defun marchyo-hypr--filter (_proc string)
      (dolist (line (split-string string "\n" t))
        (when (string-match "\\`\\([^>]+\\)>>\\(.*\\)\\'" line)
          (run-hook-with-args 'marchyo-hypr-event-hook
                              (cons (match-string 1 line)
                                    (match-string 2 line))))))

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
               :remote path
               :filter #'marchyo-hypr--filter
               :noquery t))))

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

    (defun marchyo-persp-disable ()
      (interactive)
      (remove-hook 'marchyo-hypr-event-hook #'marchyo-persp--on-event))

    (provide 'marchyo-persp)
    ;;; marchyo-persp.el ends here
  '';

  initSnippetEl = ''
    ;;; marchyo-init.el --- Bootstrap for Marchyo's Hyprland integration -*- lexical-binding: t -*-
    ;; Add this file's directory to load-path, then `(require 'marchyo-init)`
    ;; from your own init.el (or `(load "~/.config/marchyo/emacs/marchyo-init.el")`).
    ;;
    ;; Loading marchyo-init pulls in the helpers Marchyo has enabled. Wire
    ;; up perspective and event listeners explicitly so you stay in control:
    ;;
    ;;   (when (featurep 'marchyo-persp) (marchyo-persp-enable))

    (add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
    ${lib.optionalString windmoveEnabled "(require 'marchyo-windmove)"}
    ${lib.optionalString eventListenerEnabled "(require 'marchyo-hypr-events)"}
    ${lib.optionalString eventListenerEnabled "(require 'marchyo-persp)"}

    (provide 'marchyo-init)
    ;;; marchyo-init.el ends here
  '';

  hyprWindowRules = lib.optionals enabled [
    "float on, match:class ^(Emacs)$, match:title ^(emacs-scratchpad)$"
    "workspace special:magic silent, match:class ^(Emacs)$, match:title ^(emacs-scratchpad)$"
    "float on, match:class ^(Emacs)$, match:title ^(emacs-everywhere)$"
    "size 800 500, match:class ^(Emacs)$, match:title ^(emacs-everywhere)$"
    "center on, match:class ^(Emacs)$, match:title ^(emacs-everywhere)$"
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
      package = cfg.package;
      extraPackages =
        epkgs:
        (lib.optional everywhereEnabled epkgs.emacs-everywhere)
        ++ (lib.optional eventListenerEnabled epkgs.perspective);
    };

    services.emacs = {
      enable = true;
      defaultEditor = lib.mkDefault false;
    };

    home.packages = lib.mkIf everywhereEnabled (
      with pkgs;
      [
        # emacs-everywhere shells out to wl-clipboard + wtype on Wayland.
        wl-clipboard
        wtype
      ]
    );

    xdg.configFile =
      {
        "marchyo/emacs/marchyo-init.el".text = initSnippetEl;
      }
      // lib.optionalAttrs windmoveEnabled {
        "marchyo/emacs/marchyo-windmove.el".text = windmoveEl;
      }
      // lib.optionalAttrs eventListenerEnabled {
        "marchyo/emacs/marchyo-hypr-events.el".text = hyprEventsEl;
        "marchyo/emacs/marchyo-persp.el".text = perspEl;
      };

    wayland.windowManager.hyprland.settings = {
      windowrule = lib.mkAfter hyprWindowRules;
      bindd = lib.mkAfter hyprBindd;
    };
  };
}
