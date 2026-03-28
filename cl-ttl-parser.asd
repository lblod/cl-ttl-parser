(asdf:defsystem :cl-ttl-parser
  :version "0.0.1"
  :name "cl-ttl-parser"
  :description "A parser for the RDF 1.1. Turtle specification."
  :license "MIT"
  :serial t
  :depends-on (:alexandria :yacc :cl-lex :cl-ppcre :cl-interpol :quri)
  :components ((:file "packages")
               (:file "cl-ttl-parser")
               (:file "serialize")))
