;;; init-test.el --- Tests for init.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(ert-deftest my/evil-normal-state-and-save-enters-normal-state-before-saving ()
  (let (calls)
    (cl-letf (((symbol-function 'evil-normal-state)
               (lambda () (push 'normal-state calls)))
              ((symbol-function 'save-buffer)
               (lambda () (push 'save calls))))
      (my/evil-normal-state-and-save))
    (should (equal (nreverse calls) '(normal-state save)))))

(ert-deftest my/copy-file-name-copies-the-basename ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/project/archive.tar.gz")
    (let (copied)
      (cl-letf (((symbol-function 'kill-new)
                 (lambda (text &optional _replace)
                   (setq copied text))))
        (my/copy-file-name))
      (should (equal copied "archive.tar.gz")))))

(ert-deftest my/copy-file-name-rejects-a-non-file-buffer ()
  (with-temp-buffer
    (should-error (my/copy-file-name) :type 'user-error)))

(ert-deftest my/copy-project-relative-file-path-copies-a-relative-path ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/project/src/main.el")
    (let (copied)
      (cl-letf (((symbol-function 'project-current)
                 (lambda (&rest _) 'project))
                ((symbol-function 'project-root)
                 (lambda (_project) "/tmp/project/"))
                ((symbol-function 'kill-new)
                 (lambda (text &optional _replace)
                   (setq copied text))))
        (my/copy-project-relative-file-path))
      (should (equal copied "src/main.el")))))

(ert-deftest my/copy-project-relative-file-path-copies-an-absolute-path-without-a-project ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/notes/todo.org")
    (let (copied)
      (cl-letf (((symbol-function 'project-current)
                 (lambda (&rest _) nil))
                ((symbol-function 'kill-new)
                 (lambda (text &optional _replace)
                   (setq copied text))))
        (my/copy-project-relative-file-path))
      (should (equal copied "/tmp/notes/todo.org")))))

(ert-deftest my/copy-project-relative-file-path-rejects-a-non-file-buffer ()
  (with-temp-buffer
    (should-error (my/copy-project-relative-file-path) :type 'user-error)))

(ert-deftest my/search-symbol-at-point-starts-with-the-current-symbol ()
  (with-temp-buffer
    (insert "alpha beta")
    (goto-char (point-min))
    (let (initial)
      (cl-letf (((symbol-function 'consult-line)
                 (lambda (value &optional _start)
                   (setq initial value))))
        (my/search-symbol-at-point))
      (should (equal initial "alpha")))))

(ert-deftest my/search-symbol-at-point-allows-no-current-symbol ()
  (with-temp-buffer
    (let ((initial 'not-called))
      (cl-letf (((symbol-function 'consult-line)
                 (lambda (value &optional _start)
                   (setq initial value))))
        (my/search-symbol-at-point))
      (should-not initial))))

(ert-deftest my/search-open-buffers-searches-all-buffers ()
  (let (query)
    (cl-letf (((symbol-function 'consult-line-multi)
               (lambda (value &optional _initial)
                 (setq query value))))
      (my/search-open-buffers))
    (should query)))

(ert-deftest my/search-project-symbol-at-point-starts-with-the-current-symbol ()
  (with-temp-buffer
    (insert "alpha beta")
    (goto-char (point-min))
    (let (directory initial)
      (cl-letf (((symbol-function 'consult-ripgrep)
                 (lambda (dir value)
                   (setq directory dir
                         initial value))))
        (my/search-project-symbol-at-point))
      (should-not directory)
      (should (equal initial "alpha")))))

;;; init-test.el ends here
