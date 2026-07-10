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
(global-display-line-numbers-mode)

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
  :config
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))
