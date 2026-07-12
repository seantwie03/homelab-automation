;;; init.el --- Init file -*- lexical-binding: t -*-

;;; Guardrail
(when (< emacs-major-version 30)
  (error "Emacs Bedrock only works with Emacs 30 and newer; you have version %s" emacs-major-version))

;;; Package management
(use-package package
  :ensure nil
  :custom
  (package-archives
   '(("gnu" . "https://elpa.gnu.org/packages/")
     ("nongnu" . "https://elpa.nongnu.org/nongnu/")
     ("melpa" . "https://melpa.org/packages/"))))

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

(use-package savehist
  :ensure nil
  :config
  (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :config
  (save-place-mode 1))

(use-package recentf
  :ensure nil
  :custom
  (recentf-max-saved-items 200)
  (recentf-auto-cleanup 'never)
  :bind
  ("C-c r" . recentf-open)
  :init
  (recentf-mode 1))

;;; UI
(load-theme 'modus-operandi t)
(setopt ring-bell-function #'ignore)
(setopt inhibit-splash-screen t)
(setopt initial-major-mode 'org-mode)

(use-package paren
  :ensure nil
  :config
  (show-paren-mode 1))

(use-package frame
  :ensure nil
  :custom
  (cursor-in-non-selected-windows nil)
  (cursor-type '(hbar . 5))
  :config
  (blink-cursor-mode -1))

;;; Mode line
(column-number-mode 1)
(line-number-mode 1)

(use-package doom-modeline
  :ensure t
  :custom
  (doom-modeline-bar-width 1)
  (doom-modeline-icon t)
  (doom-modeline-battery nil)
  (doom-modeline-time nil)
  :config
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

(use-package display-line-numbers
  :ensure nil
  :custom
  (display-line-numbers-width-start t)
  (display-line-numbers-grow-only t)
  :config
  (global-display-line-numbers-mode 1))

(use-package editorconfig
  :ensure nil
  :config
  (editorconfig-mode 1))

(use-package delsel
  :ensure nil
  :config
  (delete-selection-mode 1))

(use-package elec-pair
  :ensure nil
  :config
  (electric-pair-mode 1))

(defun my/format-emacs-lisp-buffer ()
  "Indent the current Emacs Lisp buffer."
  (when (derived-mode-p 'emacs-lisp-mode)
    (save-excursion
      (indent-region (point-min) (point-max)))))

(defun my/delete-trailing-whitespace-maybe ()
  "Delete trailing whitespace unless the current buffer is in Org mode."
  (unless (derived-mode-p 'org-mode)
    (delete-trailing-whitespace)))

(add-hook 'before-save-hook #'my/delete-trailing-whitespace-maybe)
(add-hook 'before-save-hook #'my/format-emacs-lisp-buffer)

;; Scroll like Vim's scrolloff: keep point away from the window edges.
(setopt scroll-margin 8)
(setopt scroll-conservatively 101)
(setopt scroll-step 1)
(setopt scroll-preserve-screen-position t)
(setq next-screen-context-lines 8)

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . markdown-mode))

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
  (dired-kill-when-opening-new-dired-buffer t))

;;; Completion and navigation
(setopt read-extended-command-predicate #'command-completion-default-include-p)
(setopt enable-recursive-minibuffers t)
(setopt completions-detailed t)
(setopt completion-cycle-threshold 3)
(setopt completions-sort 'historical)
(minibuffer-depth-indicate-mode 1)

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
  :bind
  (("C-x b" . consult-buffer)
   ("C-s" . consult-line)
   ("C-c g" . consult-ripgrep)
   ("C-c f" . consult-find)
   ("C-c i" . consult-imenu)
   ("M-y" . consult-yank-pop)))

;;; Help and discovery
(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.5)
  :config
  (which-key-mode 1))

(use-package helpful
  :ensure t
  :bind
  (("C-h f" . helpful-callable)
   ("C-h v" . helpful-variable)
   ("C-h k" . helpful-key)
   ("C-h x" . helpful-command)))

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
  (project-vc-extra-root-markers '(".project")))

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

  :custom
  (org-blank-before-new-entry
   '((heading . t)
     (plain-list-item . auto)))

  (org-support-shift-select t)

  ;; Recursively include all .org files under ~/u/org in the agenda.
  ;; Files ending in .org_archive will not match this regex.
  (org-agenda-files
   (directory-files-recursively "~/u/org" "\\.org$"))

  (org-agenda-skip-scheduled-if-done nil)
  (org-agenda-skip-deadline-if-done nil)
  (org-agenda-skip-timestamp-if-done nil)
  (org-export-with-toc nil)

  (org-log-done 'time)
  (org-log-repeat 'time)
  (org-log-into-drawer "LOGBOOK")

  (org-capture-templates
   '(("t" "Task" entry
      (file "~/u/org/inbox.org")
      "* TODO %?\n:LOGBOOK:\n- Created: %U\n:END:\n")))

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

  ;; Tags:
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
  (require 'org-habit))

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
    (message "GFM export copied to clipboard"))

  (defun my/org-gfm-add-clipboard-export ()
    "Add a clipboard action to the GFM export dispatcher menu."
    (let* ((backend (org-export-get-backend 'gfm))
           (menu (org-export-backend-menu backend))
           (actions (assq-delete-all ?c (copy-tree (nth 2 menu)))))
      (setf (nth 2 menu)
            (append actions
                    (list (list ?c "To clipboard"
                                #'my/org-gfm-export-to-clipboard))))))

  (my/org-gfm-add-clipboard-export))

(use-package org-download
  :ensure t
  :after org
  :init
  (defun my/org-move-to-entry-append-position ()
    "Move point to the append position for the current Org entry body."
    (when (derived-mode-p 'org-mode)
      (org-back-to-heading t)
      (goto-char (org-entry-end-position))
      (unless (eobp)
        (open-line 1))))

  (defun my/org-move-past-image-link-for-file (buffer file)
    "In BUFFER, move point below the Org image link for FILE."
    (when (and (buffer-live-p buffer)
               file)
      (with-current-buffer buffer
        (let ((filename (file-name-nondirectory file)))
          (goto-char (point-min))
          (when (search-forward filename nil t)
            (end-of-line)
            (forward-line)
            (unless (looking-at-p "\\(?:[ \t]*$\\)")
              (open-line 1)))))))

  (defun my/org-download-clipboard ()
    "Attach an image from the clipboard to the current Org entry."
    (interactive)
    (my/org-move-to-entry-append-position)
    (let ((buffer (current-buffer)))
      (org-download-clipboard)
      (my/org-move-past-image-link-for-file buffer org-download-path-last-file)
      (run-at-time 0 nil #'my/org-move-past-image-link-for-file
                   buffer org-download-path-last-file)))

  (defun my/org-download-file-format (filename)
    "Format org-download FILENAME with timestamp and current Org heading."
    (let* ((heading (if (derived-mode-p 'org-mode)
                        (org-get-heading t t t t)
                      "image"))
           (slug (downcase
                  (replace-regexp-in-string "[^[:alnum:]]+" "-" heading))))
      (setq slug (replace-regexp-in-string "\\`-+\\|-+\\'" "" slug))
      (format "%s%s_%s"
              (format-time-string "%Y-%m-%d_%H-%M-%S_")
              (if (string-empty-p slug) "image" slug)
              filename)))
  :custom
  (org-download-method 'attach)
  :config
  (setq org-download-file-format-function #'my/org-download-file-format)
  (setq org-attach-commands
        (seq-remove (lambda (command)
                      (member ?i (car command)))
                    org-attach-commands))
  (add-to-list 'org-attach-commands
               '((?i) my/org-download-clipboard
                 "Attach an image from the clipboard.")))

;;; Startup cleanup
;; Undo early-init.el setting
(setq gc-cons-threshold (or my--initial-gc-threshold 800000))

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

;;; Evil leader keymaps
(defvar-keymap my/leader-buffers-map
  :doc "Buffer commands."
  "b" #'switch-to-buffer
  "B" #'switch-to-buffer
  "d" #'kill-current-buffer
  "k" #'kill-current-buffer
  "i" #'ibuffer
  "l" #'evil-switch-to-windows-last-buffer
  "n" #'next-buffer
  "p" #'previous-buffer
  "r" #'revert-buffer
  "R" #'rename-buffer
  "s" #'write-file
  "S" #'evil-write-all)

(defvar-keymap my/leader-code-map
  :doc "Code commands."
  "a" #'eglot-code-actions
  "c" #'compile
  "C" #'recompile
  "r" #'eglot-rename
  "w" #'delete-trailing-whitespace)

(defvar-keymap my/leader-files-map
  :doc "File commands."
  "f" #'find-file
  "l" #'locate
  "r" #'recentf-open-files
  "s" #'write-file
  "S" #'write-file)

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
  "r" #'evil-show-registers
  "u" #'insert-char)

(defvar-keymap my/leader-notes-map
  :doc "Notes and Org commands."
  "a" #'org-agenda
  "C" #'org-clock-cancel
  "l" #'org-store-link
  "m" #'org-tags-view
  "n" #'org-capture
  "o" #'org-clock-goto
  "t" #'org-todo-list
  "v" #'org-search-view)

(defvar-keymap my/leader-open-agenda-map
  :doc "Open Org agenda commands."
  "a" #'org-agenda
  "t" #'org-todo-list
  "m" #'org-tags-view
  "v" #'org-search-view)

(defvar-keymap my/leader-open-map
  :doc "Open commands."
  "-" #'dired-jump
  "A" #'org-agenda
  "a" my/leader-open-agenda-map
  "b" #'browse-url-of-file
  "f" #'make-frame
  "F" #'select-frame-by-name)

(defvar-keymap my/leader-search-map
  :doc "Search and jump commands."
  "B" #'consult-line-multi
  "f" #'locate
  "i" #'imenu
  "I" #'consult-imenu-multi
  "L" #'ffap-menu
  "j" #'evil-show-jumps
  "m" #'bookmark-jump
  "r" #'evil-show-marks)

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
  "." #'find-file
  "," #'switch-to-buffer
  "<" #'switch-to-buffer
  "`" #'evil-switch-to-windows-last-buffer
  ":" #'execute-extended-command
  ";" #'pp-eval-expression
  "u" #'universal-argument
  "w" #'evil-window-map
  "b" my/leader-buffers-map
  "c" my/leader-code-map
  "f" my/leader-files-map
  "g" my/leader-git-map
  "h" my/leader-help-map
  "i" my/leader-insert-map
  "n" my/leader-notes-map
  "o" my/leader-open-map
  "s" my/leader-search-map
  "t" my/leader-toggle-map)

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
    "r" my/org-refile-map
    "s" my/org-subtree-map
    "p" my/org-priority-map)

;;; Org localleader bindings
  (defun my/org-evil-local-bindings ()
    "Set buffer-local Evil bindings for Org buffers."
    (evil-local-set-key 'normal (kbd "] l") #'org-next-link)
    (evil-local-set-key 'normal (kbd "[ l") #'org-previous-link))

  (with-eval-after-load 'org
    (add-hook 'org-mode-hook #'my/org-evil-local-bindings)
    (evil-define-key 'insert org-mode-map
      (kbd "C-M-<return>") #'org-insert-subheading)
    (evil-define-key '(normal visual motion) org-mode-map
      (kbd "\\") my/org-localleader-map
      (kbd "C-M-<return>") #'org-insert-subheading
      (kbd "] h") #'org-forward-heading-same-level
      (kbd "[ h") #'org-backward-heading-same-level
      (kbd "] l") #'org-next-link
      (kbd "[ l") #'org-previous-link
      (kbd "] c") #'org-babel-next-src-block
      (kbd "[ c") #'org-babel-previous-src-block
      (kbd "z A") #'org-shifttab
      (kbd "z C") #'outline-hide-subtree
      (kbd "z n") #'org-tree-to-indirect-buffer
      (kbd "z O") #'outline-show-subtree
      (kbd "z i") #'org-toggle-inline-images)))
