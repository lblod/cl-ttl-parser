;; Helper variables for the terminal regular expressions.
(in-package :terminals)

(defvar pn-local-esc "\\\\[_~.\\-!$&'()*+,;=/?#@%]"
  "[172s] PN_LOCAL_ESC ::= '\' ('_' | '~' | '.' | '-' | '!' | '$' | '&' | \"'\" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%')")

(defvar hex "[0-9A-Fa-f]"
  "[171s] HEX ::= [0-9] | [A-F] | [a-f]")

(defvar percent (concatenate 'string "%" hex hex)
  "[170s] PERCENT ::= '%' HEX HEX")

(defvar plx (concatenate 'string percent "|" pn-local-esc)
  "[169s] PLX ::= PERCENT | PN_LOCAL_ESC")

;; TODO remaining unicode characters
(defvar pn-chars-base "[A-Za-z\\xC0-\\xD6\\xD8-\\xF6\\xF8]"
  "[163s] PN_CHARS_BASE ::= [A-Z] | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]")

(defvar pn-chars-u (concatenate 'string pn-chars-base "|_")
  "[164s] PN_CHARS_U ::= PN_CHARS_BASE | '_'")

;; TODO remaining unicode characters
(defvar pn-chars (concatenate 'string pn-chars-u "|[\\-0-9\\xB7]")
  "[166s] PN_CHARS ::= PN_CHARS_U | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]")

(defvar pn-local (concatenate 'string "(" pn-chars-u "|:|[0-9]|" plx ")((" pn-chars "|\\.|:|" plx ")*(" pn-chars "|:|" plx "))?")
  "[168s] PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX))?")

(defvar pn-prefix (concatenate 'string pn-chars-base "((" pn-chars "|\\.)*(" pn-chars "))?")
  "[167s] PN_PREFIX ::= PN_CHARS_BASE ((PN_CHARS | '.')* PN_CHARS)?")

(defvar ws "\\x20|\\x9|\\xD|\\xA"
  ";; [161s] WS ::= #x20 | #x9 | #xD | #xA /* #x20=space #x9=character tabulation #xD=carriage return #xA=new line */")

(defvar anon (concatenate 'string "\\[(" ws ")*\\]")
  ";; [162s] ANON ::= '[' WS* ']'")

(defvar echar "\\\\[tbnrf\"'\\\\]"
  ";; [159s] ECHAR ::= '\' [tbnrf\"'\]")

(defvar uchar (concatenate 'string "\\\\u" hex "{4}|\\\\U" hex "{8}")
  ";; [26] UCHAR ::= '\u' HEX HEX HEX HEX | '\U' HEX HEX HEX HEX HEX HEX HEX HEX")

(defvar string-literal-single-quote (concatenate 'string "'(([^\\x27\\x5C\\xA\\xD]|" echar "|" uchar  ")*)'")
    ";; [23] STRING_LITERAL_SINGLE_QUOTE ::= \"'\" ([^#x27#x5C#xA#xD] | ECHAR | UCHAR)* \"'\" /* #x27=' #x5C=\\ #xA=new line #xD=carriage return */")

(defvar string-literal-long-single-quote (concatenate 'string "'''((('|'')?([^'\\\\]|" echar "|" uchar "))*)'''")
    ";; [24] STRING_LITERAL_LONG_SINGLE_QUOTE ::= \"'''\" ((\"'\" | \"''\")? ([^'\\] | ECHAR | UCHAR))* \"'''\"")

(defvar string-literal-quote (concatenate 'string "\"(([^\\x22\\x5C\\xA\\xD]|" echar "|" uchar ")*)\"")
  ";; [22] STRING_LITERAL_QUOTE ::= '\"' ([^#x22#x5C#xA#xD] | ECHAR | UCHAR)* '\"' /* #x22=\" #x5C=\ #xA=new line #xD=carriage return */")

(defvar string-literal-long-quote (concatenate 'string "\"\"\"(((\"|\"\")?([^\"\\\\]|" echar "|" uchar "))*)\"\"\"")
  ";; [25] STRING_LITERAL_LONG_QUOTE ::= '\"\"\"' (('\"' | '\"\"')? ([^\"\] | ECHAR | UCHAR))* '\"\"\"'")

(defvar integer-terminal "[+-]?[0-9]+"
  ";; [19] INTEGER ::= [+-]? [0-9]+")

(defvar decimal "[+-]?[0-9]*\\.[0-9]+"
  ";; [20] DECIMAL ::= [+-]? [0-9]* '.' [0-9]+")

(defvar exponent "[eE][+-]?[0-9]+"
  ";; [154s] EXPONENT ::= [eE] [+-]? [0-9]+")

(defvar double (concatenate 'string "[+-]?([0-9]+\\.[0-9]*" exponent "|\\.[0-9]+" exponent "|[0-9]+" exponent ")")
  ";; [21] DOUBLE ::= [+-]? ([0-9]+ '.' [0-9]* EXPONENT | '.' [0-9]+ EXPONENT | [0-9]+ EXPONENT)")

(defvar langtag "@[a-zA-Z]+(-[a-zA-Z0-9]+)*"
  ";; [144s] LANGTAG ::= '@' [a-zA-Z]+ ('-' [a-zA-Z0-9]+)*")

(defvar blank-node-label (concatenate 'string "_:(" pn-chars-u "|[0-9])((" pn-chars "|\\.)*(" pn-chars "))?")
  ";; [141s] BLANK_NODE_LABEL ::= '_:' (PN_CHARS_U | [0-9]) ((PN_CHARS | '.')* PN_CHARS)?")

(defvar pname-ns (concatenate 'string "(" pn-prefix ")?:")
  ";; [139s] PNAME_NS ::= PN_PREFIX? ':'")

(defvar pname-ln (concatenate 'string pname-ns pn-local)
  ";; [140s] PNAME_LN ::= PNAME_NS PN_LOCAL")

(defvar iriref (concatenate 'string "<(([^<>\"{}|^`\\x00-\\x20\\\\]|" uchar ")*)>")
  ";; [18] IRIREF ::= '<' ([^#x00-#x20<>\"{}|^`\\] | UCHAR)* '>' /* #x00=NULL #01-#x1F=control codes #x20=space */")
