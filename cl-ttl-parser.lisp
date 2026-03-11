(in-package #:cl-ttl-parser)

(defparameter xsd-types-plist
  '(:boolean "http://www.w3.org/2001/XMLSchema#boolean"
    :decimal "http://www.w3.org/2001/XMLSchema#decimal"
    :double "http://www.w3.org/2001/XMLSchema#double"
    :integer "http://www.w3.org/2001/XMLSchema#integer")
  "A plist containing the URIs for xsd data types.")

(defparameter rdfs-plist
  '(:first "http://www.w3.org/1999/02/22-rdf-syntax-ns#first"
    :nil "http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"
    :rest "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest")
  "A plist containing the URIS for rdfs elements.")

(define-condition cl-ttl-parser-error (simple-error)
  ()
  (:documentation "General error for use in TTL parsing.  Can be instantiated for extra information."))


;;
;; Lexer
;;
(cl-lex:define-string-lexer ttl-lexer
  ("\\;+"
   (return (values '|;| '|;|)))
  ("\\,"
   (return (values '|,| '|,|)))
  ("\\^\\^"
   (return (values '|^^| '|^^|)))
  ("@base"
   (return (values '|@base| '|@base|)))
  ;; NOTE (09/03/2026): `cl-lex' does not seem to be able to handle a `?i' in the regex, using this dirty way to support case-insensitive sparqlBase.
  ("[Bb][Aa][Ss][Ee]"
   (return (values '|spBase| '|spBase|)))
  ("@prefix"
   (return (values '|@prefix| '|@prefix|)))
  ;; NOTE (09/03/2026): See comment sparqlBase.
  ("[Pp][Rr][Ee][Ff][Ii][Xx]"
   (return (values '|spPrefix| '|spPrefix|)))
  ("true"
   (return (values '|true| t)))
  ("false"
   (return (values '|false| nil)))
  ("\\("
   (return (values '|(| '|(|)))
  ("\\)"
   (return (values '|)| '|)|)))

  ;; [18] IRIREF ::= '<' ([^#x00-#x20<>"{}|^`\] | UCHAR)* '>' /* #x00=NULL #01-#x1F=control codes #x20=space */
  ("<(([^<>\"{}|^`\\x00-\\x20\\\\]|\\\\u[0-9A-Fa-f]{4}|\\\\U[0-9A-Fa-f]{8})*)>"
   (return (values 'iriref $1)))
  ;; [140s] PNAME_LN ::= PNAME_NS PN_LOCAL
  ("([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8](([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]|\\.)*([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]))?)?:([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|:|[0-9]|%[0-9A-Fa-f][0-9A-Fa-f]|\\\\[_~.\\-!$&'()*+,;=/?#@%])(([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]|\\.|:|%[0-9A-Fa-f][0-9A-Fa-f]|\\\\[_~.\\-!$&'()*+,;=/?#@%])*([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]|:|%[0-9A-Fa-f][0-9A-Fa-f]|\\\\[_~.\\-!$&'()*+,;=/?#@%]))?"
   (return (values 'pname_ln $@)))
  ;; [139s] PNAME_NS ::= PN_PREFIX? ':'
  ("([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8](([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]|\\.)*([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]))?)?:"
   (return (values 'pname_ns $@)))
  ;; [141s] BLANK_NODE_LABEL ::= '_:' (PN_CHARS_U | [0-9]) ((PN_CHARS | '.')* PN_CHARS)?
  ("_:([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[0-9])(([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]|\\.)*([A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]|_|[\\-0-9\\xB7]))?"
   (return (values 'blank-node-label $@)))
  ;; [144s] LANGTAG ::= '@' [a-zA-Z]+ ('-' [a-zA-Z0-9]+)*
  ("@([a-zA-Z]+(-[a-zA-Z0-9]+)*)"
   (return (values 'langtag $1)))
  ;; [21] DOUBLE ::= [+-]? ([0-9]+ '.' [0-9]* EXPONENT | '.' [0-9]+ EXPONENT | [0-9]+ EXPONENT)
  ("[+-]?([0-9]+\\.[0-9]*[eE][+-]?[0-9]+|\\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)"
   (return (values 'double $@)))
  ;; [154s] EXPONENT ::= [eE] [+-]? [0-9]+
  ;; [20] DECIMAL ::= [+-]? [0-9]* '.' [0-9]+
  ("[+-]?[0-9]*\\.[0-9]+"
   (return (values 'decimal $@)))
  ;; [19] INTEGER ::= [+-]? [0-9]+
  ("[+-]?[0-9]+"
   (return (values 'integer $@)))
  ;; [25] STRING_LITERAL_LONG_QUOTE ::= '"""' (('"' | '""')? ([^"\] | ECHAR | UCHAR))* '"""'
  ("\"\"\"(((\"|\"\")?([^\"\\\\]|\\\\[tbnrf\"'\\\\]|\\\\u[0-9A-Fa-f]{4}|\\\\U[0-9A-Fa-f]{8}))*)\"\"\""
   (return (values '|string-literal-long-quote| $1)))
  ;; [22] STRING_LITERAL_QUOTE ::= '"' ([^#x22#x5C#xA#xD] | ECHAR | UCHAR)* '"' /* #x22=" #x5C=\ #xA=new line #xD=carriage return */
  ("\"(([^\\x22\\x5C\\xA\\xD]|\\\\[tbnrf\"'\\\\]|\\\\u[0-9A-Fa-f]{4}|\\\\U[0-9A-Fa-f]{8})*)\""
   (return (values '|string-literal-quote| $1)))
  ;; [24] STRING_LITERAL_LONG_SINGLE_QUOTE ::= "'''" (("'" | "''")? ([^'\] | ECHAR | UCHAR))* "'''"
  ("'''((('|'')?([^'\\\\]|\\\\[tbnrf\"'\\\\]|\\\\u[0-9A-Fa-f]{4}|\\\\U[0-9A-Fa-f]{8}))*)'''"
   (return (values '|string-literal-long-single-quote| $1)))
  ;; [23] STRING_LITERAL_SINGLE_QUOTE ::= "'" ([^#x27#x5C#xA#xD] | ECHAR | UCHAR)* "'" /* #x27=' #x5C=\ #xA=new line #xD=carriage return */
  ("'(([^\\x27\\x5C\\xA\\xD]|\\\\[tbnrf\"'\\\\]|\\\\u[0-9A-Fa-f]{4}|\\\\U[0-9A-Fa-f]{8})*)'"
   (return (values '|string-literal-single-quote| $1)))
  ;; [26] UCHAR ::= '\u' HEX HEX HEX HEX | '\U' HEX HEX HEX HEX HEX HEX HEX HEX
  ;; [159s] ECHAR ::= '\' [tbnrf"'\]
  ;; [161s] WS ::= #x20 | #x9 | #xD | #xA /* #x20=space #x9=character tabulation #xD=carriage return #xA=new line */
  ;; [162s] ANON ::= '[' WS* ']'
  ("\\[[\\x20\\x9\\xD\\xA]*\\]"
   (return (values 'anon 'anon)))
  ;; [163s] PN_CHARS_BASE ::= [A-Z] | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
  ;; [164s] PN_CHARS_U ::= PN_CHARS_BASE | '_'
  ;; [166s] PN_CHARS ::= PN_CHARS_U | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]
  ;; [167s] PN_PREFIX ::= PN_CHARS_BASE ((PN_CHARS | '.')* PN_CHARS)?
  ;; [168s] PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX))?
  ;; [169s] PLX ::= PERCENT | PN_LOCAL_ESC
  ;; [170s] PERCENT ::= '%' HEX HEX
  ;; [171s] HEX ::= [0-9] | [A-F] | [a-f]
  ;; [172s] PN_LOCAL_ESC ::= '\' ('_' | '~' | '.' | '-' | '!' | '$' | '&' | "'" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%')

  ;; Other
  ("\\."
   (return (values '|.| '|.|)))
  ("a"
   (return (values '|a| (quri:uri "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"))))
  ;; NOTE (11/03/2026): Needs to be after ANON, otherwise the square bracket for an anonymous blank
  ;; node is interpreted as a terminal.
  ("\\["
   (return (values '|[| '|[|)))
  ("\\]"
   (return (values '|]| '|]|)))

  ;; Comments
  "#[^\\xA\\xD]*"

  ;; FIXME Catchall for if we encounter non-whitespace characters that cannot be matched by any of
  ;; the above. The parser should bail out when receiving this. Should this be necessary?
  ("\\S+" (return (values '|error| $@))))


;;
;; Base
;;
(defvar *base-uri* nil)

(defun uri-absolute-p (uri)
  "Return t if URI is absolute, nil otherwise."
  (let ((uri (if (quri:uri-p uri) uri (quri:uri uri))))
    (and (quri:uri-scheme uri)
         (or (quri:uri-host uri)
             (quri:uri-path uri)))))

(define-condition iri-resolution-error (cl-ttl-parser-error)
  ((iri :initarg :iri :reader iri-resolution-error-iri)
   (reason :initarg :reason :reader iri-resolution-error-reason))
  (:report (lambda (e stream)
             (format stream "Could not resolve IRI \"~A\" because \"~A\""
                     (iri-resolution-error-iri e)
                     (iri-resolution-error-reason e))))
  (:documentation "Error signalled when an IRI cannot be resolved."))

(defun resolve-iri (iri)
  "Resolve IRI to an absolute one using `*base-uri*'.

If IRI contains a scheme and a host or path it is assumed that IRI is already an absolute uri and it
is returned as is.

This uses `quri:merge-uris' as implementation for RFC3986 Section 5.2 Relative Resolution:
<https://www.rfc-editor.org/rfc/rfc3986#section-5.2>.  While the function's docstring refers to
RFC2396 the implementation has been updated to accommodate the relevant changes between these two
RFCs as described in <https://www.rfc-editor.org/rfc/rfc3986#appendix-D>."
  (cond
    ((uri-absolute-p iri) (quri:uri iri))
    (*base-uri* (quri:merge-uris (quri:uri iri) *base-uri*))
    (t (error 'iri-resolution-error :iri iri :reason "No base IRI"))))

(defun set-base-uri (uri)
  "Set `*base-uri*' to the parsed URI."
  (setf *base-uri*
        (if (uri-absolute-p uri)
            (quri:uri uri)
            (resolve-iri uri))))


;;
;; Prefixed names
;;
(defvar *namespace* nil
  "An alist containing the known prefixes.")

(defun define-prefix (prefix iri)
  "Define a URI as expansion for PREFIX."
  (push (cons prefix (quri:uri iri)) *namespace*))

(define-condition prefix-expand-error (cl-ttl-parser-error)
  ((prefix :initarg :prefix :reader prefix-expand-error-prefix))
  (:report (lambda (e stream)
             (format stream
                     "Could not expand the prefix \"~A\"~%Known prefixes: ~{~A~^, ~}"
                     (prefix-expand-error-prefix e)
                     (mapcar #'car *namespace*))))
  (:documentation "Error signalled when a prefix cannot be expanded during parsing."))

(defun expand-prefix (prefix)
  "Return the expansion defined for PREFIX."
  (let ((entry (assoc prefix *namespace* :test #'string=)))
    (if entry
        (cdr entry)
        (error 'prefix-expand-error :prefix prefix))))

(defun split-prefixed-name (pname)
  "Split a prefixed name into its prefix, including colon, and local name."
  (let* ((colon-pos (position #\: pname))
         (pos-after-colon (1+ colon-pos)))
    (cons (subseq pname 0 pos-after-colon) (subseq pname pos-after-colon))))

(defun expand-prefixed-name (pname)
  "Expand the prefix in PNAME to its corresponding iri."
  (let* ((split (split-prefixed-name pname))
         (prefix-exp (quri:render-uri (expand-prefix (car split)))))
    (concatenate 'string prefix-exp (cdr split))))

(defun unescpace-reserved-characters (str)
  "Unescape any escaped reserved characters in STR.

See <https://www.w3.org/TR/turtle/#sec-escapes>"
  (cl-ppcre:regex-replace-all "\\\\([~\\.\\-!$&'()*+,;=/?#@%_])" str "\\1"))

(defun parse-prefixed-name (pname)
  "Parse a prefixed name PNAME to corresponding its absolute iri.

The prefix in PNAME is expanded to its corresponding iri.  If expanding PNAME results in a relative
iri it will be resolved against the current `*base*'."
  (let ((expanded-pname (expand-prefixed-name pname)))
    (resolve-iri (unescpace-reserved-characters expanded-pname))))


;;
;; Blank nodes
;;
(defvar *bnode-labels* nil
  "A list of known blank node labels.")

(defparameter *bnode-counter* 0
  "Counter used to assign unique labels to anonymous nodes.")

(defparameter *bnode-id* ""
  "A unique id used to construct the label for all blank nodes in a graph.")

(defun add-bnode (&optional label)
  "Add a new blank node to *bnode-labels* and return it.

If LABEL is nil, generate the next unique label and add it to `*bnode-labels'.
If LABEL is non-nil and does not yet exist, add it to `*bnode-labels'."
  (unless label
    (progn
      (setf label (concatenate 'string
                               "bnode-"
                               *bnode-id*
                               "-"
                               (write-to-string (incf *bnode-counter*))))))
  (unless (member label *bnode-labels*)
    (push label *bnode-labels*))
  label)


;;
;; RDF Literals
;;
(defstruct (rdf-literal (:constructor make-rdf-literal*))
  (value "" :type (or string null))
  (lang nil :type (or null string))
  (datatype nil :type (or null quri:uri)))

(define-condition rdf-literal-error (cl-ttl-parser-error)
  ((value :initarg :value :reader rdf-literal-error-value)
   (lang :initarg :lang :reader rdf-literal-error-lang)
   (datatype :initarg :datatype :reader rdf-literal-error-datatype))
  (:report (lambda (e stream)
             (format
              stream
              "An RDF literal \"~A\" cannot have both a language tag \"~A\" and a datatype iri \"~A\""
              (rdf-literal-error-value e)
              (rdf-literal-error-lang e)
              (rdf-literal-error-datatype e))))
  (:documentation "Error thrown when an error is encountered when constructing an RDF literal."))

(defun make-rdf-literal (&key value lang datatype)
  "Constructs a new RDF literal object.

If DATATYPE is non-nil it converted to a `quri:uri' if necessary."
  (if (and lang datatype)
      ;; NOTE (20/03/2026): This is an extra check, the parser itself should already signal an error
      ;; when the input being parsed contains both elements.
      (error 'rdf-literal-error :value value :lang lang :datatype datatype))
  (when (and datatype (not (quri:uri-p datatype)))
    ;; TODO: Handle potential errors from quri?
    (setf datatype (quri:uri datatype)))
  (make-rdf-literal* :value value :lang lang :datatype datatype))


;;
;; Parser
;;
(yacc:define-parser *ttl-parser*
  (:start-symbol turtleDoc)
  (:terminals ( |a|
                |.| |,| |;| |^^|
                |[| |]| |(| |)|
                |@prefix| |@base| |spBase| |spPrefix|
                iriref pname_ns pname_ln blank-node-label anon
                |true| |false|
                integer decimal double
                langtag
                |string-literal-quote| |string-literal-single-quote| |string-literal-long-single-quote| |string-literal-long-quote|))
  (:precedence nil)

  ;; [1] turtleDoc ::= statement*
  (turtleDoc
   nil
   (turtleDoc statement
              #'(lambda (td s)
                  (nconc td s))))
  ;; [2] statement ::= directive | triples '.'
  (statement
   directive
   (triples |.|
            #'(lambda (tr d)
                (declare (ignore d))
                tr)))
  ;; [3] directive ::= prefixID | base | sparqlPrefix | sparqlBase
  (directive
   prefixID
   base
   sparqlPrefix
   sparqlBase)
  ;; [4] prefixID ::= '@prefix' PNAME_NS IRIREF '.'
  (prefixID
   (|@prefix| pname_ns iriref |.|
              #'(lambda (k pre uri d)
                  (declare (ignore k d))
                  (define-prefix pre uri)
                  nil)))
  ;; [5] base ::= '@base' IRIREF '.'
  (base
   (|@base| iriref |.|
            #'(lambda (b i d)
                (declare (ignore b d))
                (set-base-uri i)
                nil)))
  ;; [5s] sparqlBase ::= "BASE" IRIREF
  (sparqlBase
   (|spBase| iriref
             #'(lambda (b i)
                 (declare (ignore b))
                 (set-base-uri i)
                 nil)))
  ;; [6s] sparqlPrefix ::= "PREFIX" PNAME_NS IRIREF
  (sparqlPrefix
   (|spPrefix| pname_ns iriref
               #'(lambda (k pre uri)
                  (declare (ignore k))
                  (define-prefix pre uri)
                  nil)))
  ;; [6] triples ::= subject predicateObjectList | blankNodePropertyList predicateObjectList?
  (triples
   (subject predicateObjectList
            ;; s1 p1 o1 . = (s1 p1 o1)
            ;; s1 p1 o1 ; p2 o2 . = ((s1 p1 o1) (s1 p2 o2))
            ;; s1 p1 o1 , o2 . = ((s1 p1 o1) (s1 p1 o2))
            ;;
            ;; s1 p1 [ ip1 io1 ] . = ((s1 p1 BNODE) (BNODE ip1 io1))
            ;; s1 p1 [ ip1 io1 ; ip2 io2 ] . = ((s1 p1 BNODE) (BNODE ip1 io1) (BNODE ip2 io2))
            ;; s1 p1 [ ip1 [ ip2 io2 ] ] . = ((s1 p1 BNODE1) (BNODE1 ip1 BNODE2) (BNODE2 ip2 io2))
            ;;
            ;; s1 p1 [ ip1 [ ip2 io2 ] ] . = ((s1 p1 BNODE1) (BNODE1 ip1 BNODE2) (BNODE2 ip2 io2))
            ;;
            ;; s1 p1 ( o1 o2 ) . = ((s1 p1 BNODE1) (BNODE1 rdf:first o1) (BNODE1 rdf:rest BNODE2)
            ;;                                     (BNODE2 rdf:first o2) (BNODE2 rdf:rest rdf:nil))
            ;; s1 p1 ( o1 ( o11 o12 ) ) . = ((s1 p1 BNODE1) (BNODE1 rdf:first o1) (BNODE1 rdf:rest BNODE2)
            ;;                                              (BNODE2 rdf:first BNODE3) (BNODE2 rdf:rest rdf:nil)
            ;;                                              (BNODE3 rdf:first o11) (BNODE3 rdf:rest BNODE4)
            ;;                                              (BNODE4 rdf:first o12) (BNODE4 rdf:rest rdf:nil))
            ;; ( s1 s2 ) p1 o1 . = ((BNODE1 p1 o1) (BNODE1 rdf:first s1) (BNODE1 rdf:rest BNODE2)
            ;;                      (BNODE2 rdf:first s2) (BNODE2 rdf:rest rdf:nil))
            #'(lambda (subj pol)
                (let ((s (if (listp subj) (caar subj) subj)))
                  (nconc (if (listp subj) subj '())
                         (loop for (pred obj) in pol
                               collect (list s pred (if (listp obj)
                                                        (caar obj)
                                                        obj))
                               if (listp obj) append obj)))))
   ;; [ p1 o1 ] . = ((BNODE1 p1 o1))
   ;; [ p1 o1 ] p2 o2 = ((BNODE1 p1 o1) (BNODE1 p2 o2))
   (blankNodePropertyList predicateObjectList?
                          #'(lambda (bpl pol)
                              (let ((subj (caar bpl)))
                                (nconc bpl
                                       (loop for (pred obj) in pol
                                             collect (list subj pred (if (listp obj)
                                                                         (caar obj)
                                                                         obj))))))))
  ;; [7] predicateObjectList ::= verb objectList (';' (verb objectList)?)*
  (predicateObjectList
   (verb objectList
         #'(lambda (v ol)
             (mapcar #'(lambda (o)
                         (list v o))
                     ol)))
   (verb objectList |;| predicateObjectList?
         #'(lambda (v ol sc pol)
             (declare (ignore sc))
             (nconc
              (mapcar #'(lambda (o)
                          (list v o))
                      ol)
              pol))))
  (predicateObjectList?
   nil
   predicateObjectList)
  ;; [8] objectList ::= object (',' object)*
  (objectList
   (object)
   (object |,| objectList
           #'(lambda (o c ol)
               (declare (ignore c))
               (push o ol))))
  ;; [9] verb ::= predicate | 'a'
  (verb
   predicate
   |a|)
  ;; [10] subject ::= iri | BlankNode | collection
  (subject
   iri
   BlankNode
   collection)
  ;; [11] predicate ::= iri
  (predicate
   iri)
  ;; [12] object ::= iri | BlankNode | collection | blankNodePropertyList | literal
  (object
   iri
   BlankNode
   collection
   blankNodePropertyList
   literal)
  ;; [13] literal ::= RDFLiteral | NumericLiteral | BooleanLiteral
  (literal
   RDFLiteral
   NumericLiteral
   BooleanLiteral)
  ;; [14] blankNodePropertyList ::= '[' predicateObjectList ']'
  (blankNodePropertyList
   (|[| predicateObjectList |]|
        #'(lambda (ob pol cb)
            (declare (ignore ob cb))
            (let ((bnode (add-bnode)))
              (nconc ()
                     (loop for (pred obj) in pol
                           collect (list bnode pred (if (listp obj)
                                                        (caar obj)
                                                        obj))
                           if (listp obj) append obj))))))
  ;; [15] collection ::= '(' object* ')'
  (collection
   (|(| object* |)|
        #'(lambda (ob objects cb)
            (declare (ignore ob cb))
            (if (null objects)
                (quri:uri (getf rdfs-plist :nil))
                (let ((nested-collections (remove-if-not #'listp objects))
                      (triples (let ((bnode (add-bnode)))
                                 (loop for (first . rest) on objects
                                       collect (list bnode (quri:uri (getf rdfs-plist :first))
                                                     (if (listp first)
                                                         (caar first) ; TODO: Is this always correct? Retrieve right BNODE from `nested-collections' instead?
                                                         first))
                                       collect (list bnode (quri:uri (getf rdfs-plist :rest))
                                                     (if (null rest)
                                                         (quri:uri (getf rdfs-plist :nil))
                                                         (setf bnode (add-bnode))))))))
                  (nconc triples (car nested-collections)))))))
  (object*
   nil
   (object object*
           #'(lambda (first rest)
               (cons first rest))))
  ;; [16] NumericLiteral ::= INTEGER | DECIMAL | DOUBLE
  (NumericLiteral
   (integer
    #'(lambda (int)
        (make-rdf-literal :value int :datatype (getf xsd-types-plist :integer))))
   (decimal
    #'(lambda (int)
        (make-rdf-literal :value int :datatype (getf xsd-types-plist :decimal))))
   (double
    #'(lambda (int)
        (make-rdf-literal :value int :datatype (getf xsd-types-plist :double)))))
  ;; [128s] RDFLiteral ::= String (LANGTAG | '^^' iri)?
  (RDFLiteral
   (String
    #'(lambda (s)
        (make-rdf-literal :value s)))
   (String langtag
           #'(lambda (s lt)
               (make-rdf-literal :value s :lang lt)))
   (String |^^| iri
           #'(lambda (s d i)
               (declare (ignore d))
               (make-rdf-literal :value s :datatype i))))
  ;; [133s] BooleanLiteral ::= 'true' | 'false'
  (BooleanLiteral
   (|true|
    #'(lambda (tr)
        (declare (ignorable tr))
        (make-rdf-literal :value "true" :datatype (getf xsd-types-plist :boolean))))
   (|false|
    #'(lambda (f)
        (declare (ignorable f))
        (make-rdf-literal :value "false" :datatype (getf xsd-types-plist :boolean)))))
  ;; [17] String ::= STRING_LITERAL_QUOTE | STRING_LITERAL_SINGLE_QUOTE | STRING_LITERAL_LONG_SINGLE_QUOTE | STRING_LITERAL_LONG_QUOTE
  (String
   |string-literal-quote|
   |string-literal-single-quote|
   |string-literal-long-single-quote|
   |string-literal-long-quote|)
  ;; [135s] iri ::= IRIREF | PrefixedName
  (iri
   (iriref
    #'(lambda (i) (resolve-iri i)))
   PrefixedName)
  ;; [136s] PrefixedName ::= PNAME_LN | PNAME_NS
  (PrefixedName
   (pname_ln
    #'(lambda (pname-ln) (parse-prefixed-name pname-ln)))
   (pname_ns
    #'(lambda (pname-ns) (parse-prefixed-name pname-ns))))
  ;; [137s] BlankNode ::= BLANK_NODE_LABEL | ANON
  (BlankNode
   (blank-node-label
    #'(lambda (l) (add-bnode l)))
   (anon
    #'(lambda (l)
        (declare (ignore l)) ; NOTE (02/03/2026): Ignore `anon' terminal
        (add-bnode)))))


;;
;; Public API
;;
(defun parse-ttl (string &optional initial-base)
  "Parse STRING as a graph described using ttl format.

INITIAL-BASE is used to resolve relative IRIs encountered before a base is explicitly set in the
STRING.  This includes relative IRIs set as base before any other absolute base is set."
  (let ((*base-uri* initial-base)
        (*namespace* nil)
        (*bnode-labels* nil)
        (*bnode-counter* 0)
        ;; NOTE (03/03/2026): Using `random' here to avoid dragging in UUID generators and their
        ;; dependencies.
        (*bnode-id* (write-to-string (random 99999))))
    (yacc:parse-with-lexer (ttl-lexer string) *ttl-parser*)))
