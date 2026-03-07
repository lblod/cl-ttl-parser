(in-package :cl-user)

(defpackage :cl-ttl-parser
  (:use :common-lisp)
  (:export :parse-ttl))

(defpackage #:terminals
  (:use :common-lisp))

(defpackage #:cl-ttl-parser-tests
  (:use :common-lisp))
