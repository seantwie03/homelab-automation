;;; orbit-server.el --- Orbit Org HTTP backend -*- lexical-binding: t; -*-

;; Dependency-free Emacs HTTP API for Orbit.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'org)
(require 'org-id)
(require 'subr-x)
(require 'url-parse)

(defgroup orbit nil
  "Orbit Org backend."
  :group 'applications)

(defcustom orbit-org-files nil
  "Absolute Org files served by Orbit."
  :type '(repeat file)
  :group 'orbit)

(defcustom orbit-api-token nil
  "Bearer token required for Orbit HTTP requests."
  :type '(choice (const nil) string)
  :group 'orbit)

(defcustom orbit-host "0.0.0.0"
  "Host address for `orbit-start-server'."
  :type 'string
  :group 'orbit)

(defcustom orbit-port 8787
  "Port for `orbit-start-server'."
  :type 'integer
  :group 'orbit)

(defcustom orbit-actionable-todo-keywords '("NEXT")
  "TODO keywords included in Today without a scheduled date or deadline."
  :type '(repeat string)
  :group 'orbit)

(defvar orbit--server-process nil)
(defvar orbit--client-buffers nil)

(defconst orbit--json-content-type "application/json; charset=utf-8")

(defun orbit--configured-p ()
  "Return non-nil when required Orbit configuration is present."
  (and orbit-api-token
       (stringp orbit-api-token)
       (not (string-empty-p orbit-api-token))
       orbit-org-files
       (cl-every #'file-name-absolute-p orbit-org-files)))

(defun orbit--require-config ()
  "Signal an error unless required Orbit configuration is present."
  (unless (and orbit-org-files (cl-every #'file-name-absolute-p orbit-org-files))
    (error "orbit-org-files must be a non-empty list of absolute file paths"))
  (unless (and orbit-api-token
               (stringp orbit-api-token)
               (not (string-empty-p orbit-api-token)))
    (error "orbit-api-token must be set")))

(defun orbit--json-encode (value)
  "Encode VALUE as JSON with object keys preserved as strings."
  (let ((json-object-type 'alist)
        (json-array-type 'list)
        (json-key-type 'string)
        (json-encoding-pretty-print nil))
    (json-encode value)))

(defun orbit--json-response (status body)
  "Return an HTTP response plist for STATUS and JSON BODY."
  (list :status status :headers `(("Content-Type" . ,orbit--json-content-type)) :body (orbit--json-encode body)))

(defun orbit--error-response (status message)
  "Return a JSON error response for STATUS and MESSAGE."
  (orbit--json-response status `(("error" . ,message))))

(defun orbit--date-today ()
  "Return today's date as YYYY-MM-DD."
  (format-time-string "%Y-%m-%d"))

(defun orbit--time-to-date (time)
  "Format TIME as YYYY-MM-DD."
  (when time
    (format-time-string "%Y-%m-%d" time)))

(defun orbit--org-date (value)
  "Parse Org timestamp VALUE and return YYYY-MM-DD, or nil."
  (when (and value (not (string-empty-p value)))
    (orbit--time-to-date (org-time-string-to-time value))))

(defun orbit--date-on-or-before-p (date cutoff)
  "Return non-nil when DATE is on or before CUTOFF.
Both arguments must be YYYY-MM-DD strings."
  (and date (not (string> date cutoff))))

(defun orbit--todo-done-p ()
  "Return non-nil when the current heading is done."
  (member (org-get-todo-state) org-done-keywords))

(defun orbit--task-heading-p ()
  "Return non-nil when point is on an Org TODO heading."
  (and (org-at-heading-p)
       (org-get-todo-state)))

(defun orbit--todo-actionable-p ()
  "Return non-nil when the current heading is an actionable TODO state."
  (member (org-get-todo-state) orbit-actionable-todo-keywords))

(defun orbit--file-buffer (file)
  "Return a buffer visiting FILE, reverting it first when appropriate."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer
      (when (and (not (buffer-modified-p))
                 (file-exists-p file)
                 (not (verify-visited-file-modtime buffer)))
        (revert-buffer :ignore-auto :noconfirm)))
    buffer))

(defun orbit-reload-org-buffers ()
  "Revert unmodified Orbit Org buffers that changed on disk."
  (interactive)
  (dolist (file orbit-org-files)
    (when (file-exists-p file)
      (orbit--file-buffer file))))

(defun orbit--save-if-modified ()
  "Save the current buffer when it has modifications."
  (when (buffer-modified-p)
    (save-buffer)))

(defun orbit--heading-path ()
  "Return heading ancestry for the current Org heading."
  (let (path)
    (save-excursion
      (org-back-to-heading t)
      (push (org-get-heading t t t t) path)
      (while (org-up-heading-safe)
        (push (org-get-heading t t t t) path)))
    path))

(defun orbit--heading-description ()
  "Return body text below the current heading before child headings."
  (save-excursion
    (org-back-to-heading t)
    (let* ((start (save-excursion
                    (forward-line 1)
                    (while (looking-at-p org-planning-line-re)
                      (forward-line 1))
                    (when (looking-at-p org-drawer-regexp)
                      (org-end-of-meta-data t))
                    (point)))
           (end (save-excursion
                  (outline-next-heading)
                  (point)))
           (text (string-trim (buffer-substring-no-properties start end))))
      (if (string-empty-p text) nil text))))

(defun orbit--normalize-org-timestamp (timestamp)
  "Return TIMESTAMP as YYYY-MM-DD or YYYY-MM-DDTHH:MM."
  (when (and timestamp (not (string-empty-p timestamp)))
    (let ((date (orbit--org-date timestamp)))
      (when date
        (if (string-match "\\<[0-9][0-9]?:[0-9][0-9]\\>" timestamp)
            (format-time-string "%Y-%m-%dT%H:%M" (org-time-string-to-time timestamp))
          date)))))

(defun orbit--logbook-drawer-text ()
  "Return the current heading's direct LOGBOOK drawer text, or nil."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion
                 (outline-next-heading)
                 (point)))
          start)
      (forward-line 1)
      (while (and (< (point) end) (looking-at-p org-planning-line-re))
        (forward-line 1))
      (when (looking-at-p "^[ \t]*:PROPERTIES:[ \t]*$")
        (when (re-search-forward "^[ \t]*:END:[ \t]*$" end t)
          (forward-line 1)))
      (when (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" end t)
        (setq start (line-beginning-position 2))
        (when (re-search-forward "^[ \t]*:END:[ \t]*$" end t)
          (buffer-substring-no-properties start (line-beginning-position)))))))

(defun orbit--logbook-entry-start-p (line)
  "Return non-nil when LINE starts a LOGBOOK entry."
  (string-match-p "^[ \t]*\\(?:-[ \t]+\\|CLOCK:\\)" line))

(defun orbit--logbook-parse-duration-minutes (duration)
  "Parse Org clock DURATION as minutes."
  (when (and duration (string-match "\\`\\([0-9]+\\):\\([0-9][0-9]\\)\\'" duration))
    (+ (* 60 (string-to-number (match-string 1 duration)))
       (string-to-number (match-string 2 duration)))))

(defun orbit--logbook-parse-state (line)
  "Parse LINE as an Org state change LOGBOOK entry."
  (when (string-match
         "^[ \t]*-[ \t]+State[ \t]+\"\\([^\"]+\\)\"[ \t]+from[ \t]+\"\\([^\"]+\\)\"[ \t]+\\(\\[[^]]+\\]\\)"
         line)
    (let ((to-status (match-string 1 line))
          (from-status (match-string 2 line))
          (timestamp (orbit--normalize-org-timestamp (match-string 3 line))))
      `(("type" . "state")
        ("timestamp" . ,timestamp)
        ("text" . ,(format "State \"%s\" from \"%s\"" to-status from-status))
        ("fromStatus" . ,from-status)
        ("toStatus" . ,to-status)))))

(defun orbit--logbook-parse-clock (line)
  "Parse LINE as an Org clock LOGBOOK entry."
  (when (string-match
         "^[ \t]*CLOCK:[ \t]*\\(\\[[^]]+\\]\\)--\\(\\[[^]]+\\]\\)[ \t]*=>[ \t]*\\([0-9]+:[0-9][0-9]\\)"
         line)
    (let* ((start (match-string 1 line))
           (end (match-string 2 line))
           (duration (match-string 3 line))
           (minutes (orbit--logbook-parse-duration-minutes duration)))
      `(("type" . "clock")
        ("start" . ,(orbit--normalize-org-timestamp start))
        ("end" . ,(orbit--normalize-org-timestamp end))
        ("durationMinutes" . ,minutes)
        ("text" . ,(format "Clocked %s minutes" minutes))))))

(defun orbit--logbook-parse-note (lines)
  "Parse LINES as an Org note LOGBOOK entry."
  (let ((line (car lines)))
    (when (string-match "^[ \t]*-[ \t]+Note taken on[ \t]+\\(\\[[^]]+\\]\\)" line)
      (let* ((timestamp (match-string 1 line))
             (body (string-trim
                    (mapconcat
                     (lambda (body-line)
                       (replace-regexp-in-string "^[ \t]+" "" body-line))
                     (cdr lines)
                     "\n")))
             (text (if (string-empty-p body) "Note taken" body)))
        `(("type" . "note")
          ("timestamp" . ,(orbit--normalize-org-timestamp timestamp))
          ("text" . ,text))))))

(defun orbit--logbook-parse-entry (lines)
  "Parse LINES as a fallback LOGBOOK entry."
  (let* ((text (string-trim
                (mapconcat
                 (lambda (line)
                   (replace-regexp-in-string "^[ \t]*-[ \t]*\\|^[ \t]+" "" line))
                 lines
                 "\n")))
         (timestamp (and (string-match "\\(\\[[^]]+\\]\\)" text)
                         (orbit--normalize-org-timestamp (match-string 1 text)))))
    `(("type" . "entry")
      ("timestamp" . ,timestamp)
      ("text" . ,text))))

(defun orbit--logbook-parse-entry-lines (lines)
  "Parse one LOGBOOK entry from LINES."
  (or (and (= 1 (length lines))
           (or (orbit--logbook-parse-state (car lines))
               (orbit--logbook-parse-clock (car lines))))
      (orbit--logbook-parse-note lines)
      (orbit--logbook-parse-entry lines)))

(defun orbit--heading-logbook-entries ()
  "Return structured LOGBOOK entries for the current heading."
  (let ((text (orbit--logbook-drawer-text))
        entries
        current)
    (when text
      (dolist (line (split-string text "\n"))
        (unless (string-empty-p (string-trim line))
          (if (and current (orbit--logbook-entry-start-p line))
              (progn
                (push (orbit--logbook-parse-entry-lines (nreverse current)) entries)
                (setq current (list line)))
            (push line current))))
      (when current
        (push (orbit--logbook-parse-entry-lines (nreverse current)) entries)))
    (vconcat (nreverse entries))))

(defun orbit--state-logbook-entry-present-p (from-status to-status)
  "Return non-nil if the current heading LOGBOOK has FROM-STATUS to TO-STATUS."
  (let ((text (orbit--logbook-drawer-text)))
    (and text
         (string-match-p
          (regexp-quote (format "State \"%s\"       from \"%s\"" to-status from-status))
          text))))

(defun orbit--logbook-entry-insertion-point ()
  "Return insertion point for a direct LOGBOOK entry at current heading.
Create a LOGBOOK drawer after planning/properties metadata when needed."
  (save-excursion
    (org-back-to-heading t)
    (let ((heading-end (save-excursion
                         (outline-next-heading)
                         (point)))
          drawer-start)
      (forward-line 1)
      (while (and (< (point) heading-end) (looking-at-p org-planning-line-re))
        (forward-line 1))
      (when (looking-at-p "^[ \t]*:PROPERTIES:[ \t]*$")
        (when (re-search-forward "^[ \t]*:END:[ \t]*$" heading-end t)
          (forward-line 1)))
      (setq drawer-start (point))
      (if (re-search-forward "^[ \t]*:LOGBOOK:[ \t]*$" heading-end t)
          (progn
            (unless (re-search-forward "^[ \t]*:END:[ \t]*$" heading-end t)
              (error "LOGBOOK drawer has no END"))
            (line-beginning-position))
        (goto-char drawer-start)
        (insert ":LOGBOOK:\n:END:\n")
        (forward-line -1)
        (point)))))

(defun orbit--maybe-log-state-transition (from-status to-status)
  "Record FROM-STATUS to TO-STATUS in LOGBOOK when drawer logging is enabled.
This is a fallback for noninteractive `org-todo' calls, which update the state
and CLOSED timestamp but do not always materialize a LOGBOOK state row."
  (when (and from-status
             to-status
             (not (string= from-status to-status))
             (bound-and-true-p org-log-into-drawer)
             (not (orbit--state-logbook-entry-present-p from-status to-status)))
    (save-excursion
      (goto-char (orbit--logbook-entry-insertion-point))
      (insert (format "- State \"%s\"       from \"%s\"       %s\n"
                      to-status
                      from-status
                      (format-time-string "[%Y-%m-%d %a %H:%M]"))))))

(defun orbit--explicit-priority ()
  "Return the explicit Org priority cookie at point, or nil."
  (save-excursion
    (org-back-to-heading t)
    (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
      (when (string-match "\\[#\\([A-Z0-9]\\)\\]" line)
        (match-string 1 line)))))

(defun orbit--file-revision (file point)
  "Return a deterministic freshness marker for FILE and POINT."
  (let* ((attrs (file-attributes file))
         (mtime (file-attribute-modification-time attrs))
         (line (line-number-at-pos point t))
         (title (org-get-heading t t t t))
         (state (or (org-get-todo-state) ""))
         (scheduled (or (org-entry-get point "SCHEDULED") ""))
         (deadline (or (org-entry-get point "DEADLINE") "")))
    (secure-hash
     'sha1
     (mapconcat
      #'identity
      (list (file-truename file)
            (format-time-string "%s" mtime)
            (number-to-string line)
            state
            title
            scheduled
            deadline)
      "\0"))))

(defun orbit--task-model (&optional include-detail)
  "Return the Orbit task model at point.
When INCLUDE-DETAIL is non-nil, include description, path, and LOGBOOK entries."
  (org-back-to-heading t)
  (let* ((point (point))
         (file (buffer-file-name))
         (id (org-entry-get point "ID"))
         (title (org-get-heading t t t t))
         (status (org-get-todo-state))
         (tags (org-get-tags nil t))
         (priority (orbit--explicit-priority))
         (scheduled (org-entry-get point "SCHEDULED"))
         (deadline (org-entry-get point "DEADLINE"))
         (scheduled-date (orbit--org-date scheduled))
         (deadline-date (orbit--org-date deadline))
         (today (orbit--date-today))
         (is-overdue (or (and scheduled-date (string< scheduled-date today))
                         (and deadline-date (string< deadline-date today))))
         (repeat-label (or (and scheduled (string-match "\\([.+]?+[0-9]+[hdwmy]\\)" scheduled)
                                (match-string 1 scheduled))
                           (and deadline (string-match "\\([.+]?+[0-9]+[hdwmy]\\)" deadline)
                                (match-string 1 deadline))))
         (task `(("id" . ,id)
                 ("title" . ,title)
                 ("status" . ,status)
                 ("project" . ,(car (last (butlast (orbit--heading-path)))))
                 ("tags" . ,(vconcat tags))
                 ("priority" . ,priority)
                 ("scheduledDate" . ,scheduled-date)
                 ("deadlineDate" . ,deadline-date)
                 ("isOverdue" . ,(if is-overdue t :json-false))
                 ("isRepeating" . ,(if repeat-label t :json-false))
                 ("repeatLabel" . ,repeat-label)
                 ("file" . ,file)
                 ("revision" . ,(orbit--file-revision file point)))))
    (if include-detail
        (append task
                `(("description" . ,(orbit--heading-description))
                  ("path" . ,(vconcat (orbit--heading-path)))
                  ("logbookEntries" . ,(orbit--heading-logbook-entries))))
      task)))

(defun orbit--each-task (fn)
  "Call FN at each TODO heading in `orbit-org-files'."
  (orbit--require-config)
  (dolist (file orbit-org-files)
    (unless (file-exists-p file)
      (error "Org file does not exist: %s" file))
    (with-current-buffer (orbit--file-buffer file)
      (org-with-wide-buffer
       (org-mode)
       (goto-char (point-min))
       (while (re-search-forward org-heading-regexp nil t)
         (let ((next-heading (save-excursion
                               (outline-next-heading)
                               (point-marker))))
           (unwind-protect
               (when (orbit--task-heading-p)
                 (funcall fn file))
             (goto-char next-heading)
             (set-marker next-heading nil))))))))

(defun orbit--ensure-id ()
  "Ensure current Org heading has an ID, saving the buffer if needed."
  (let ((existing (org-entry-get (point) "ID")))
    (or existing
        (prog1 (org-id-get-create)
          (orbit--save-if-modified)))))

(defun orbit--agenda-task-at-point-p (today)
  "Return non-nil when current task belongs in the Today agenda by TODAY."
  (let ((scheduled (orbit--org-date (org-entry-get (point) "SCHEDULED")))
        (deadline (orbit--org-date (org-entry-get (point) "DEADLINE")))
        (closed (orbit--org-date (org-entry-get (point) "CLOSED"))))
    (or (orbit--date-on-or-before-p scheduled today)
        (orbit--date-on-or-before-p deadline today)
        (orbit--todo-actionable-p)
        (and (orbit--todo-done-p)
             closed
             (string= closed today)))))

(defun orbit--task-has-tags-p (required-tags)
  "Return non-nil when the current task has all REQUIRED-TAGS."
  (or (null required-tags)
      (let ((tags (org-get-tags nil t)))
        (cl-every (lambda (tag) (member tag tags)) required-tags))))

(defun orbit-agenda-today (&optional required-tags)
  "Return the Today agenda response object."
  (let ((today (orbit--date-today))
        open-tasks
        done-tasks)
    (orbit--each-task
     (lambda (_file)
       (when (and (orbit--agenda-task-at-point-p today)
                  (orbit--task-has-tags-p required-tags))
         (orbit--ensure-id)
         (if (orbit--todo-done-p)
             (push (orbit--task-model) done-tasks)
           (push (orbit--task-model) open-tasks)))))
    `(("date" . ,today)
      ("tasks" . ,(vconcat (nreverse open-tasks) (nreverse done-tasks))))))

(defun orbit--find-task-by-id (id fn)
  "Find task ID and call FN at its heading.
Return FN's result or nil if no task exists."
  (let (found)
    (catch 'done
      (orbit--each-task
       (lambda (_file)
         (when (string= (org-entry-get (point) "ID") id)
           (setq found (funcall fn))
           (throw 'done found)))))
    found))

(defun orbit-task-detail (id)
  "Return task detail for ID, or nil."
  (orbit--find-task-by-id id (lambda () (orbit--task-model t))))

(defun orbit-complete-task (id)
  "Complete task ID using native Org behavior and return updated task detail."
  (orbit--find-task-by-id
   id
   (lambda ()
     (let ((from-status (org-get-todo-state)))
       (org-todo "DONE")
       (orbit--maybe-log-state-transition from-status (org-get-todo-state)))
     (orbit--save-if-modified)
     (orbit--task-model t))))

(defun orbit--authorized-p (headers)
  "Return non-nil when HEADERS contains the configured bearer token."
  (string= (cdr (assoc "authorization" headers))
           (concat "Bearer " orbit-api-token)))

(defun orbit--decode-path (path)
  "URL-decode PATH without query parameters."
  (url-unhex-string (car (split-string path "\\?" t))))

(defun orbit--decode-query-component (value)
  "URL-decode query component VALUE."
  (url-unhex-string (replace-regexp-in-string "\\+" " " value nil t)))

(defun orbit--parse-query (raw-path)
  "Return decoded query parameters from RAW-PATH as an alist."
  (let ((query (cadr (split-string raw-path "\\?" t)))
        params)
    (when query
      (dolist (part (split-string query "&" t))
        (let* ((pair (split-string part "="))
               (key (orbit--decode-query-component (or (car pair) "")))
               (value (orbit--decode-query-component
                       (mapconcat #'identity (cdr pair) "="))))
          (push (cons key value) params))))
    (nreverse params)))

(defun orbit--query-values (query key)
  "Return all values for KEY from decoded QUERY parameters."
  (let (values)
    (dolist (param query)
      (when (string= (car param) key)
        (push (cdr param) values)))
    (nreverse values)))

(defun orbit--route (method raw-path headers)
  "Route METHOD RAW-PATH with HEADERS to a response plist."
  (condition-case err
      (progn
        (orbit--require-config)
        (if (not (orbit--authorized-p headers))
            (orbit--error-response 401 "unauthorized")
          (let ((path (orbit--decode-path raw-path))
                (query (orbit--parse-query raw-path)))
            (cond
             ((and (string= method "GET") (string= path "/api/health"))
              (orbit--json-response 200 `(("ok" . t))))
             ((and (string= method "GET") (string= path "/api/agenda/today"))
              (orbit--json-response 200 (orbit-agenda-today (orbit--query-values query "tag"))))
             ((string-match "\\`/api/tasks/\\([^/]+\\)/complete\\'" path)
              (if (not (string= method "POST"))
                  (orbit--error-response 405 "method not allowed")
                (let ((task (orbit-complete-task (match-string 1 path))))
                  (if task
                      (orbit--json-response 200 task)
                    (orbit--error-response 404 "task not found")))))
             ((string-match "\\`/api/tasks/\\([^/]+\\)\\'" path)
              (if (not (string= method "GET"))
                  (orbit--error-response 405 "method not allowed")
                (let ((task (orbit-task-detail (match-string 1 path))))
                  (if task
                      (orbit--json-response 200 task)
                    (orbit--error-response 404 "task not found")))))
             ((member method '("GET" "POST"))
              (orbit--error-response 404 "not found"))
             (t
              (orbit--error-response 405 "method not allowed"))))))
    (error
     (orbit--error-response 500 (error-message-string err)))))

(defun orbit--parse-request (request)
  "Parse HTTP REQUEST into a plist."
  (when (string-match "\\`\\([A-Z]+\\) \\([^ ]+\\) HTTP/[0-9.]+\r?\n" request)
    (let ((method (match-string 1 request))
          (path (match-string 2 request))
          headers)
      (dolist (line (split-string request "\r?\n"))
        (when (string-match "\\`\\([^:]+\\):[ \t]*\\(.*\\)\\'" line)
          (push (cons (downcase (match-string 1 line))
                      (string-trim (match-string 2 line)))
                headers)))
      (list :method method :path path :headers headers))))

(defun orbit--status-text (status)
  "Return HTTP reason phrase for STATUS."
  (pcase status
    (200 "OK")
    (401 "Unauthorized")
    (404 "Not Found")
    (405 "Method Not Allowed")
    (500 "Internal Server Error")
    (_ "OK")))

(defun orbit--format-response (response)
  "Format RESPONSE plist as an HTTP response string."
  (let* ((status (plist-get response :status))
         (body (or (plist-get response :body) ""))
         (headers (append (plist-get response :headers)
                          `(("Content-Length" . ,(number-to-string (string-bytes body)))
                            ("Connection" . "close")))))
    (concat
     (format "HTTP/1.1 %d %s\r\n" status (orbit--status-text status))
     (mapconcat (lambda (header) (format "%s: %s" (car header) (cdr header))) headers "\r\n")
     "\r\n\r\n"
     body)))

(defun orbit--client-filter (process chunk)
  "Handle HTTP CHUNK from PROCESS."
  (let ((buffer (process-buffer process)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (goto-char (point-max))
        (insert chunk)
        (let ((request (buffer-string)))
          (when (string-match-p "\r?\n\r?\n" request)
            (let* ((parsed (orbit--parse-request request))
                   (response (if parsed
                                 (orbit--route (plist-get parsed :method)
                                               (plist-get parsed :path)
                                               (plist-get parsed :headers))
                               (orbit--error-response 500 "bad request"))))
              (process-send-string process (orbit--format-response response))
              (delete-process process))))))))

(defun orbit--client-sentinel (process _event)
  "Clean up PROCESS buffer."
  (let ((buffer (process-buffer process)))
    (when (buffer-live-p buffer)
      (setq orbit--client-buffers (delq buffer orbit--client-buffers))
      (kill-buffer buffer))))

(defun orbit--server-filter (process chunk)
  "Initialize a client PROCESS and handle CHUNK."
  (unless (process-buffer process)
    (let ((buffer (generate-new-buffer " *orbit-client*")))
      (push buffer orbit--client-buffers)
      (set-process-buffer process buffer)
      (set-process-sentinel process #'orbit--client-sentinel)))
  (orbit--client-filter process chunk))

;;;###autoload
(defun orbit-start-server ()
  "Start the Orbit HTTP server."
  (interactive)
  (orbit--require-config)
  (when (process-live-p orbit--server-process)
    (delete-process orbit--server-process))
  (setq orbit--server-process
        (make-network-process
         :name "orbit-http-server"
         :server t
         :host orbit-host
         :service orbit-port
         :family 'ipv4
         :filter #'orbit--server-filter
         :noquery t))
  orbit--server-process)

;;;###autoload
(defun orbit-stop-server ()
  "Stop the Orbit HTTP server and active client buffers."
  (interactive)
  (when (process-live-p orbit--server-process)
    (delete-process orbit--server-process))
  (setq orbit--server-process nil)
  (dolist (buffer orbit--client-buffers)
    (when (buffer-live-p buffer)
      (kill-buffer buffer)))
  (setq orbit--client-buffers nil))

(provide 'orbit-server)

;;; orbit-server.el ends here
