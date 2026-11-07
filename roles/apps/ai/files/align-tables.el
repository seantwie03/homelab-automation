#!/usr/bin/env -S emacs --no-site-file --script
;;; align-tables.el --- Align Markdown and Org tables in place -*- lexical-binding: t -*-

;;; Commentary:

;; Usage: align-tables FILE.md|FILE.org [FILE ...]
;;
;; Align every table in each file in place, including tables wider than
;; `my--align-tables-max-width'.  Exit with status 3 when an aligned table is
;; that wide, as a warning that the caller can act on or ignore, and with
;; status 2 on a usage error.

;;; Code:

(defconst my--align-tables-max-width 109
  "Widest table, in characters, that does not trigger exit status 3.")

(defun my--align-tables-usage-error (format-string &rest args)
  "Print a usage error from FORMAT-STRING and ARGS, then exit with status 2."
  (message "%s" (apply #'format format-string args))
  (kill-emacs 2))

(defun my--align-tables-too-wide-p (file beg end)
  "Report the table from BEG to END in FILE and return non-nil if too wide."
  (save-excursion
    (goto-char beg)
    (let ((line (line-number-at-pos))
          (width 0))
      (while (< (point) end)
        (setq width (max width (string-width
                                (buffer-substring (line-beginning-position)
                                                  (line-end-position)))))
        (forward-line 1))
      (when (> width my--align-tables-max-width)
        (princ (format "%s:%d: table is %d characters wide (limit %d)\n"
                       file line width my--align-tables-max-width))
        t))))

(defun my--align-tables-org (file)
  "Align every table in the current buffer, which visits Org FILE.
Return non-nil if an aligned table is too wide."
  (let (too-wide)
    (org-mode)
    (org-table-map-tables
     (lambda ()
       (org-table-align)
       (when (my--align-tables-too-wide-p file (org-table-begin) (org-table-end))
         (setq too-wide t)))
     t)
    too-wide))

(defun my--align-tables-markdown (file)
  "Align every table in the current buffer, which visits Markdown FILE.
Return non-nil if an aligned table is too wide."
  (unless (require 'markdown-mode nil t)
    (message "align-tables: markdown-mode is not installed; start Emacs once to install it")
    (kill-emacs 1))
  (let (too-wide)
    (gfm-mode)
    (goto-char (point-min))
    (while (not (eobp))
      (if (not (markdown-table-at-point-p))
          (forward-line 1)
        (markdown-table-align)
        (when (my--align-tables-too-wide-p file (markdown-table-begin) (markdown-table-end))
          (setq too-wide t))
        (goto-char (markdown-table-end))
        (forward-line 1)))
    too-wide))

(let ((files command-line-args-left)
      (too-wide nil))
  (setq command-line-args-left nil)
  (unless files
    (my--align-tables-usage-error "usage: align-tables FILE.md|FILE.org [FILE ...]"))
  (dolist (file files)
    (unless (string-match-p "\\.\\(md\\|markdown\\|org\\)\\'" file)
      (my--align-tables-usage-error "align-tables: not a Markdown or Org file: %s" file))
    (unless (file-regular-p file)
      (my--align-tables-usage-error "align-tables: no such file: %s" file)))
  (package-initialize)
  (dolist (file files)
    (with-current-buffer (find-file-noselect file)
      (when (if (string-suffix-p ".org" file)
                (my--align-tables-org file)
              (my--align-tables-markdown file))
        (setq too-wide t))
      (when (buffer-modified-p)
        (let ((inhibit-message t))
          (save-buffer)))
      (kill-buffer)))
  (kill-emacs (if too-wide 3 0)))

;;; align-tables.el ends here
