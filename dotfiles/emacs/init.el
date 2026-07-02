;;; init.el --- Init file -*- lexical-binding: t -*-

;;; Guardrail
(when (< emacs-major-version 30)
  (error "Emacs Bedrock only works with Emacs 30 and newer; you have version %s" emacs-major-version))

;; Keep generated backup and auto-save files out of project directories
(defvar my-emacs-state-directory
  (file-name-as-directory
   (if (eq system-type 'windows-nt)
       (expand-file-name "state/" user-emacs-directory)
     (expand-file-name "emacs/"
		       (or (getenv "XDG_STATE_HOME") "~/.local/state/")))))
(defvar my-emacs-backup-directory
  (expand-file-name "backups/" my-emacs-state-directory))
(defvar my-emacs-auto-save-directory
  (expand-file-name "auto-saves/" my-emacs-state-directory))
(defvar my-emacs-auto-save-list-directory
  (expand-file-name "auto-save-list/" my-emacs-state-directory))

(dolist (dir (list
	      my-emacs-backup-directory
	      my-emacs-auto-save-directory
	      my-emacs-auto-save-list-directory))
  (make-directory dir t))

(setopt backup-directory-alist `(("." . ,my-emacs-backup-directory)))
(setopt auto-save-file-name-transforms
        `((".*" ,my-emacs-auto-save-directory t)))
(setopt auto-save-list-file-prefix
        (expand-file-name ".saves-" my-emacs-auto-save-list-directory))
(setopt create-lockfiles nil)

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

;; Less aggressive screen scrolling
(setq next-screen-context-lines 10)

;; Undo early-init.el setting
(setq gc-cons-threshold (or my--initial-gc-threshold 800000))
