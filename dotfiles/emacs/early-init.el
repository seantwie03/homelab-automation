;;; early-init.el --- Early init file -*- lexical-binding: t -*-

;;; Package management
;; package.el initializes after early-init.el and before init.el, so third-party
;; archives must be configured here for first-start package installation.
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;;; Startup
(setq gc-cons-threshold 32000000
      gc-cons-percentage 0.5)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold 800000
                  gc-cons-percentage 0.1)))

(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

;; Silence the startup echo-area message.
(setq inhibit-startup-echo-area-message (user-login-name))

;;; Frame and UI
(setq frame-resize-pixelwise t)
(setq window-resize-pixelwise t)

;; Disable unused UI elements before the first frame is drawn.
;;(if (fboundp 'menu-bar-mode) (menu-bar-mode -1))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
;;(if (fboundp 'tooltip-mode) (tooltip-mode -1))

(setq default-frame-alist '((fullscreen . maximized)
                            (vertical-scroll-bars . nil)
                            (horizontal-scroll-bars . nil)))

;; Only the very first frame of a non-daemon startup can render before
;; init.el loads auto-dark/modus-themes. Rather than guess a color, start it
;; invisible; init.el reveals it (see emacs-startup-hook there) once the real
;; theme is active, so its first paint is already correct.
(setq initial-frame-alist '((visibility . nil)))
