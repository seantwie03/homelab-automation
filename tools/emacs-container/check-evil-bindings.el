;;; check-evil-bindings.el --- Test Evil key bindings -*- lexical-binding: t -*-

(require 'cl-lib)
(require 'evil)
(require 'org)
(require 'which-key)

(which-key-mode 1)

(defun my/test-key (keymap key)
  "Return binding for KEY in KEYMAP."
  (keymap-lookup keymap key nil t))

(defun my/assert-key (keymap key expected)
  "Assert KEY in KEYMAP resolves to EXPECTED."
  (let ((actual (my/test-key keymap key)))
    (unless (eq actual expected)
      (error "Expected %S in %S to be %S, got %S"
             key keymap expected actual))))

(defun my/assert-unbound (keymap key)
  "Assert KEY is unbound in KEYMAP."
  (let ((actual (my/test-key keymap key)))
    (unless (null actual)
      (error "Expected %S in %S to be unbound, got %S"
             key keymap actual))))

(defun my/assert-keymap (symbol)
  "Assert SYMBOL is bound to a keymap."
  (unless (and (boundp symbol) (keymapp (symbol-value symbol)))
    (error "Expected %S to be a bound keymap" symbol)))

(defun my/assert-keymap-doc (symbol)
  "Assert SYMBOL has a useful keymap docstring."
  (let ((doc (documentation-property symbol 'variable-documentation)))
    (unless (and (stringp doc)
                 (> (length doc) 0)
                 (not (string-match-p "\\`Prefix command\\'" doc)))
      (error "Missing useful which-key doc for %S: %S" symbol doc))))

(defun my/assert-which-key-bindings-readable (keymap-symbol)
  "Assert which-key can collect bindings for KEYMAP-SYMBOL."
  (let* ((keymap (symbol-value keymap-symbol))
         (bindings (which-key--get-keymap-bindings keymap)))
    (unless (listp bindings)
      (error "which-key did not return a binding list for %S: %S"
             keymap-symbol bindings))))

(defun my/assert-prefix-keymap (parent key child-symbol)
  "Assert KEY in PARENT resolves to CHILD-SYMBOL's keymap."
  (let ((actual (my/test-key parent key))
        (expected (symbol-value child-symbol)))
    (unless (eq actual expected)
      (error "Expected prefix %S to be %S, got %S"
             key child-symbol actual))))

(defun my/assert-effective-key (mode key expected)
  "Assert KEY resolves to EXPECTED in a temporary buffer using MODE."
  (with-temp-buffer
    (funcall mode)
    (evil-normal-state)
    (let ((actual (key-binding (kbd key))))
      (unless (eq actual expected)
        (error "Expected effective %S in %S to be %S, got %S"
               key mode expected actual)))))

(defun my/evil-ex-command (command)
  "Return COMMAND's resolved Evil Ex command."
  (let ((target (cdr (assoc command evil-ex-commands))))
    (while (stringp target)
      (setq target (cdr (assoc target evil-ex-commands))))
    target))

(dolist (symbol '(my/leader-map
                  my/leader-buffers-map
                  my/leader-code-map
                  my/leader-files-map
                  my/leader-git-map
                  my/leader-help-map
                  my/leader-insert-map
                  my/leader-notes-map
                  my/leader-open-agenda-map
                  my/leader-open-map
                  my/leader-search-map
                  my/leader-toggle-map
                  my/org-localleader-map
                  my/org-attachments-map
                  my/org-tables-map
                  my/org-tables-delete-map
                  my/org-tables-insert-map
                  my/org-tables-toggle-map
                  my/org-clock-map
                  my/org-date-map
                  my/org-goto-map
                  my/org-links-map
                  my/org-publish-map
                  my/org-refile-map
                  my/org-subtree-map
                  my/org-priority-map))
  (my/assert-keymap symbol)
  (my/assert-keymap-doc symbol)
  (my/assert-which-key-bindings-readable symbol))

;;; Non-leader Evil bindings
(dolist (keymap (list evil-normal-state-map evil-visual-state-map))
  (my/assert-key keymap "j" #'evil-next-visual-line)
  (my/assert-key keymap "k" #'evil-previous-visual-line)
  (my/assert-key keymap "<down>" #'evil-next-visual-line)
  (my/assert-key keymap "<up>" #'evil-previous-visual-line))

(my/assert-key evil-insert-state-map "<down>" #'evil-next-visual-line)
(my/assert-key evil-insert-state-map "<up>" #'evil-previous-visual-line)
(my/assert-key evil-normal-state-map "Y" #'evil-yank-line)
(my/assert-key evil-visual-state-map "Y" #'evil-yank)
(my/assert-key evil-normal-state-map "C-a" #'mark-whole-buffer)
(my/assert-key evil-insert-state-map "C-a" #'mark-whole-buffer)
(my/assert-key evil-normal-state-map "C-c" #'evil-yank-line)
(my/assert-key evil-visual-state-map "C-c" #'clipboard-kill-ring-save)
(my/assert-key evil-visual-state-map "C-<insert>" #'clipboard-kill-ring-save)
(my/assert-key evil-insert-state-map "C-v" #'clipboard-yank)
(my/assert-key evil-visual-state-map "C-v" #'evil-visual-paste)
(my/assert-key evil-insert-state-map "S-<insert>" #'clipboard-yank)
(my/assert-unbound evil-normal-state-map "C-x")
(my/assert-unbound evil-insert-state-map "C-x")
(my/assert-key evil-visual-state-map "C-x" #'clipboard-kill-region)
(my/assert-key evil-normal-state-map "S-<delete>" #'evil-delete-line)
(my/assert-key evil-visual-state-map "S-<delete>" #'clipboard-kill-region)
(dolist (keymap (list evil-normal-state-map evil-visual-state-map evil-insert-state-map))
  (my/assert-key keymap "C-s" #'save-buffer))
(unless (eq evil-undo-system 'undo-redo)
  (error "Expected evil-undo-system to be undo-redo, got %S"
         evil-undo-system))
(my/assert-key evil-normal-state-map "C-r" #'evil-redo)
(unless (eq (my/evil-ex-command "q") #'evil-delete-buffer)
  (error "Expected :q to resolve to evil-delete-buffer"))
(unless (eq (my/evil-ex-command "quit") #'evil-delete-buffer)
  (error "Expected :quit to resolve to evil-delete-buffer"))
(unless (eq (my/evil-ex-command "qa") #'evil-quit-all)
  (error "Expected :qa to resolve to evil-quit-all"))
(unless (eq (my/evil-ex-command "qall") #'evil-quit-all)
  (error "Expected :qall to resolve to evil-quit-all"))
(my/assert-key evil-visual-state-map "<backspace>" #'evil-delete)
(my/assert-key evil-insert-state-map "C-h" #'evil-delete-backward-word)
(my/assert-key evil-normal-state-map "C-j" #'evil-window-down)
(my/assert-key evil-normal-state-map "C-k" #'evil-window-up)
(my/assert-key evil-normal-state-map "C-h" #'evil-window-left)
(my/assert-key evil-normal-state-map "C-l" #'evil-window-right)
(my/assert-key evil-normal-state-map "-" #'dired-jump)

;;; Leader bindings
(dolist (keymap (list evil-normal-state-map evil-visual-state-map evil-motion-state-map))
  (my/assert-key keymap "SPC" my/leader-map))

(my/assert-key my/leader-map "." #'find-file)
(my/assert-key my/leader-map "," #'switch-to-buffer)
(my/assert-key my/leader-map "<" #'switch-to-buffer)
(my/assert-key my/leader-map "`" #'evil-switch-to-windows-last-buffer)
(my/assert-key my/leader-map ":" #'execute-extended-command)
(my/assert-key my/leader-map ";" #'pp-eval-expression)
(my/assert-key my/leader-map "u" #'universal-argument)
(my/assert-key my/leader-map "w" #'evil-window-map)
(my/assert-prefix-keymap my/leader-map "b" 'my/leader-buffers-map)
(my/assert-prefix-keymap my/leader-map "c" 'my/leader-code-map)
(my/assert-prefix-keymap my/leader-map "f" 'my/leader-files-map)
(my/assert-prefix-keymap my/leader-map "g" 'my/leader-git-map)
(my/assert-prefix-keymap my/leader-map "h" 'my/leader-help-map)
(my/assert-prefix-keymap my/leader-map "i" 'my/leader-insert-map)
(my/assert-prefix-keymap my/leader-map "n" 'my/leader-notes-map)
(my/assert-prefix-keymap my/leader-map "o" 'my/leader-open-map)
(my/assert-prefix-keymap my/leader-map "s" 'my/leader-search-map)
(my/assert-prefix-keymap my/leader-map "t" 'my/leader-toggle-map)

(dolist (entry '(("b" . switch-to-buffer)
                 ("B" . switch-to-buffer)
                 ("d" . kill-current-buffer)
                 ("k" . kill-current-buffer)
                 ("i" . ibuffer)
                 ("l" . evil-switch-to-windows-last-buffer)
                 ("n" . next-buffer)
                 ("p" . previous-buffer)
                 ("r" . revert-buffer)
                 ("R" . rename-buffer)
                 ("s" . write-file)
                 ("S" . evil-write-all)))
  (my/assert-key my/leader-buffers-map (car entry) (cdr entry)))

(dolist (entry '(("a" . eglot-code-actions)
                 ("c" . compile)
                 ("C" . recompile)
                 ("r" . eglot-rename)
                 ("w" . delete-trailing-whitespace)))
  (my/assert-key my/leader-code-map (car entry) (cdr entry)))

(dolist (entry '(("f" . find-file)
                 ("l" . locate)
                 ("r" . recentf-open-files)
                 ("s" . write-file)
                 ("S" . write-file)))
  (my/assert-key my/leader-files-map (car entry) (cdr entry)))

(my/assert-key my/leader-git-map "R" #'vc-revert)

(dolist (entry '(("." . helpful-at-point)
                 ("a" . apropos-command)
                 ("b" . describe-bindings)
                 ("d" . apropos-documentation)
                 ("f" . helpful-callable)
                 ("i" . info)
                 ("k" . helpful-key)
                 ("m" . describe-mode)
                 ("o" . describe-symbol)
                 ("p" . describe-package)
                 ("r" . info-emacs-manual)
                 ("u" . apropos-user-option)
                 ("v" . helpful-variable)
                 ("w" . where-is)
                 ("x" . helpful-command)))
  (my/assert-key my/leader-help-map (car entry) (cdr entry)))

(dolist (entry '(("e" . emoji-search)
                 ("r" . evil-show-registers)
                 ("u" . insert-char)))
  (my/assert-key my/leader-insert-map (car entry) (cdr entry)))

(dolist (entry '(("a" . org-agenda)
                 ("C" . org-clock-cancel)
                 ("l" . org-store-link)
                 ("m" . org-tags-view)
                 ("n" . org-capture)
                 ("o" . org-clock-goto)
                 ("t" . org-todo-list)
                 ("v" . org-search-view)))
  (my/assert-key my/leader-notes-map (car entry) (cdr entry)))

(my/assert-key my/leader-open-map "-" #'dired-jump)
(my/assert-key my/leader-open-map "A" #'org-agenda)
(my/assert-prefix-keymap my/leader-open-map "a" 'my/leader-open-agenda-map)
(my/assert-key my/leader-open-map "b" #'browse-url-of-file)
(my/assert-key my/leader-open-map "f" #'make-frame)
(my/assert-key my/leader-open-map "F" #'select-frame-by-name)

(dolist (entry '(("a" . org-agenda)
                 ("t" . org-todo-list)
                 ("m" . org-tags-view)
                 ("v" . org-search-view)))
  (my/assert-key my/leader-open-agenda-map (car entry) (cdr entry)))

(dolist (entry '(("B" . consult-line-multi)
                 ("f" . locate)
                 ("i" . imenu)
                 ("I" . consult-imenu-multi)
                 ("L" . ffap-menu)
                 ("j" . evil-show-jumps)
                 ("m" . bookmark-jump)
                 ("r" . evil-show-marks)))
  (my/assert-key my/leader-search-map (car entry) (cdr entry)))

(dolist (entry '(("c" . global-display-fill-column-indicator-mode)
                 ("f" . flymake-mode)
                 ("F" . toggle-frame-fullscreen)
                 ("r" . read-only-mode)
                 ("v" . visible-mode)
                 ("w" . visual-line-mode)))
  (my/assert-key my/leader-toggle-map (car entry) (cdr entry)))

;;; Org localleader bindings
(my/assert-key my/org-localleader-map "#" #'org-update-statistics-cookies)
(my/assert-key my/org-localleader-map "'" #'org-edit-special)
(my/assert-key my/org-localleader-map "*" #'org-ctrl-c-star)
(my/assert-key my/org-localleader-map "-" #'org-ctrl-c-minus)
(my/assert-key my/org-localleader-map "," #'org-switchb)
(my/assert-key my/org-localleader-map "." #'consult-org-heading)
(my/assert-key my/org-localleader-map "/" #'consult-org-agenda)
(my/assert-key my/org-localleader-map "@" #'org-cite-insert)
(my/assert-key my/org-localleader-map "A" #'org-archive-subtree-default)
(my/assert-key my/org-localleader-map "e" #'org-export-dispatch)
(my/assert-key my/org-localleader-map "f" #'org-footnote-action)
(my/assert-key my/org-localleader-map "h" #'org-toggle-heading)
(my/assert-key my/org-localleader-map "i" #'org-toggle-item)
(my/assert-key my/org-localleader-map "I" #'org-id-get-create)
(my/assert-key my/org-localleader-map "k" #'org-babel-remove-result)
(my/assert-key my/org-localleader-map "n" #'org-store-link)
(my/assert-key my/org-localleader-map "o" #'org-set-property)
(my/assert-key my/org-localleader-map "q" #'org-set-tags-command)
(my/assert-key my/org-localleader-map "t" #'org-todo)
(my/assert-key my/org-localleader-map "T" #'org-todo-list)
(my/assert-key my/org-localleader-map "x" #'org-toggle-checkbox)

(dolist (entry '(("a" . my/org-attachments-map)
                 ("b" . my/org-tables-map)
                 ("c" . my/org-clock-map)
                 ("d" . my/org-date-map)
                 ("g" . my/org-goto-map)
                 ("l" . my/org-links-map)
                 ("P" . my/org-publish-map)
                 ("r" . my/org-refile-map)
                 ("s" . my/org-subtree-map)
                 ("p" . my/org-priority-map)))
  (my/assert-prefix-keymap my/org-localleader-map (car entry) (cdr entry)))

(dolist (entry '(("a" . org-attach)
                 ("d" . org-attach-delete-one)
                 ("D" . org-attach-delete-all)
                 ("n" . org-attach-new)
                 ("o" . org-attach-open)
                 ("O" . org-attach-open-in-emacs)
                 ("r" . org-attach-reveal)
                 ("R" . org-attach-reveal-in-emacs)
                 ("u" . org-attach-url)
                 ("s" . org-attach-set-directory)
                 ("S" . org-attach-sync)))
  (my/assert-key my/org-attachments-map (car entry) (cdr entry)))

(dolist (entry '(("-" . org-table-insert-hline)
                 ("a" . org-table-align)
                 ("b" . org-table-blank-field)
                 ("c" . org-table-create-or-convert-from-region)
                 ("e" . org-table-edit-field)
                 ("f" . org-table-edit-formulas)
                 ("h" . org-table-field-info)
                 ("s" . org-table-sort-lines)
                 ("r" . org-table-recalculate)
                 ("R" . org-table-recalculate-buffer-tables)))
  (my/assert-key my/org-tables-map (car entry) (cdr entry)))
(my/assert-prefix-keymap my/org-tables-map "d" 'my/org-tables-delete-map)
(my/assert-prefix-keymap my/org-tables-map "i" 'my/org-tables-insert-map)
(my/assert-prefix-keymap my/org-tables-map "t" 'my/org-tables-toggle-map)

(dolist (entry '(("c" . org-table-delete-column)
                 ("r" . org-table-kill-row)))
  (my/assert-key my/org-tables-delete-map (car entry) (cdr entry)))
(dolist (entry '(("c" . org-table-insert-column)
                 ("h" . org-table-insert-hline)
                 ("r" . org-table-insert-row)
                 ("H" . org-table-hline-and-move)))
  (my/assert-key my/org-tables-insert-map (car entry) (cdr entry)))
(dolist (entry '(("f" . org-table-toggle-formula-debugger)
                 ("o" . org-table-toggle-coordinate-overlays)))
  (my/assert-key my/org-tables-toggle-map (car entry) (cdr entry)))

(dolist (entry '(("c" . org-clock-cancel)
                 ("e" . org-clock-modify-effort-estimate)
                 ("E" . org-set-effort)
                 ("g" . org-clock-goto)
                 ("G" . org-clock-goto)
                 ("i" . org-clock-in)
                 ("I" . org-clock-in-last)
                 ("o" . org-clock-out)
                 ("r" . org-resolve-clocks)
                 ("R" . org-clock-report)
                 ("t" . org-evaluate-time-range)))
  (my/assert-key my/org-clock-map (car entry) (cdr entry)))

(dolist (entry '(("d" . org-deadline)
                 ("s" . org-schedule)
                 ("t" . org-time-stamp)
                 ("T" . org-time-stamp-inactive)))
  (my/assert-key my/org-date-map (car entry) (cdr entry)))

(dolist (entry '(("g" . consult-org-heading)
                 ("G" . consult-org-agenda)
                 ("c" . org-clock-goto)
                 ("C" . org-clock-goto)
                 ("i" . org-id-goto)
                 ("r" . org-refile-goto-last-stored)))
  (my/assert-key my/org-goto-map (car entry) (cdr entry)))

(dolist (entry '(("i" . org-id-store-link)
                 ("l" . org-insert-link)
                 ("L" . org-insert-all-links)
                 ("s" . org-store-link)
                 ("S" . org-insert-last-stored-link)
                 ("t" . org-toggle-link-display)))
  (my/assert-key my/org-links-map (car entry) (cdr entry)))

(dolist (entry '(("a" . org-publish-all)
                 ("f" . org-publish-current-file)
                 ("p" . org-publish)
                 ("P" . org-publish-current-project)))
  (my/assert-key my/org-publish-map (car entry) (cdr entry)))

(my/assert-key my/org-refile-map "r" #'org-refile)
(my/assert-key my/org-refile-map "R" #'org-refile-reverse)

(dolist (entry '(("a" . org-toggle-archive-tag)
                 ("b" . org-tree-to-indirect-buffer)
                 ("c" . org-clone-subtree-with-time-shift)
                 ("d" . org-cut-subtree)
                 ("h" . org-promote-subtree)
                 ("j" . org-move-subtree-down)
                 ("k" . org-move-subtree-up)
                 ("l" . org-demote-subtree)
                 ("n" . org-narrow-to-subtree)
                 ("r" . org-refile)
                 ("s" . org-sparse-tree)
                 ("A" . org-archive-subtree-default)
                 ("N" . widen)
                 ("S" . org-sort)))
  (my/assert-key my/org-subtree-map (car entry) (cdr entry)))

(dolist (entry '(("d" . org-priority-down)
                 ("p" . org-priority)
                 ("u" . org-priority-up)))
  (my/assert-key my/org-priority-map (car entry) (cdr entry)))

(dolist (entry '(("\\ t" . org-todo)
                 ("C-M-<return>" . org-insert-subheading)
                 ("] h" . org-forward-heading-same-level)
                 ("[ h" . org-backward-heading-same-level)
                 ("] l" . org-next-link)
                 ("[ l" . org-previous-link)
                 ("] c" . org-babel-next-src-block)
                 ("[ c" . org-babel-previous-src-block)
                 ("z A" . org-shifttab)
                 ("z C" . outline-hide-subtree)
                 ("z n" . org-tree-to-indirect-buffer)
                 ("z O" . org-fold-show-subtree)
                 ("z i" . org-toggle-inline-images)))
  (my/assert-effective-key 'org-mode (car entry) (cdr entry)))

(princ "evil binding checks ok\n")

;;; check-evil-bindings.el ends here
