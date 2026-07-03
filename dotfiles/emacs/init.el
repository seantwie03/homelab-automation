;;; init.el --- Init file -*- lexical-binding: t -*-

;;; Guardrail
(when (< emacs-major-version 30)
  (error "Emacs Bedrock only works with Emacs 30 and newer; you have version %s" emacs-major-version))

;; Keep generated backup and auto-save files out of project directories.
(dolist (dir (list
              (expand-file-name "backups/" user-emacs-directory)
              (expand-file-name "auto-saves/" user-emacs-directory)
              (expand-file-name "auto-save-list/" user-emacs-directory)))
  (make-directory dir t))

(setopt backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
(setopt auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-saves/" user-emacs-directory) t)))
(setopt auto-save-list-file-prefix
        (expand-file-name "auto-save-list/.saves-" user-emacs-directory))
(setopt create-lockfiles nil)
(setopt vc-follow-symlinks t)

;; Use spaces by default; EditorConfig can override this per project.
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

(use-package editorconfig
  :ensure nil
  :config
  (editorconfig-mode 1))

(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.5)
  :config
  (which-key-mode 1))

(defun my/format-emacs-lisp-buffer ()
  "Indent the current Emacs Lisp buffer."
  (when (derived-mode-p 'emacs-lisp-mode)
    (save-excursion
      (indent-region (point-min) (point-max)))))

(add-hook 'before-save-hook #'my/format-emacs-lisp-buffer)

;; Automatically reread from disk if the underlying file changes
;; Check if polling is being used for the current buffer by running the
;; following elisp and looking for :watch in the output
;; (with-current-buffer (window-buffer (selected-window))
;;     (list :buffer (buffer-name) :file buffer-file-name :watch
;;           (and (boundp 'auto-revert-notify-watch-descriptor)
;;                auto-revert-notify-watch-descriptor)))
(setopt auto-revert-avoid-polling t)
(setopt auto-revert-interval 5)
(setopt auto-revert-check-vc-info t)
(global-auto-revert-mode)

(setq read-extended-command-predicate #'command-completion-default-include-p)
(setq enable-recursive-minibuffers t)
(setq completions-detailed t)
(minibuffer-depth-indicate-mode 1)

(use-package savehist
  :ensure nil
  :config
  (savehist-mode 1))

(use-package recentf
  :ensure nil
  :custom
  (recentf-max-saved-items 200)
  (recentf-auto-cleanup 'never)
  :bind
  ("C-c r" . recentf-open)
  :config
  (recentf-mode 1))

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

(setq completion-cycle-threshold 3
      completions-sort 'historical)

;; Scroll like Vim's scrolloff: keep point away from the window edges.
(setopt scroll-margin 8)
(setopt scroll-conservatively 101)
(setopt scroll-step 1)
(setopt scroll-preserve-screen-position t)
(setq next-screen-context-lines 8)

;; Undo early-init.el setting
(setq gc-cons-threshold (or my--initial-gc-threshold 800000))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(consult marginalia orderless)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
