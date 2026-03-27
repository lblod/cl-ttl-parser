(in-package :serialize)

;; Experimental functionality to serialize a graph that is the result resulting of parsing a turtle
;; string. Currently is only supports serialising to n-triples format. This implementation does not
;; aim to be compliant to the n-triples specification.

(defun is-triple (input)
  "Return T if INPUT is a list that can represent a triple."
  (and (listp input) (= 3 (length input))))

(defun subject (triple)
  "Return the subject of TRIPLE."
  (car triple))

(defun predicate (triple)
  "Return the predicate of TRIPLE."
  (cadr triple))

(defun object (triple)
  "Return the object of TRIPLE."
  (caddr triple))

(defun serialize-uri (uri)
  "Serialize the URI by surrounding it with \"<\" and \">\".

The literal URI is just taken as is, no further transformations are applied."
  (format nil "<~A>" (quri:render-uri uri)))

(defun serialize-bnode (bnode)
  "Serialize the `blank-node' BNODE into a blank node label."
  (format nil "_:~A" (cl-ttl-parser:blank-node-label bnode)))

;; TODO: This is disturbingly dirty, should rewrite it
(defun serialize-string (str)
  "Serialize STR by replacing special characters by allowed ones and escaping double quotes."
  (cl-ppcre:regex-replace-all
   "\\xD"
   (cl-ppcre:regex-replace-all
    "\\xA"
    (cl-ppcre:regex-replace-all "([^\\\\])\"" str "\\1\\\"")
    "\\n")
   "\\r"))

(defun serialize-literal (literal)
  "Serialize an rdf LITERAL into its corresponding representation."
  (when (cl-ttl-parser:rdf-literal-p literal)
    (concatenate
     'string
     "\""
     (serialize-string (cl-ttl-parser:rdf-literal-value literal))
     "\""
     (when-let ((lang (cl-ttl-parser:rdf-literal-lang literal)))
       (format nil "@~A" lang))
     (when-let ((datatype (cl-ttl-parser:rdf-literal-datatype literal)))
       (format nil "^^~A" (serialize-uri datatype))))))

(defun serialize-object (object)
  "Serialize OBJECT as it was used as object in a triple.

OBJECT should represent a uri, rdf literal, or blank node."
  (cond
    ((quri:uri-p object) (serialize-uri object))
    ((cl-ttl-parser:rdf-literal-p object) (serialize-literal object))
    (t (serialize-bnode object))))

(defun serialize-subject (subject)
  "Serialize SUBJECT as it was used as subject in a triple.

SUBJECT should represent either a uri or a blank node."
  (if (quri:uri-p subject)
      (serialize-uri subject)
      (serialize-bnode subject)))

(defun serialize-triple (triple)
  "Serialize TRIPLE to its string representation."
  (format
   nil
   "~&~A ~A ~A ."
   (serialize-subject (subject triple))
   (serialize-uri (predicate triple))
   (serialize-object (object triple))))

(defun serialize (graph stream)
  "Serialize a GRAPH to STREAM."
  (format
   stream
   "~{~A~^~%~}"
   (mapcar (lambda (triple) (serialize-triple triple)) graph)))

(defun write-to-file (graph file)
  "Serialize GRAPH and write the result to FILE.

GRAPH is expected to be the result produced by `cl-ttl-parser:parse-ttl'.
FILE must be a path to a file and will be interpreted relative to this system.  Any existing FILE will be overwritten without warning."
  (with-open-file
      (stream
       (asdf:system-relative-pathname :cl-ttl-parser file)
       :direction :output
       :if-exists :supersede)
    (serialize graph stream)))
