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

;;; init-test.el ends here
