;;; jylhis-themes.el --- Register Jylhis themes -*- lexical-binding: t; -*-
;;
;; Author:      Markus Jylhänkangas
;; Homepage:    https://jylhis.com
;; Keywords:    faces, theme
;; Package-Requires: ((emacs "28.1"))
;;
;;; Commentary:
;;
;;  Require this file to add the Jylhis theme directory to
;;  `custom-theme-load-path'.  This is the recommended entry point for
;;  Nix consumers (trivialBuild does not process ###autoload cookies
;;  into an autoloads file, so the per-theme autoload forms never run
;;  at package-initialize time).
;;
;;  Usage:
;;    (require 'jylhis-themes)
;;    (load-theme 'jylhis-light t)   ; light
;;    (load-theme 'jylhis-dark t)   ; dark
;;
;;  With auto-dark:
;;    (require 'jylhis-themes)
;;    (setq auto-dark-light-theme 'jylhis-light
;;          auto-dark-dark-theme  'jylhis-dark)
;;    (auto-dark-mode 1)
;;
;;  Batch mode: `emacs --batch' does not run site-start.el, so
;;  custom-theme-load-path is not populated by the Nix wrapper.
;;  Guard top-level load-theme calls in init files that are
;;  byte-compiled:
;;    (unless noninteractive
;;      (load-theme 'jylhis-light t))
;;
;;; Code:

;;;###autoload
(when (boundp 'custom-theme-load-path)
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory
                (file-name-directory
                 (or load-file-name (locate-library "jylhis-themes"))))))

(provide 'jylhis-themes)
;;; jylhis-themes.el ends here
