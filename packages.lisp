(in-package :cl-user)

(defpackage :cl-ttl-parser
  (:use :common-lisp)
  (:export :parse-ttl
   :rdf-literal :rdf-literal-value :rdf-literal-lang :rdf-literal-datatype
   :blank-node :blank-node-label))

(defpackage #:terminals
  (:use :common-lisp))

(defpackage #:serialize
  (:use :common-lisp)
  (:export
   #:serialize
   #:write-to-file)
  (:import-from #:alexandria
                #:when-let))

(defpackage #:cl-ttl-parser-tests
  (:use :common-lisp))
