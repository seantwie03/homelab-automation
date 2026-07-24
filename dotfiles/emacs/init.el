;;; init.el --- Init file -*- lexical-binding: t -*-

;;; Guardrail
(when (< emacs-major-version 30)
  (error "This configuration only works with Emacs 30 and newer; you have version %s" emacs-major-version))

;;; Generated state
(use-package cus-edit
  :ensure nil
  :custom
  (custom-file (expand-file-name "custom.el" user-emacs-directory))
  :config
  (load custom-file 'noerror 'nomessage))

(use-package files
  :ensure nil
  :init
  ;; Keep generated backup and auto-save files out of project directories.
  (dolist (dir (list
                (expand-file-name "backups/" user-emacs-directory)
                (expand-file-name "auto-saves/" user-emacs-directory)))
    (make-directory dir t))

  :custom
  (backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
  (auto-save-file-name-transforms
   `((".*" ,(expand-file-name "auto-saves/" user-emacs-directory) t)))
  (create-lockfiles nil))

(savehist-mode 1)
(save-place-mode 1)

(use-package recentf
  :ensure nil
  :custom
  (recentf-max-saved-items 200)
  (recentf-auto-cleanup 'never)
  :config
  (recentf-mode 1))

;;; UI
(add-to-list 'face-font-family-alternatives
             '("Iosevka Nerd Font" "Iosevka Curly" "Ubuntu Mono"))
(set-face-attribute 'default nil :family "Iosevka Nerd Font" :height 140)
(load-theme 'modus-operandi t)
(setopt ring-bell-function #'ignore)
(setopt inhibit-splash-screen t)
(setopt initial-major-mode 'org-mode)
(blink-cursor-mode -1)
(show-paren-mode 1)
(global-visual-line-mode 1)

;; Scroll like Vim's scrolloff: keep point away from the window edges.
(setopt scroll-margin 8)
(setopt scroll-conservatively 101)
(setopt scroll-step 1)
(setopt scroll-preserve-screen-position t)
(setq next-screen-context-lines 8)


(use-package term/xterm
  :ensure nil
  :custom
  (xterm-extra-capabilities '(setSelection))
  :config
  ;; The initial terminal frame is initialized before init.el is loaded.
  (unless (or (daemonp) (display-graphic-p))
    (xterm--init-activate-set-selection)))

(use-package display-line-numbers
  :ensure nil
  :preface
  (defun my/disable-line-numbers ()
    "Disable line numbers in the current buffer."
    (display-line-numbers-mode -1))
  :hook
  ((org-mode markdown-mode) . my/disable-line-numbers)
  :custom
  (display-line-numbers-width-start t)
  (display-line-numbers-grow-only t)
  :config
  (global-display-line-numbers-mode 1))

(use-package doom-modeline
  :ensure t
  :custom
  (doom-modeline-bar-width 1)
  (doom-modeline-icon t)
  (doom-modeline-battery nil)
  (doom-modeline-time nil)
  :config
  (column-number-mode 1)
  (line-number-mode 1)
  (doom-modeline-mode 1)
  (set-face-attribute 'mode-line nil
                      :background "#f2f2f2"
                      :height 130)
  (doom-modeline-remove-segment 'misc-info 'main)
  (doom-modeline-add-segment 'misc-info 'buffer-position :after 'main)
  (doom-modeline-refresh-bars))

;;; Editing
;; Use spaces by default; EditorConfig can override this per project.
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default show-trailing-whitespace t)
(setopt sentence-end-double-space nil)
(editorconfig-mode 1)
(delete-selection-mode 1)
(setopt kill-do-not-save-duplicates t)
(setopt save-interprogram-paste-before-kill 100000)

(use-package files
  :ensure nil
  :preface
  (defun my/format-emacs-lisp-buffer ()
    "Indent the current Emacs Lisp buffer."
    (when (derived-mode-p 'emacs-lisp-mode)
      (save-excursion
        (indent-region (point-min) (point-max)))))

  (defvar-local my--delete-trailing-whitespace-on-save-p t
    "Whether to delete trailing whitespace when saving the current buffer.")

  (defun my/delete-trailing-whitespace-on-save ()
    "Delete trailing whitespace when enabled for the current buffer."
    (when my--delete-trailing-whitespace-on-save-p
      (delete-trailing-whitespace)))

  (defun my/disable-delete-trailing-whitespace-on-save ()
    "Preserve trailing whitespace when saving the current buffer."
    (setq-local my--delete-trailing-whitespace-on-save-p nil))

  :init
  (add-hook 'before-save-hook #'my/format-emacs-lisp-buffer)
  (add-hook 'before-save-hook #'my/delete-trailing-whitespace-on-save)

  :hook
  ((org-mode markdown-mode) . my/disable-delete-trailing-whitespace-on-save))

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . gfm-mode)
  :hook
  (markdown-mode . visual-wrap-prefix-mode)
  :custom
  (markdown-command '("pandoc" "--from=gfm" "--to=html5"))
  (markdown-open-command "xdg-open")
  (markdown-unordered-list-item-prefix "- ")
  :config
  (defun my/markdown-insert-list-item ()
    "Append a Markdown list item and enter Evil insert state."
    (interactive)
    (unless (evil-insert-state-p)
      (end-of-line))
    (markdown-insert-list-item)
    (evil-insert-state))

  (defun my/markdown-insert-task-item ()
    "Insert a GFM task item and enter Evil insert state."
    (interactive)
    (unless (evil-insert-state-p)
      (end-of-line))
    (markdown-insert-list-item)
    (delete-horizontal-space)
    (insert " [ ] ")
    (evil-insert-state))

  (defun my--markdown-insert-heading-after-subtree (childp)
    "Insert a Markdown heading after the current subtree.

When CHILDP is non-nil, make the new heading a child of the current one."
    (let ((level 1)
          heading-found)
      (save-excursion
        (condition-case nil
            (progn
              (markdown-back-to-heading t)
              (setq heading-found t
                    level (markdown-outline-level)))
          (error nil)))
      (when childp
        (setq level (1+ level)))
      (when (> level 6)
        (user-error "Markdown headings cannot be deeper than level 6"))
      (if heading-found
          (markdown-end-of-subtree t)
        (end-of-line))
      (end-of-line)
      (let ((boundary (point)))
        (skip-chars-forward "\n")
        (delete-region boundary (point)))
      (insert "\n\n" (make-string level ?#) " ")
      (save-excursion
        (insert "\n\n"))
      (evil-insert-state)))

  (defun my/markdown-insert-heading-respect-content ()
    "Insert a same-level Markdown heading after the current subtree."
    (interactive)
    (my--markdown-insert-heading-after-subtree nil))

  (defun my/markdown-insert-subheading-respect-content ()
    "Insert a child Markdown heading after the current subtree."
    (interactive)
    (my--markdown-insert-heading-after-subtree t))

  (defun my/markdown-table-insert-row-below ()
    "Insert a Markdown table row below point and enter insert state."
    (interactive)
    (markdown-table-insert-row t)
    (evil-insert-state))

  (defun my/markdown-cut-subtree ()
    "Kill the current Markdown heading and its subtree."
    (interactive)
    (markdown-mark-subtree)
    (kill-region (region-beginning) (region-end)))

  (defun my/markdown-cycle-global ()
    "Cycle visibility for all Markdown headings."
    (interactive)
    (markdown-cycle t))

  (defvar-keymap my/markdown-tables-delete-map
    :doc "Markdown table deletion commands."
    "c" #'markdown-table-delete-column
    "r" #'markdown-table-delete-row)

  (defvar-keymap my/markdown-tables-insert-map
    :doc "Markdown table insertion commands."
    "c" #'markdown-table-insert-column
    "r" #'markdown-table-insert-row)

  (defvar-keymap my/markdown-tables-map
    :doc "Markdown table commands."
    "a" #'markdown-table-align
    "c" #'markdown-table-convert-region
    "d" my/markdown-tables-delete-map
    "i" my/markdown-tables-insert-map
    "s" #'markdown-table-sort-lines)

  (defvar-keymap my/markdown-subtree-map
    :doc "Markdown heading and subtree commands."
    "d" #'my/markdown-cut-subtree
    "h" #'markdown-promote-subtree
    "j" #'markdown-move-subtree-down
    "k" #'markdown-move-subtree-up
    "l" #'markdown-demote-subtree
    "n" #'markdown-narrow-to-subtree
    "N" #'widen)

  (defvar-keymap my/markdown-links-map
    :doc "Markdown link commands."
    "l" #'markdown-insert-link
    "t" #'markdown-toggle-url-hiding)

  (defvar-keymap my/markdown-localleader-map
    :doc "Markdown commands."
    "." #'consult-outline
    "b" my/markdown-tables-map
    "e" #'markdown-export
    "f" #'markdown-insert-footnote
    "l" my/markdown-links-map
    "o" #'markdown-open
    "p" #'markdown-preview
    "s" my/markdown-subtree-map
    "x" #'markdown-toggle-gfm-checkbox)

  (which-key-add-keymap-based-replacements
    my/markdown-localleader-map
    "." "headings"
    "b" (cons "tables" my/markdown-tables-map)
    "e" "export"
    "f" "footnote"
    "l" (cons "links" my/markdown-links-map)
    "o" "open"
    "p" "preview"
    "s" (cons "subtree" my/markdown-subtree-map)
    "x" "toggle task")

  (which-key-add-keymap-based-replacements
    my/markdown-tables-map
    "d" (cons "delete" my/markdown-tables-delete-map)
    "i" (cons "insert" my/markdown-tables-insert-map))

  (defun my/markdown-setup-evil-bindings ()
    "Install mode-specific Evil bindings for Markdown buffers."
    (evil-define-key 'insert markdown-mode-map
      (kbd "M-<return>") #'markdown-insert-list-item
      (kbd "M-S-<return>") #'my/markdown-insert-task-item
      (kbd "C-<return>") #'my/markdown-insert-heading-respect-content
      (kbd "C-M-<return>") #'my/markdown-insert-subheading-respect-content
      (kbd "S-<return>") #'my/markdown-table-insert-row-below)
    (evil-define-key 'insert gfm-mode-map
      (kbd "M-<return>") #'markdown-insert-list-item
      (kbd "M-S-<return>") #'my/markdown-insert-task-item
      (kbd "C-<return>") #'my/markdown-insert-heading-respect-content
      (kbd "C-M-<return>") #'my/markdown-insert-subheading-respect-content
      (kbd "S-<return>") #'my/markdown-table-insert-row-below)
    (evil-define-key '(normal visual motion) markdown-mode-map
      (kbd "\\") my/markdown-localleader-map
      (kbd "M-<return>") #'my/markdown-insert-list-item
      (kbd "M-S-<return>") #'my/markdown-insert-task-item
      (kbd "C-<return>") #'my/markdown-insert-heading-respect-content
      (kbd "C-M-<return>") #'my/markdown-insert-subheading-respect-content
      (kbd "S-<return>") #'my/markdown-table-insert-row-below
      (kbd "] h") #'markdown-next-visible-heading
      (kbd "[ h") #'markdown-previous-visible-heading
      (kbd "] p") #'markdown-demote
      (kbd "[ p") #'markdown-promote
      (kbd "z a") #'markdown-cycle
      (kbd "z A") #'my/markdown-cycle-global
      (kbd "z c") #'outline-hide-subtree
      (kbd "z o") #'outline-show-subtree
      (kbd "z R") #'outline-show-all
      (kbd "z i") #'markdown-toggle-inline-images)
    (evil-define-key '(normal visual motion) gfm-mode-map
      (kbd "\\") my/markdown-localleader-map
      (kbd "M-<return>") #'my/markdown-insert-list-item
      (kbd "M-S-<return>") #'my/markdown-insert-task-item
      (kbd "C-<return>") #'my/markdown-insert-heading-respect-content
      (kbd "C-M-<return>") #'my/markdown-insert-subheading-respect-content
      (kbd "S-<return>") #'my/markdown-table-insert-row-below
      (kbd "] h") #'markdown-next-visible-heading
      (kbd "[ h") #'markdown-previous-visible-heading
      (kbd "] p") #'markdown-demote
      (kbd "[ p") #'markdown-promote
      (kbd "z a") #'markdown-cycle
      (kbd "z A") #'my/markdown-cycle-global
      (kbd "z c") #'outline-hide-subtree
      (kbd "z o") #'outline-show-subtree
      (kbd "z R") #'outline-show-all
      (kbd "z i") #'markdown-toggle-inline-images)
    (dolist (state '(normal visual motion insert))
      (evil-make-intercept-map markdown-mode-map state t)
      (evil-make-intercept-map gfm-mode-map state t))
    (evil-normalize-keymaps))

  (with-eval-after-load 'evil
    (add-hook 'markdown-mode-hook #'my/markdown-setup-evil-bindings t)
    (add-hook 'gfm-mode-hook #'my/markdown-setup-evil-bindings t)
    (my/markdown-setup-evil-bindings)))

(use-package olivetti
  :ensure t
  :custom
  (olivetti-body-width 110)
  (olivetti-style 'fancy)
  :hook
  ((org-mode markdown-mode) . olivetti-mode))

;;; File behavior
(setopt vc-follow-symlinks t)

(use-package autorevert
  :ensure nil
  :custom
  (auto-revert-avoid-polling t)
  (auto-revert-interval 5)
  (auto-revert-check-vc-info t)
  :config
  ;; Automatically reread from disk if the underlying file changes.
  ;; Check if polling is being used for the current buffer by running the
  ;; following elisp and looking for :watch in the output:
  ;; (with-current-buffer (window-buffer (selected-window))
  ;;     (list :buffer (buffer-name) :file buffer-file-name :watch
  ;;           (and (boundp 'auto-revert-notify-watch-descriptor)
  ;;                auto-revert-notify-watch-descriptor)))
  (global-auto-revert-mode 1))

(use-package dired
  :ensure nil
  :custom
  (delete-by-moving-to-trash t)
  (dired-kill-when-opening-new-dired-buffer t))

;;; Completion and navigation
(setopt read-extended-command-predicate #'command-completion-default-include-p)
(setopt enable-recursive-minibuffers t)
(setopt completions-detailed t)
(setopt completion-cycle-threshold 3)
(setopt completions-sort 'historical)
(minibuffer-depth-indicate-mode 1)

(use-package minibuffer
  :ensure nil
  :config
  (keymap-set minibuffer-local-map "C-h" #'backward-kill-word)
  (keymap-set minibuffer-local-map "C-v" #'clipboard-yank))

(use-package icomplete
  :ensure nil
  :custom
  (icomplete-delay-completions-threshold 0)
  (icomplete-compute-delay 0)
  (icomplete-show-matches-on-no-input t)
  (icomplete-prospects-height 10)
  (icomplete-scroll t)
  :config
  (fido-vertical-mode 1))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file (styles basic partial-completion))))
  :config
  (defun my/fido-completion-styles ()
    "Use Orderless completion styles inside Fido minibuffers."
    (setq-local completion-styles '(orderless basic))
    (setq-local completion-category-overrides
                '((file (styles basic partial-completion)))))

  (add-hook 'minibuffer-setup-hook #'my/fido-completion-styles 90)
  (define-key minibuffer-local-completion-map (kbd "SPC") #'self-insert-command)
  (define-key minibuffer-local-must-match-map (kbd "SPC") #'self-insert-command))

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode 1))

(use-package consult
  :ensure t
  :init
  (defun my/search-symbol-at-point ()
    "Search the current buffer for the symbol at point."
    (interactive)
    (consult-line (thing-at-point 'symbol t)))

  (defun my/search-open-buffers ()
    "Search text across all open buffers."
    (interactive)
    (consult-line-multi t))

  (defun my/search-project-symbol-at-point ()
    "Search the current project for the symbol at point."
    (interactive)
    (consult-ripgrep nil (thing-at-point 'symbol t))))

(use-package vundo
  :ensure t)

;;; Help and discovery
(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.5)
  :config
  (which-key-mode 1))

(use-package helpful
  :ensure t)

(use-package keycast
  :ensure t
  :config
  (setopt keycast-mode-line-format "%1s%K%c%r")
  (add-hook 'post-command-hook #'keycast--update t)
  (add-hook 'minibuffer-exit-hook #'keycast--minibuffer-exit t)
  (add-to-list 'global-mode-string '("" keycast-mode-line)))

(use-package project
  :ensure nil
  :custom
  (project-vc-extra-root-markers '(".project"))
  :config
  (defun my/copy-file-name ()
    "Copy the current buffer's file name to the kill ring."
    (interactive)
    (unless buffer-file-name
      (user-error "Current buffer is not visiting a file"))
    (let ((name (file-name-nondirectory buffer-file-name)))
      (kill-new name)
      (message "Copied file name: %s" name)))

  (defun my/copy-project-relative-file-path ()
    "Copy the current file's project-relative path to the kill ring.
Copy the absolute path when the file is not in a project."
    (interactive)
    (unless buffer-file-name
      (user-error "Current buffer is not visiting a file"))
    (let* ((project (project-current nil
                                     (file-name-directory buffer-file-name)))
           (path (if project
                     (file-relative-name buffer-file-name
                                         (project-root project))
                   (expand-file-name buffer-file-name))))
      (kill-new path)
      (message "Copied file path: %s" path))))

(use-package ghostel
  :ensure t
  :bind
  (("C-c t" . ghostel)
   :map project-prefix-map
   ("s" . ghostel-project))
  :hook
  (ghostel-mode . my/ghostel-disable-trailing-whitespace)
  :config
  (defun my/ghostel-disable-trailing-whitespace ()
    "Disable trailing whitespace display in Ghostel buffers."
    (setq-local show-trailing-whitespace nil)))

(use-package org
  :ensure nil
  :bind
  (("C-c a" . org-agenda)
   ("C-c c" . org-capture)
   ("C-c l" . org-store-link))
  :hook
  ((org-mode . org-indent-mode)
   (org-mode . visual-line-mode))
  :init
  (defun my/org-find-file-in-notes ()
    "Find a file beneath `org-directory'."
    (interactive)
    (require 'org)
    (let* ((root (file-name-as-directory
                  (expand-file-name org-directory)))
           (project (cons 'transient root)))
      (project-find-file-in nil (list root) project t)))

  (defun my/org-browse-notes ()
    "Open `org-directory' in Dired."
    (interactive)
    (require 'org)
    (dired org-directory))

  (defun my/org-search-notes ()
    "Search for text beneath `org-directory'."
    (interactive)
    (require 'org)
    (consult-ripgrep org-directory))

  (defun my/org-command-and-enter-insert-state (command)
    "Call COMMAND interactively, then enter Evil insert state."
    (call-interactively command)
    (evil-insert-state))

  (defun my/org-insert-heading-respect-content ()
    "Insert an Org heading after the current subtree and start editing."
    (interactive)
    (my/org-command-and-enter-insert-state
     #'org-insert-heading-respect-content))

  (defun my/org-meta-return ()
    "Append an Org item in Evil normal state and start editing it."
    (interactive)
    (when (evil-normal-state-p)
      (end-of-line))
    (my/org-command-and-enter-insert-state #'org-meta-return))

  (defun my/org-insert-subheading ()
    "Insert an Org subheading and enter Evil insert state."
    (interactive)
    (my/org-command-and-enter-insert-state #'org-insert-subheading))

  (defun my/org-table-copy-down ()
    "Run `org-table-copy-down' and enter Evil insert state."
    (interactive)
    (my/org-command-and-enter-insert-state #'org-table-copy-down))

  (defun my/org-insert-todo-heading-respect-content ()
    "Insert a TODO heading after the current subtree and start editing."
    (interactive)
    (my/org-command-and-enter-insert-state
     #'org-insert-todo-heading-respect-content))

  (defun my/org-insert-todo-heading ()
    "Append an Org TODO item in Evil normal state and start editing it."
    (interactive)
    (when (evil-normal-state-p)
      (end-of-line))
    (my/org-command-and-enter-insert-state #'org-insert-todo-heading))

  (defun my/org-open-fold ()
    "Open the current Org fold while leaving nested folds closed."
    (interactive)
    (save-excursion
      (org-back-to-heading t)
      (org-fold-show-entry)
      (org-fold-show-children)))

  (defun my--org-visible-fold-level ()
    "Return the deepest folded Org heading level in the visible window."
    (let ((level 1))
      (save-restriction
        (narrow-to-region (window-start) (window-end))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (org-next-visible-heading 1)
            (when (memq (get-char-property (line-end-position) 'invisible)
                        '(outline org-fold-outline))
              (setq level (max level (org-outline-level)))))))
      level))

  (defun my/org-hide-next-fold-level (&optional count)
    "Hide COUNT additional Org outline levels in the visible window."
    (interactive "p")
    (let ((level (max 1 (- (my--org-visible-fold-level) (or count 1)))))
      (outline-hide-sublevels level)
      (message "Folded to level %s" level)))

  (defun my/org-show-next-fold-level (&optional count)
    "Show COUNT additional Org outline levels in the visible window."
    (interactive "p")
    (let ((level (+ (my--org-visible-fold-level) (or count 1))))
      (outline-hide-sublevels level)
      (message "Folded to level %s" level)))

  :custom
  ;;; File Structure
  (org-directory "~/u/org")
  (org-default-notes-file
   (expand-file-name "inbox.org" org-directory))
  (org-agenda-files
   (directory-files-recursively org-directory "\\.org$"))

  ;;; Display
  (org-blank-before-new-entry
   '((heading . t)
     (plain-list-item . auto)))

  ;;; Editing
  (org-support-shift-select t)

  ;;; Export
  (org-export-with-toc nil)

  ;;; Logging
  (org-log-done 'time)
  (org-log-repeat 'time)
  (org-log-into-drawer "LOGBOOK")

  ;; TODO workflow:
  ;; TODO      = known work, but not currently active/actionable
  ;; NEXT      = active/actionable, including in-progress work
  ;; WAITING   = blocked
  ;; DONE      = complete
  ;; CANCELLED = no longer relevant
  (org-todo-keywords
   '((sequence
      "TODO(t)"
      "NEXT(n)"
      "WAITING(w)"
      "|"
      "DONE(d!)"
      "CANCELLED(c!)")))

  ;;; Tags:
  ;; Place: choose one of home/computer/device/away
  ;; Effort: choose one of short/medium/long
  ;; Mode: optionally add menial and/or physical
  (org-tag-alist
   '((:startgroup)
     ("home" . ?h)
     ("computer" . ?c)
     ("device" . ?d)
     ("away" . ?a)
     (:endgroup)

     (:startgroup)
     ("short" . ?s) ;; Less than 15 minutes
     ("medium" . ?m) ;; Between 15 and 30 minutes
     ("long" . ?l) ;; Greater than 30 minutes
     (:endgroup)

     ("menial" . ?n) ;; Can listen to book/podcast while preforming this action
     ("physical" . ?p))) ;; Requires movement

  ;;; Agenda
  ;; Continue showing DONE items on the Agenda
  ;; It is rewarding to see what you've accomplished
  (org-agenda-skip-scheduled-if-done nil)
  (org-agenda-skip-deadline-if-done nil)
  (org-agenda-skip-timestamp-if-done nil)

  ;; Custom agenda commands:
  ;;
  ;; C-c a d = daily dashboard
  ;; C-c a n = all NEXT actions
  ;;
  ;; In the NEXT view, press "/" and type a tag:
  ;; medium RET
  ;; home RET
  ;; menial RET
  (org-agenda-custom-commands
   '(("d" "Daily dashboard"
      ((agenda "" ((org-agenda-span 1)))
       (todo "NEXT"
             ((org-agenda-overriding-header "Next actions")))))

     ("n" "Next actions"
      todo "NEXT")))

  :config
  ;; Display
  (set-face-attribute 'org-level-1 nil :height 1.25)
  (set-face-attribute 'org-level-2 nil :height 1.20)
  (set-face-attribute 'org-level-3 nil :height 1.15)
  (set-face-attribute 'org-level-4 nil :height 1.10)
  (set-face-attribute 'org-level-5 nil :height 1.05)
  (require 'org-habit))

(use-package org-srs
  :ensure t
  :after org
  :preface
  (defvar-keymap my/org-srs-map
    :doc "Org-srs commands."
    "c" #'org-srs-item-create
    "r" #'org-srs-review-start
    "a" #'org-srs-review-rate-again
    "e" #'org-srs-review-rate-easy
    "g" #'org-srs-review-rate-good
    "h" #'org-srs-review-rate-hard
    "p" #'org-srs-review-postpone
    "q" #'org-srs-review-quit
    "s" #'org-srs-review-suspend
    "u" #'org-srs-review-undo
    "U" #'org-srs-review-undo-redo)

  :hook
  (org-mode . org-srs-embed-overlay-mode))

(use-package org-capture
  :ensure nil
  :after (org evil)
  :custom
  (org-capture-templates
   `(("t" "Task" entry
      (file ,(expand-file-name "inbox.org" org-directory))
      "* TODO %?\n:LOGBOOK:\n- Created: %U\n:END:\n"
      :empty-lines-before 1)))
  :hook
  (org-capture-mode . evil-insert-state))

(use-package ox-gfm
  :ensure t
  :after org
  :config
  (defun my/org-gfm-export-to-clipboard
      (async subtreep visible-only body-only)
    "Export Org content as GFM and copy it to the clipboard.

SUBTREEP, VISIBLE-ONLY, and BODY-ONLY are Org export options.  ASYNC is
unsupported because the exported text must be available immediately."
    (interactive (list nil nil nil nil))
    (when async
      (user-error "Clipboard export cannot run asynchronously"))
    (kill-new (org-export-as 'gfm subtreep visible-only body-only))
    (message "GFM export copied to clipboard")))

(use-package ox-html
  :ensure nil
  :after org
  :init
  (defun my/org-export-to-clipboard-as-rich-text ()
    "Export the active Org region or buffer as rich text."
    (interactive)
    (require 'ox-ascii)
    (require 'ox-html)
    (let* ((html (org-export-as 'html nil nil t))
           (plain (org-export-as 'ascii nil nil t))
           (selection (copy-sequence plain)))
      (add-text-properties 0 (length selection)
                           (list 'text/html html)
                           selection)
      (kill-new plain)
      (gui-set-selection 'CLIPBOARD selection)
      (message "Rich-text export copied to clipboard"))))

(use-package evil
  :ensure t
  :init
  (setq evil-want-keybinding nil) ; Required for evil-collection compatibility
  (setq evil-respect-visual-line-mode t)
  (setq evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

;;; Evil keybindings
(defun my/keymap-set-many (keymaps key command)
  "Bind KEY to COMMAND in each keymap in KEYMAPS."
  (dolist (keymap keymaps)
    (keymap-set keymap key command)))

(defun my/evil-normal-state-and-save ()
  "Enter Evil normal state and save the current buffer."
  (interactive)
  (evil-normal-state)
  (save-buffer))

(defun my/evil-open-line-above-and-stay-normal (count)
  "Open COUNT lines above point and return to Evil normal state."
  (interactive "p")
  (evil-open-above count)
  (evil-normal-state))

(defun my/evil-open-line-below-and-stay-normal (count)
  "Open COUNT lines below point and return to Evil normal state."
  (interactive "p")
  (evil-open-below count)
  (evil-normal-state))

(defun my/evil-smart-beginning-of-line ()
  "Toggle between indentation and the beginning of the current line."
  (interactive)
  (let ((first-nonblank-position
         (save-excursion
           (evil-first-non-blank)
           (point))))
    (if (= (point) first-nonblank-position)
        (evil-beginning-of-line)
      (evil-first-non-blank))))

(defun my/evil-command-and-recenter (command)
  "Call COMMAND interactively, then center point in the window."
  (call-interactively command)
  (recenter))

(defun my/evil-scroll-down-and-center ()
  "Scroll down half a page and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-scroll-down))

(defun my/evil-scroll-up-and-center ()
  "Scroll up half a page and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-scroll-up))

(defun my/evil-search-next-and-center ()
  "Repeat the last search and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-search-next))

(defun my/evil-search-previous-and-center ()
  "Repeat the last search backward and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-search-previous))

(defun my/evil-backward-paragraph-and-center ()
  "Move backward by a paragraph and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-backward-paragraph))

(defun my/evil-forward-paragraph-and-center ()
  "Move forward by a paragraph and center point in the window."
  (interactive)
  (my/evil-command-and-recenter #'evil-forward-paragraph))

;;; Evil leader keymaps
(defvar-keymap my/leader-buffers-map
  :doc "Buffer commands."
  "b" #'switch-to-buffer
  "d" #'kill-current-buffer
  "l" #'evil-switch-to-windows-last-buffer
  "n" #'next-buffer
  "p" #'previous-buffer
  "r" #'revert-buffer
  "s" #'write-file
  "S" #'evil-write-all
  "x" #'scratch-buffer)

(defvar-keymap my/leader-files-map
  :doc "File commands."
  "f" #'find-file
  "r" #'recentf-open
  "s" #'write-file
  "y" #'my/copy-file-name
  "Y" #'my/copy-project-relative-file-path)

(defvar-keymap my/leader-windows-map
  :doc "Window commands."
  "s" #'evil-window-split
  "v" #'evil-window-vsplit
  "n" #'evil-window-new
  "p" #'evil-window-mru
  "q" #'evil-quit
  "o" #'delete-other-windows
  "=" #'balance-windows
  "+" #'evil-window-increase-height
  "-" #'evil-window-decrease-height
  "<" #'evil-window-decrease-width
  ">" #'evil-window-increase-width
  "f" #'ffap-other-window
  "T" #'tab-window-detach
  "h" #'evil-window-move-far-left
  "j" #'evil-window-move-very-bottom
  "k" #'evil-window-move-very-top
  "l" #'evil-window-move-far-right)

(defvar-keymap my/leader-git-map
  :doc "Git commands."
  "R" #'vc-revert)

(defvar-keymap my/leader-help-map
  :doc "Help commands."
  "." #'helpful-at-point
  "a" #'apropos-command
  "b" #'describe-bindings
  "d" #'apropos-documentation
  "f" #'helpful-callable
  "i" #'info
  "k" #'helpful-key
  "m" #'describe-mode
  "o" #'describe-symbol
  "p" #'describe-package
  "r" #'info-emacs-manual
  "u" #'apropos-user-option
  "v" #'helpful-variable
  "w" #'where-is
  "x" #'helpful-command)

(defvar-keymap my/leader-insert-map
  :doc "Insert commands."
  "e" #'emoji-search
  "i" #'yank-media
  "u" #'insert-char)

(defvar-keymap my/leader-notes-map
  :doc "Notes and Org commands."
  "-" #'my/org-browse-notes
  "a" #'org-agenda
  "f" #'my/org-find-file-in-notes
  "l" #'org-store-link
  "m" #'org-tags-view
  "n" #'org-capture
  "N" #'org-capture-goto-last-stored
  "s" #'my/org-search-notes
  "t" #'org-todo-list
  "y" #'my/org-gfm-export-to-clipboard
  "Y" #'my/org-export-to-clipboard-as-rich-text)

(defvar-keymap my/leader-search-map
  :doc "Search and jump commands."
  "*" #'my/search-symbol-at-point
  "'" #'evil-show-marks
  "b" #'my/search-open-buffers
  "j" #'evil-show-jumps
  "m" #'bookmark-jump
  "s" #'my/search-project-symbol-at-point
  "t" #'consult-ripgrep
  "u" #'vundo)

(defvar-keymap my/leader-toggle-map
  :doc "Toggle commands."
  "c" #'global-display-fill-column-indicator-mode
  "f" #'flymake-mode
  "F" #'toggle-frame-fullscreen
  "r" #'read-only-mode
  "v" #'visible-mode
  "w" #'visual-line-mode)

(defvar-keymap my/leader-map
  :doc "Global leader keymap."
  "\"" #'evil-show-registers
  "." #'project-find-file
  "*" #'my/search-symbol-at-point
  "/" #'consult-line
  "," #'project-switch-to-buffer
  "'" #'evil-show-marks
  "`" #'evil-switch-to-windows-last-buffer
  ":" #'execute-extended-command
  ";" #'pp-eval-expression
  "O" #'my/evil-open-line-above-and-stay-normal
  "j" #'evil-show-jumps
  "o" #'my/evil-open-line-below-and-stay-normal
  "u" #'universal-argument
  "w" my/leader-windows-map
  "b" my/leader-buffers-map
  "f" my/leader-files-map
  "g" my/leader-git-map
  "h" my/leader-help-map
  "i" my/leader-insert-map
  "n" my/leader-notes-map
  "s" my/leader-search-map
  "t" my/leader-toggle-map)

(which-key-add-keymap-based-replacements
  my/leader-map
  "b" (cons "buffers" my/leader-buffers-map)
  "f" (cons "files" my/leader-files-map)
  "g" (cons "git" my/leader-git-map)
  "h" (cons "help" my/leader-help-map)
  "i" (cons "insert" my/leader-insert-map)
  "n" (cons "notes" my/leader-notes-map)
  "s" (cons "search" my/leader-search-map)
  "t" (cons "toggle" my/leader-toggle-map)
  "w" (cons "windows" my/leader-windows-map))

;;; Evil non-leader bindings
(with-eval-after-load 'evil
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map)
   "j" #'evil-next-visual-line)
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map)
   "k" #'evil-previous-visual-line)
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map)
   "<down>" #'evil-next-visual-line)
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map)
   "<up>" #'evil-previous-visual-line)
  (keymap-set evil-insert-state-map "<down>" #'evil-next-visual-line)
  (keymap-set evil-insert-state-map "<up>" #'evil-previous-visual-line)
  (keymap-set evil-normal-state-map "0" #'my/evil-smart-beginning-of-line)
  (keymap-set evil-normal-state-map "Y" #'evil-yank-line)
  (keymap-set evil-visual-state-map "Y" #'evil-yank)
  (keymap-set evil-normal-state-map "C-a" #'mark-whole-buffer)
  (keymap-set evil-insert-state-map "C-a" #'mark-whole-buffer)
  (keymap-set evil-visual-state-map "C-c" #'clipboard-kill-ring-save)
  (keymap-set evil-visual-state-map "C-<insert>" #'clipboard-kill-ring-save)
  (keymap-set evil-insert-state-map "C-v" #'clipboard-yank)
  (keymap-set evil-visual-state-map "C-v" #'evil-visual-paste)
  (keymap-set evil-insert-state-map "S-<insert>" #'clipboard-yank)
  (keymap-unset evil-normal-state-map "C-x" t)
  (keymap-unset evil-insert-state-map "C-x" t)
  (keymap-set evil-visual-state-map "C-x" #'clipboard-kill-region)
  (keymap-set evil-normal-state-map "S-<delete>" #'evil-delete-line)
  (keymap-set evil-visual-state-map "S-<delete>" #'clipboard-kill-region)
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map)
   "C-s" #'save-buffer)
  (keymap-set evil-insert-state-map "C-s" #'my/evil-normal-state-and-save)
  (evil-ex-define-cmd "q[uit]" #'evil-delete-buffer)
  (evil-ex-define-cmd "qa[ll]" #'evil-quit-all)
  (keymap-set evil-visual-state-map "<backspace>" #'evil-delete)
  (keymap-set evil-insert-state-map "C-h" #'evil-delete-backward-word)
  (keymap-set evil-normal-state-map "C-j" #'evil-window-down)
  (keymap-set evil-normal-state-map "C-k" #'evil-window-up)
  (keymap-set evil-normal-state-map "C-h" #'evil-window-left)
  (keymap-set evil-normal-state-map "C-l" #'evil-window-right)
  (keymap-set evil-normal-state-map "C-d" #'my/evil-scroll-down-and-center)
  (keymap-set evil-normal-state-map "C-u" #'my/evil-scroll-up-and-center)
  (keymap-set evil-normal-state-map "n" #'my/evil-search-next-and-center)
  (keymap-set evil-normal-state-map "N" #'my/evil-search-previous-and-center)
  (keymap-set evil-normal-state-map "{" #'my/evil-backward-paragraph-and-center)
  (keymap-set evil-normal-state-map "}" #'my/evil-forward-paragraph-and-center)
  (keymap-set evil-normal-state-map "-" #'dired-jump)

;;; Evil leader bindings
  (my/keymap-set-many
   (list evil-normal-state-map evil-visual-state-map evil-motion-state-map)
   "SPC" my/leader-map)

;;; Org localleader keymaps
  (defvar-keymap my/org-attachments-map
    :doc "Org attachment commands."
    "a" #'org-attach
    "d" #'org-attach-delete-one
    "D" #'org-attach-delete-all
    "n" #'org-attach-new
    "o" #'org-attach-open
    "O" #'org-attach-open-in-emacs
    "r" #'org-attach-reveal
    "R" #'org-attach-reveal-in-emacs
    "u" #'org-attach-url
    "s" #'org-attach-set-directory
    "S" #'org-attach-sync)

  (defvar-keymap my/org-tables-delete-map
    :doc "Org table delete commands."
    "c" #'org-table-delete-column
    "r" #'org-table-kill-row)

  (defvar-keymap my/org-tables-insert-map
    :doc "Org table insert commands."
    "c" #'org-table-insert-column
    "h" #'org-table-insert-hline
    "r" #'org-table-insert-row
    "H" #'org-table-hline-and-move)

  (defvar-keymap my/org-tables-toggle-map
    :doc "Org table toggle commands."
    "f" #'org-table-toggle-formula-debugger
    "o" #'org-table-toggle-coordinate-overlays)

  (defvar-keymap my/org-tables-map
    :doc "Org table commands."
    "-" #'org-table-insert-hline
    "a" #'org-table-align
    "b" #'org-table-blank-field
    "c" #'org-table-create-or-convert-from-region
    "e" #'org-table-edit-field
    "f" #'org-table-edit-formulas
    "h" #'org-table-field-info
    "s" #'org-table-sort-lines
    "r" #'org-table-recalculate
    "R" #'org-table-recalculate-buffer-tables
    "d" my/org-tables-delete-map
    "i" my/org-tables-insert-map
    "t" my/org-tables-toggle-map)

  (defvar-keymap my/org-clock-map
    :doc "Org clock commands."
    "c" #'org-clock-cancel
    "e" #'org-clock-modify-effort-estimate
    "E" #'org-set-effort
    "g" #'org-clock-goto
    "G" #'org-clock-goto
    "i" #'org-clock-in
    "I" #'org-clock-in-last
    "o" #'org-clock-out
    "r" #'org-resolve-clocks
    "R" #'org-clock-report
    "t" #'org-evaluate-time-range)

  (defvar-keymap my/org-date-map
    :doc "Org date and scheduling commands."
    "d" #'org-deadline
    "s" #'org-schedule
    "t" #'org-time-stamp
    "T" #'org-time-stamp-inactive)

  (defvar-keymap my/org-goto-map
    :doc "Org goto commands."
    "g" #'consult-org-heading
    "G" #'consult-org-agenda
    "c" #'org-clock-goto
    "C" #'org-clock-goto
    "i" #'org-id-goto
    "r" #'org-refile-goto-last-stored)

  (defvar-keymap my/org-links-map
    :doc "Org link commands."
    "i" #'org-id-store-link
    "l" #'org-insert-link
    "L" #'org-insert-all-links
    "s" #'org-store-link
    "S" #'org-insert-last-stored-link
    "t" #'org-toggle-link-display)

  (defvar-keymap my/org-publish-map
    :doc "Org publish commands."
    "a" #'org-publish-all
    "f" #'org-publish-current-file
    "p" #'org-publish
    "P" #'org-publish-current-project)

  (defvar-keymap my/org-refile-map
    :doc "Org refile commands."
    "r" #'org-refile
    "R" #'org-refile-reverse)

  (defvar-keymap my/org-subtree-map
    :doc "Org tree and subtree commands."
    "a" #'org-toggle-archive-tag
    "b" #'org-tree-to-indirect-buffer
    "c" #'org-clone-subtree-with-time-shift
    "d" #'org-cut-subtree
    "h" #'org-promote-subtree
    "j" #'org-move-subtree-down
    "k" #'org-move-subtree-up
    "l" #'org-demote-subtree
    "n" #'org-narrow-to-subtree
    "r" #'org-refile
    "s" #'org-sparse-tree
    "A" #'org-archive-subtree-default
    "N" #'widen
    "S" #'org-sort)

  (defvar-keymap my/org-priority-map
    :doc "Org priority commands."
    "d" #'org-priority-down
    "p" #'org-priority
    "u" #'org-priority-up)

  (defvar-keymap my/org-localleader-map
    :doc "Org commands."
    "#" #'org-update-statistics-cookies
    "'" #'org-edit-special
    "*" #'org-ctrl-c-star
    "-" #'org-ctrl-c-minus
    "," #'org-switchb
    "." #'consult-org-heading
    "/" #'consult-org-agenda
    "@" #'org-cite-insert
    "A" #'org-archive-subtree-default
    "e" #'org-export-dispatch
    "f" #'org-footnote-action
    "h" #'org-toggle-heading
    "i" #'org-toggle-item
    "I" #'org-id-get-create
    "k" #'org-babel-remove-result
    "n" #'org-store-link
    "o" #'org-set-property
    "q" #'org-set-tags-command
    "t" #'org-todo
    "T" #'org-todo-list
    "x" #'org-toggle-checkbox
    "a" my/org-attachments-map
    "b" my/org-tables-map
    "c" my/org-clock-map
    "d" my/org-date-map
    "g" my/org-goto-map
    "l" my/org-links-map
    "P" my/org-publish-map
    "R" my/org-srs-map
    "r" my/org-refile-map
    "s" my/org-subtree-map
    "p" my/org-priority-map)

  (which-key-add-keymap-based-replacements
    my/org-localleader-map
    "a" (cons "attachments" my/org-attachments-map)
    "b" (cons "tables" my/org-tables-map)
    "c" (cons "clock" my/org-clock-map)
    "d" (cons "date" my/org-date-map)
    "g" (cons "goto" my/org-goto-map)
    "l" (cons "links" my/org-links-map)
    "p" (cons "priority" my/org-priority-map)
    "P" (cons "publish" my/org-publish-map)
    "R" (cons "review" my/org-srs-map)
    "r" (cons "refile" my/org-refile-map)
    "s" (cons "subtree" my/org-subtree-map))

  (which-key-add-keymap-based-replacements
    my/org-tables-map
    "d" (cons "delete" my/org-tables-delete-map)
    "i" (cons "insert" my/org-tables-insert-map)
    "t" (cons "toggle" my/org-tables-toggle-map))

;;; Org localleader bindings
  (with-eval-after-load 'org
    (evil-define-key 'insert org-mode-map
      (kbd "C-M-<return>") #'org-insert-subheading)
    (evil-define-key '(normal visual motion) org-mode-map
      (kbd "\\") my/org-localleader-map
      (kbd "C-<return>") #'my/org-insert-heading-respect-content
      (kbd "M-<return>") #'my/org-meta-return
      (kbd "C-M-<return>") #'my/org-insert-subheading
      (kbd "S-<return>") #'my/org-table-copy-down
      (kbd "C-S-<return>") #'my/org-insert-todo-heading-respect-content
      (kbd "M-S-<return>") #'my/org-insert-todo-heading
      (kbd "] h") #'org-forward-heading-same-level
      (kbd "[ h") #'org-backward-heading-same-level
      (kbd "] l") #'org-next-link
      (kbd "[ l") #'org-previous-link
      (kbd "] c") #'org-babel-next-src-block
      (kbd "[ c") #'org-babel-previous-src-block
      (kbd "z a") #'org-cycle
      (kbd "z A") #'org-shifttab
      (kbd "z c") #'outline-hide-subtree
      (kbd "z C") #'outline-hide-subtree
      (kbd "z m") #'my/org-hide-next-fold-level
      (kbd "z M") #'org-overview
      (kbd "z n") #'org-tree-to-indirect-buffer
      (kbd "z o") #'my/org-open-fold
      (kbd "z O") #'outline-show-subtree
      (kbd "z r") #'my/org-show-next-fold-level
      (kbd "z R") #'outline-show-all
      (kbd "z i") #'org-toggle-inline-images)))
