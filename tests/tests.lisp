(in-package :cl-ttl-parser-tests)

(defparameter rdf11-turtle-dir "rdf-tests/rdf/rdf11/rdf-turtle/"
  "The directory in which the input test files for RDF 1.1 turtle are located.")

(defparameter fallback-base "http://cl-ttl-parser-tests.org/"
  "Default base URI used if none is provided for when running a test.")

(defun read-test-file (&key name (path "tests/test.ttl"))
  "Read the contents of the test file with NAME or the file located at PATH.

If NAME is non-nil, any provided PATH is ignored."
  (when name
    (setf path (concatenate 'string rdf11-turtle-dir name ".ttl")))
  (let ((path (asdf:system-relative-pathname :cl-ttl-parser path)))
    (alexandria:read-file-into-string path)))

(defparameter *failed-tests* '())

;; TODO Check whether file exists
;; TODO compare output to expected nt file? (graph isomorphism)
(defun run-test (name &key (initial-base fallback-base) failp)
  "Try to parse the contents of test with filename NAME.

INITIAL-BASE will be passed on the `parse-ttl' to prevent errors caused by a missing base IRI.
If FAILP is non-nil, the parsing is expected to raise a `yacc:yacc-parse-error' or
`cl-ttl-parser:cl-ttl-parser-error'."
  (let ((contents (read-test-file :name name)))
    (if failp
        (block :no-error
          (handler-case
              (cl-ttl-parser:parse-ttl contents initial-base)
            ;; TODO: Allow to specify which error is expected
            (yacc:yacc-parse-error (e)
              (format t "~&~A: [PASS] Received expected error \"~A\"" name e)
              (return-from :no-error t))
            (cl-ttl-parser::cl-ttl-parser-error (e)
              (format t "~&~A: [PASS] Received expected error \"~A\"" name e)
              (return-from :no-error t)))
          (push name *failed-tests*)
          (format t "~&~A: [FAIL] Expected a `yacc:yacc-parse-error' or `cl-ttl-parser-error' but no such error was received" name))
        (block :error
          (handler-case
              (cl-ttl-parser:parse-ttl contents initial-base)
            (error (e)
              (push name *failed-tests*)
              (format t "~&~A: [FAIL] Received an unexpected error: ~A" name e)
              (return-from :error t)))
          (format t "~&~A: [PASS] Successfully parsed" name)))))

(defun run-all-tests ()
  "Try to parse all rdf-turtle 1.1 test files."
  (let ((*failed-tests* '()))
    (load (asdf:system-relative-pathname :cl-ttl-parser "tests/test-overview.lisp"))
    (format t "~&~%Summary")
    (format t "~&Number of failed tests: ~d" (length *failed-tests*))
    (format t "~& ~{~%~a~}" *failed-tests*)))
