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

;;; init-test.el ends here
