;;; jylhis-theme-toggle.el --- Switch Jylhis light/dark -*- lexical-binding: t; -*-

;;; Commentary:
;;  Minimal toggle helper. Binds to M-x jylhis-toggle-theme.
;;  Pairs with platforms/hyprland/jylhis.conf bind: SUPER+SHIFT+T.
;;
;;  If you use auto-dark to follow system appearance, you do not need
;;  this file.  Configure auto-dark-light-theme / auto-dark-dark-theme
;;  instead (see jylhis-themes.el for an example).  This toggle helper
;;  is for consumers who want a manual keybinding to switch themes.

;;; Code:

(defvar jylhis-theme-light 'jylhis-light)
(defvar jylhis-theme-dark  'jylhis-dark)

;;;###autoload
(defun jylhis-load-theme (&optional mode)
  "Load the Jylhis theme for MODE (`light' or `dark')."
  (interactive
   (list (intern (completing-read "Mode: " '(light dark) nil t))))
  (let ((target (if (eq mode 'light) jylhis-theme-light jylhis-theme-dark)))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme target t)))

;;;###autoload
(defun jylhis-toggle-theme ()
  "Toggle between Jylhis light (Paper) and dark (Black)."
  (interactive)
  (let ((current (car custom-enabled-themes)))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme (if (eq current jylhis-theme-dark)
                    jylhis-theme-light
                  jylhis-theme-dark)
                t)))

(provide 'jylhis-theme-toggle)
;;; jylhis-theme-toggle.el ends here
