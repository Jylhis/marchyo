;;; jylhis-dark-theme.el --- Jylhis dark theme  -*- lexical-binding: t; -*-
;;
;; GENERATED from tokens.core.json + themes/jylhis.json. Do not edit by hand.
;; Run: bun scripts/generate.mjs
;;
;; Author:      Markus Jylhänkangas
;; Homepage:    https://jylhis.com
;; Keywords:    faces, theme
;; Package-Requires: ((emacs "28.1"))
;;
;;; Commentary:
;;
;;  Dark "field" edition of the Jylhis design system for Emacs.
;;  Modus-style semantic face targeting — source of truth: themes/jylhis.json
;;  palette and design(7) Keyboard for the shared primitives (focus, kbd,
;;  selected-item language).  A sibling `jylhis-dark-theme.el` ships the light
;;  variant; both reuse the same semantic face map below.
;;
;;  Install:
;;    (add-to-list 'custom-theme-load-path "~/.config/emacs/themes/")
;;    (load-theme 'jylhis-dark t)
;;    ;; Toggle:
;;    (defun jylhis-toggle-theme ()
;;      (interactive)
;;      (if (car custom-enabled-themes)
;;          (progn (disable-theme (car custom-enabled-themes))
;;                 (load-theme (if (eq (car custom-enabled-themes) 'jylhis-dark)
;;                                 'jylhis-dark 'jylhis-dark) t))))
;;
;;; Code:

(deftheme jylhis-dark
  "Jylhis — dark theme. International-orange accent on black, Modus Vivendi syntax.")

(let ((class '((class color) (min-colors 256)))

      ;; ── Core palette (themes/jylhis.json, dark column) ──
      (bg            "#0b0b0b")
      (bg-subtle     "#141210")
      (surface       "#1a1713")
      (surface-raised "#221e18")
      (fg            "#f2ede4")
      (fg-muted      "#9c9488")
      (fg-heading    "#f7f3ec")
      (fg-faint      "#746a5c")
      (accent        "#8ab8ff")
      (accent-hover  "#f7f3ec")
      (accent-subtle "#3a3020")
      (brand         "#8ab8ff")
      (border        "#786e60")
      (border-strong "#8a8070")
      (decorator     "#8a8070")

      ;; ── Syntax / semantic — Modus role taxonomy (themes/jylhis.json) ──
      (syn-keyword   "#ab8fff") ; violet
      (syn-string    "#00bb18") ; green
      (syn-number    "#749fff") ; blue
      (syn-function  "#ff6db6") ; magenta
      (syn-builtin   "#ff5fec") ; olive
      (syn-type      "#00b78f") ; teal
      (syn-variable  "#00b8c6") ; sky
      (syn-tag       "#00b78f") ; alias of type
      (syn-comment   "#979796") ; from red-faint
      (syn-docstring "#92a07e") ; muted green
      ;; Semantic status — Modus red/yellow/green/blue accents
      (err  "#ff6a5a")
      (warn "#ffd08a")
      (ok   "#7fd18a")
      (info "#4fd1bd"))

  (custom-theme-set-faces
   'jylhis-dark

   ;; ─────────────────────────────────────────────
   ;; Frame / base
   ;; ─────────────────────────────────────────────
   `(default             ((,class :background ,bg :foreground ,fg)))
   `(cursor              ((,class :background ,accent)))
   `(fringe              ((,class :background ,bg)))
   `(vertical-border     ((,class :foreground ,border)))
   `(window-divider      ((,class :foreground ,border)))
   `(window-divider-first-pixel  ((,class :foreground ,border)))
   `(window-divider-last-pixel   ((,class :foreground ,border)))
   `(shadow              ((,class :foreground ,fg-faint)))

   ;; ─────────────────────────────────────────────
   ;; Text emphasis
   ;; ─────────────────────────────────────────────
   `(bold                ((,class :weight bold :foreground ,fg-heading)))
   `(italic              ((,class :slant italic)))
   `(underline           ((,class :underline (:color ,fg-muted))))
   `(link                ((,class :foreground ,accent :underline (:color ,accent))))
   `(link-visited        ((,class :foreground ,syn-number :underline (:color ,syn-number))))

   ;; ─────────────────────────────────────────────
   ;; Selection + region  (design(7) Keyboards)
   ;; ─────────────────────────────────────────────
   `(region              ((,class :background ,accent-subtle :extend t)))
   `(secondary-selection ((,class :background ,surface :extend t)))
   `(highlight           ((,class :background ,surface-raised :extend t)))
   `(hl-line             ((,class :background ,bg-subtle :extend t)))
   `(match               ((,class :background ,accent-subtle :foreground ,accent :weight bold)))
   `(isearch             ((,class :background ,accent :foreground ,bg :weight bold)))
   `(isearch-fail        ((,class :background ,err :foreground ,bg)))
   `(lazy-highlight      ((,class :background ,accent-subtle :foreground ,fg)))

   ;; ─────────────────────────────────────────────
   ;; Mode line
   ;; ─────────────────────────────────────────────
   `(mode-line
     ((,class :background ,surface :foreground ,fg
              :box (:line-width 3 :color ,surface))))
   `(mode-line-inactive
     ((,class :background ,bg-subtle :foreground ,fg-muted
              :box (:line-width 3 :color ,bg-subtle))))
   `(mode-line-highlight ((,class :foreground ,accent :background ,surface-raised)))
   `(mode-line-emphasis  ((,class :foreground ,accent :weight bold)))
   `(mode-line-buffer-id ((,class :foreground ,fg-heading :weight bold)))

   ;; doom-modeline
   `(doom-modeline-bar              ((,class :background ,accent)))
   `(doom-modeline-bar-inactive     ((,class :background ,surface)))
   `(doom-modeline-buffer-file      ((,class :foreground ,fg-heading :weight bold)))
   `(doom-modeline-buffer-modified  ((,class :foreground ,warn :weight bold)))
   `(doom-modeline-buffer-major-mode ((,class :foreground ,syn-tag :weight bold)))
   `(doom-modeline-project-dir      ((,class :foreground ,fg-muted)))
   `(doom-modeline-info             ((,class :foreground ,ok)))
   `(doom-modeline-warning          ((,class :foreground ,warn)))
   `(doom-modeline-urgent           ((,class :foreground ,err)))
   `(doom-modeline-lsp-success      ((,class :foreground ,ok)))
   `(doom-modeline-lsp-warning      ((,class :foreground ,warn)))
   `(doom-modeline-lsp-error        ((,class :foreground ,err)))

   ;; Header-line = the "second toolbar". Kept quiet.
   `(header-line          ((,class :background ,bg-subtle :foreground ,fg-muted
                                   :box (:line-width 3 :color ,bg-subtle))))

   ;; Tab-bar / tab-line — selected tab uses the canonical language
   `(tab-bar              ((,class :background ,bg-subtle :foreground ,fg-muted)))
   `(tab-bar-tab          ((,class :background ,surface :foreground ,fg
                                   :box (:line-width 3 :color ,surface)
                                   :weight bold)))
   `(tab-bar-tab-inactive ((,class :background ,bg-subtle :foreground ,fg-muted
                                   :box (:line-width 3 :color ,bg-subtle))))

   ;; ─────────────────────────────────────────────
   ;; Minibuffer / echo area
   ;; ─────────────────────────────────────────────
   `(minibuffer-prompt    ((,class :foreground ,accent :weight bold)))
   `(error                ((,class :foreground ,err   :weight bold)))
   `(warning              ((,class :foreground ,warn  :weight bold)))
   `(success              ((,class :foreground ,ok    :weight bold)))

   ;; ─────────────────────────────────────────────
   ;; Font-lock  (semantic face mapping, themes/jylhis.json)
   ;; ─────────────────────────────────────────────
   `(font-lock-builtin-face          ((,class :foreground ,syn-builtin)))
   `(font-lock-comment-face          ((,class :foreground ,syn-comment :slant italic)))
   `(font-lock-comment-delimiter-face ((,class :foreground ,syn-comment)))
   `(font-lock-constant-face         ((,class :foreground ,syn-number)))
   `(font-lock-doc-face              ((,class :foreground ,syn-docstring :slant italic)))
   `(font-lock-function-name-face    ((,class :foreground ,syn-function :weight bold)))
   `(font-lock-keyword-face          ((,class :foreground ,syn-keyword :weight bold)))
   `(font-lock-negation-char-face    ((,class :foreground ,err)))
   `(font-lock-preprocessor-face     ((,class :foreground ,syn-builtin)))
   `(font-lock-regexp-grouping-backslash ((,class :foreground ,syn-function :weight bold)))
   `(font-lock-regexp-grouping-construct ((,class :foreground ,syn-keyword :weight bold)))
   `(font-lock-string-face           ((,class :foreground ,syn-string)))
   `(font-lock-type-face             ((,class :foreground ,syn-type)))
   `(font-lock-variable-name-face    ((,class :foreground ,syn-variable)))
   `(font-lock-warning-face          ((,class :foreground ,warn :weight bold)))

   ;; Tree-sitter richer faces (Emacs 29+)
   `(font-lock-bracket-face          ((,class :foreground ,fg-muted)))
   `(font-lock-delimiter-face        ((,class :foreground ,fg-muted)))
   `(font-lock-escape-face           ((,class :foreground ,syn-function)))
   `(font-lock-misc-punctuation-face ((,class :foreground ,fg-muted)))
   `(font-lock-number-face           ((,class :foreground ,syn-number)))
   `(font-lock-operator-face         ((,class :foreground ,syn-keyword)))
   `(font-lock-property-name-face    ((,class :foreground ,syn-tag)))
   `(font-lock-property-use-face     ((,class :foreground ,syn-tag)))
   `(font-lock-punctuation-face      ((,class :foreground ,fg-muted)))

   ;; ─────────────────────────────────────────────
   ;; Line numbers
   ;; ─────────────────────────────────────────────
   `(line-number              ((,class :background ,bg :foreground ,fg-faint)))
   `(line-number-current-line ((,class :background ,bg-subtle :foreground ,accent :weight bold)))
   `(line-number-major-tick   ((,class :foreground ,fg-muted)))
   `(line-number-minor-tick   ((,class :foreground ,fg-faint)))

   ;; ─────────────────────────────────────────────
   ;; Parens / structure
   ;; ─────────────────────────────────────────────
   `(show-paren-match         ((,class :background ,accent-subtle :foreground ,accent :weight bold)))
   `(show-paren-mismatch      ((,class :background ,err :foreground ,bg :weight bold)))

   ;; rainbow-delimiters
   `(rainbow-delimiters-depth-1-face ((,class :foreground ,syn-keyword)))
   `(rainbow-delimiters-depth-2-face ((,class :foreground ,syn-string)))
   `(rainbow-delimiters-depth-3-face ((,class :foreground ,syn-tag)))
   `(rainbow-delimiters-depth-4-face ((,class :foreground ,syn-number)))
   `(rainbow-delimiters-depth-5-face ((,class :foreground ,syn-function)))
   `(rainbow-delimiters-depth-6-face ((,class :foreground ,accent)))
   `(rainbow-delimiters-depth-7-face ((,class :foreground ,fg-muted)))
   `(rainbow-delimiters-unmatched-face ((,class :foreground ,err :weight bold)))

   ;; ─────────────────────────────────────────────
   ;; Vertico / Consult / Marginalia / Corfu / Orderless
   ;; — this IS the command palette (design(7) Keyboard)
   ;; ─────────────────────────────────────────────
   `(vertico-current        ((,class :background ,accent-subtle
                                     :foreground ,fg :extend t
                                     :weight normal)))
   `(vertico-group-title    ((,class :foreground ,fg-faint :slant italic)))
   `(vertico-group-separator ((,class :foreground ,decorator :strike-through t)))

   `(marginalia-key          ((,class :foreground ,accent :weight bold)))
   `(marginalia-documentation ((,class :foreground ,fg-muted :slant italic)))
   `(marginalia-date         ((,class :foreground ,syn-number)))
   `(marginalia-file-name    ((,class :foreground ,fg)))
   `(marginalia-size         ((,class :foreground ,fg-muted)))
   `(marginalia-mode         ((,class :foreground ,syn-tag)))
   `(marginalia-function     ((,class :foreground ,syn-function)))
   `(marginalia-type         ((,class :foreground ,syn-tag)))
   `(marginalia-null         ((,class :foreground ,fg-faint)))
   `(marginalia-value        ((,class :foreground ,fg)))

   `(consult-file           ((,class :foreground ,fg)))
   `(consult-bookmark       ((,class :foreground ,syn-number)))
   `(consult-line-number    ((,class :foreground ,fg-faint)))
   `(consult-preview-line   ((,class :background ,bg-subtle :extend t)))
   `(consult-preview-match  ((,class :background ,accent-subtle :foreground ,accent)))

   `(orderless-match-face-0  ((,class :foreground ,accent :weight bold)))
   `(orderless-match-face-1  ((,class :foreground ,syn-string :weight bold)))
   `(orderless-match-face-2  ((,class :foreground ,syn-tag :weight bold)))
   `(orderless-match-face-3  ((,class :foreground ,syn-number :weight bold)))

   `(corfu-default           ((,class :background ,surface-raised :foreground ,fg)))
   `(corfu-current           ((,class :background ,accent-subtle :foreground ,fg)))
   `(corfu-border            ((,class :background ,border-strong)))
   `(corfu-bar               ((,class :background ,accent)))
   `(corfu-echo              ((,class :foreground ,fg-muted :slant italic)))

   ;; Eldoc / tooltip
   `(eldoc-highlight-function-argument ((,class :foreground ,accent :weight bold)))
   `(tooltip                 ((,class :background ,surface-raised :foreground ,fg
                                      :inherit variable-pitch)))

   ;; which-key — the leader cheatsheet (design(7) Keyboard)
   `(which-key-key-face        ((,class :foreground ,accent :weight bold)))
   `(which-key-group-description-face ((,class :foreground ,syn-tag)))
   `(which-key-command-description-face ((,class :foreground ,fg)))
   `(which-key-local-map-description-face ((,class :foreground ,syn-string)))
   `(which-key-separator-face  ((,class :foreground ,decorator)))
   `(which-key-note-face       ((,class :foreground ,fg-faint)))

   ;; ─────────────────────────────────────────────
   ;; Org
   ;; ─────────────────────────────────────────────
   `(org-level-1    ((,class :foreground ,accent       :weight bold :height 1.4)))
   `(org-level-2    ((,class :foreground ,syn-tag      :weight bold :height 1.2)))
   `(org-level-3    ((,class :foreground ,syn-string   :weight bold :height 1.1)))
   `(org-level-4    ((,class :foreground ,syn-number   :weight bold)))
   `(org-level-5    ((,class :foreground ,syn-function :weight bold)))
   `(org-level-6    ((,class :foreground ,syn-keyword)))
   `(org-level-7    ((,class :foreground ,fg-muted)))
   `(org-level-8    ((,class :foreground ,fg-faint)))

   `(org-document-title      ((,class :foreground ,fg-heading :weight bold :height 1.6)))
   `(org-document-info       ((,class :foreground ,fg-muted)))
   `(org-document-info-keyword ((,class :foreground ,fg-faint)))
   `(org-meta-line           ((,class :foreground ,fg-faint :slant italic)))
   `(org-drawer              ((,class :foreground ,fg-faint)))
   `(org-special-keyword     ((,class :foreground ,syn-tag)))

   `(org-todo                ((,class :foreground ,warn :weight bold :box (:line-width 1 :color ,warn))))
   `(org-done                ((,class :foreground ,ok :weight bold :box (:line-width 1 :color ,ok))))
   `(org-headline-done       ((,class :foreground ,fg-muted :strike-through nil)))

   `(org-date                ((,class :foreground ,syn-number :underline nil)))
   `(org-tag                 ((,class :foreground ,fg-muted :weight normal)))
   `(org-priority            ((,class :foreground ,accent :weight bold)))

   `(org-block               ((,class :background ,bg-subtle :extend t)))
   `(org-block-begin-line    ((,class :background ,bg-subtle :foreground ,fg-faint :extend t)))
   `(org-block-end-line      ((,class :background ,bg-subtle :foreground ,fg-faint :extend t)))
   `(org-code                ((,class :foreground ,syn-string :background ,bg-subtle)))
   `(org-verbatim            ((,class :foreground ,syn-string)))
   `(org-quote               ((,class :foreground ,fg-muted :slant italic)))

   `(org-table               ((,class :foreground ,fg :background ,bg-subtle)))
   `(org-table-header        ((,class :foreground ,fg-heading :background ,surface :weight bold)))

   `(org-link                ((,class :inherit link)))
   `(org-footnote            ((,class :foreground ,syn-number :underline t)))
   `(org-ellipsis            ((,class :foreground ,fg-faint :underline nil)))
   `(org-hide                ((,class :foreground ,bg)))

   ;; org-modern helpers
   `(org-modern-tag          ((,class :foreground ,bg :background ,syn-tag :weight bold)))
   `(org-modern-date-active  ((,class :foreground ,bg :background ,accent :weight bold)))

   ;; Agenda
   `(org-agenda-structure    ((,class :foreground ,accent :weight bold)))
   `(org-agenda-date         ((,class :foreground ,syn-tag :weight bold)))
   `(org-agenda-date-today   ((,class :foreground ,accent :weight bold :underline t)))
   `(org-agenda-date-weekend ((,class :foreground ,fg-muted)))
   `(org-scheduled           ((,class :foreground ,syn-string)))
   `(org-scheduled-today     ((,class :foreground ,ok :weight bold)))
   `(org-scheduled-previously ((,class :foreground ,warn)))
   `(org-upcoming-deadline   ((,class :foreground ,warn)))
   `(org-warning             ((,class :foreground ,warn :weight bold)))

   ;; ─────────────────────────────────────────────
   ;; Dired
   ;; ─────────────────────────────────────────────
   `(dired-directory         ((,class :foreground ,syn-tag :weight bold)))
   `(dired-symlink           ((,class :foreground ,info)))
   `(dired-broken-symlink    ((,class :foreground ,err :strike-through t)))
   `(dired-header            ((,class :foreground ,accent :weight bold)))
   `(dired-mark              ((,class :foreground ,accent)))
   `(dired-marked            ((,class :background ,accent-subtle :foreground ,accent :weight bold)))
   `(dired-perm-write        ((,class :foreground ,warn)))
   `(dired-flagged           ((,class :foreground ,err :weight bold)))
   `(dired-ignored           ((,class :foreground ,fg-faint)))

   ;; ─────────────────────────────────────────────
   ;; Magit / diff
   ;; ─────────────────────────────────────────────
   `(diff-added              ((,class :background ,bg-subtle :foreground ,ok)))
   `(diff-removed            ((,class :background ,bg-subtle :foreground ,err)))
   `(diff-context            ((,class :foreground ,fg-muted)))
   `(diff-hunk-header        ((,class :background ,surface :foreground ,fg-heading :weight bold)))
   `(diff-file-header        ((,class :background ,surface :foreground ,accent :weight bold)))
   `(diff-refine-added       ((,class :background ,accent-subtle :foreground ,ok :weight bold)))
   `(diff-refine-removed     ((,class :background ,accent-subtle :foreground ,err :weight bold)))

   `(magit-section-heading           ((,class :foreground ,accent :weight bold)))
   `(magit-section-highlight         ((,class :background ,bg-subtle :extend t)))
   `(magit-branch-local              ((,class :foreground ,syn-tag :weight bold)))
   `(magit-branch-remote             ((,class :foreground ,syn-string :weight bold)))
   `(magit-branch-current            ((,class :foreground ,accent :weight bold
                                              :box (:line-width 1 :color ,accent))))
   `(magit-tag                       ((,class :foreground ,syn-number)))
   `(magit-hash                      ((,class :foreground ,fg-faint)))
   `(magit-log-author                ((,class :foreground ,syn-function)))
   `(magit-log-date                  ((,class :foreground ,fg-faint)))
   `(magit-diff-added                ((,class :background ,bg-subtle :foreground ,ok)))
   `(magit-diff-added-highlight      ((,class :background ,surface :foreground ,ok)))
   `(magit-diff-removed              ((,class :background ,bg-subtle :foreground ,err)))
   `(magit-diff-removed-highlight    ((,class :background ,surface :foreground ,err)))
   `(magit-diff-context              ((,class :foreground ,fg-muted)))
   `(magit-diff-context-highlight    ((,class :background ,bg-subtle :foreground ,fg)))
   `(magit-diff-hunk-heading         ((,class :background ,surface :foreground ,fg-heading)))
   `(magit-diff-hunk-heading-highlight ((,class :background ,surface-raised :foreground ,fg-heading :weight bold)))
   `(magit-diffstat-added            ((,class :foreground ,ok)))
   `(magit-diffstat-removed          ((,class :foreground ,err)))

   ;; ─────────────────────────────────────────────
   ;; Flymake / Flycheck
   ;; ─────────────────────────────────────────────
   `(flymake-error           ((,class :underline (:style wave :color ,err))))
   `(flymake-warning         ((,class :underline (:style wave :color ,warn))))
   `(flymake-note            ((,class :underline (:style wave :color ,info))))
   `(flycheck-error          ((,class :underline (:style wave :color ,err))))
   `(flycheck-warning        ((,class :underline (:style wave :color ,warn))))
   `(flycheck-info           ((,class :underline (:style wave :color ,info))))
   `(compilation-error       ((,class :foreground ,err :weight bold)))
   `(compilation-warning     ((,class :foreground ,warn :weight bold)))
   `(compilation-info        ((,class :foreground ,info)))

   ;; ─────────────────────────────────────────────
   ;; Company + Eglot
   ;; ─────────────────────────────────────────────
   `(company-tooltip                      ((,class :background ,surface-raised :foreground ,fg)))
   `(company-tooltip-selection            ((,class :background ,accent-subtle :foreground ,fg)))
   `(company-tooltip-common               ((,class :foreground ,accent :weight bold)))
   `(company-tooltip-annotation           ((,class :foreground ,fg-muted)))
   `(company-scrollbar-bg                 ((,class :background ,surface)))
   `(company-scrollbar-fg                 ((,class :background ,border-strong)))

   `(eglot-highlight-symbol-face          ((,class :background ,surface :weight bold)))
   `(eglot-mode-line                      ((,class :foreground ,accent)))
   `(eglot-diagnostic-tag-deprecated-face ((,class :strike-through t :foreground ,fg-faint)))

   ;; ─────────────────────────────────────────────
   ;; Terminal (vterm / ansi-term)  — themes/jylhis.json ANSI palette
   ;; ─────────────────────────────────────────────
   `(ansi-color-black               ((,class :foreground "#1a1713" :background "#1a1713")))
   `(ansi-color-red                 ((,class :foreground "#ff6a5a" :background "#ff6a5a")))
   `(ansi-color-green               ((,class :foreground "#7fd18a" :background "#7fd18a")))
   `(ansi-color-yellow              ((,class :foreground "#ffd08a" :background "#ffd08a")))
   `(ansi-color-blue                ((,class :foreground "#8ab8ff" :background "#8ab8ff")))
   `(ansi-color-magenta             ((,class :foreground "#ff6db6" :background "#ff6db6")))
   `(ansi-color-cyan                ((,class :foreground "#00b8c6" :background "#00b8c6")))
   `(ansi-color-white               ((,class :foreground "#9c9488" :background "#9c9488")))
   `(ansi-color-bright-black        ((,class :foreground "#746a5c" :background "#746a5c")))
   `(ansi-color-bright-red          ((,class :foreground "#ff7a6a" :background "#ff7a6a")))
   `(ansi-color-bright-green        ((,class :foreground "#00bb18" :background "#00bb18")))
   `(ansi-color-bright-yellow       ((,class :foreground "#ffa028" :background "#ffa028")))
   `(ansi-color-bright-blue         ((,class :foreground "#749fff" :background "#749fff")))
   `(ansi-color-bright-magenta      ((,class :foreground "#ff5fec" :background "#ff5fec")))
   `(ansi-color-bright-cyan         ((,class :foreground "#00b78f" :background "#00b78f")))
   `(ansi-color-bright-white        ((,class :foreground "#f7f3ec" :background "#f7f3ec")))

   ;; ─────────────────────────────────────────────
   ;; Misc
   ;; ─────────────────────────────────────────────
   `(trailing-whitespace       ((,class :background ,err)))
   `(whitespace-tab            ((,class :foreground ,fg-faint)))
   `(whitespace-space          ((,class :foreground ,fg-faint)))
   `(whitespace-newline        ((,class :foreground ,fg-faint)))
   `(whitespace-indentation    ((,class :foreground ,fg-faint)))
   `(whitespace-line           ((,class :background ,bg-subtle)))
   `(whitespace-trailing       ((,class :background ,err)))

   `(hi-yellow                 ((,class :background ,warn :foreground ,bg)))
   `(hi-pink                   ((,class :background ,syn-number :foreground ,bg)))
   `(hi-green                  ((,class :background ,ok :foreground ,bg)))

   ;; tab-line / centaur-tabs
   `(tab-line-tab-current      ((,class :background ,surface :foreground ,accent :weight bold)))
   `(tab-line-tab              ((,class :background ,bg-subtle :foreground ,fg-muted)))

   ;; hl-todo
   `(hl-todo                   ((,class :foreground ,warn :weight bold)))

   ;; indent-bars
   `(indent-bars-face          ((,class :foreground ,fg-faint)))))

(custom-theme-set-variables
 'jylhis-dark
 '(ansi-color-names-vector
   ["#1a1713" "#ff6a5a" "#7fd18a" "#ffd08a"
    "#8ab8ff" "#ff6db6" "#00b8c6" "#9c9488"])
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(hl-todo-keyword-faces
   '(("FIXME"      . "#ff6a5a")
     ("BUG"        . "#ff6a5a")
     ("TODO"       . "#ffd08a")
     ("HACK"       . "#ffd08a")
     ("NOTE"       . "#4fd1bd")
     ("REVIEW"     . "#4fd1bd")
     ("DEPRECATED" . "#746a5c"))))

(provide-theme 'jylhis-dark)

;;;###autoload
(and load-file-name
     (boundp 'custom-theme-load-path)
     (add-to-list 'custom-theme-load-path
                  (file-name-as-directory
                   (file-name-directory load-file-name))))

;;; jylhis-dark-theme.el ends here
