[
  "fun" "end"
  "if" "case" "of" "when"
  "receive" "after"
  "try" "catch" "throw"
  "begin"
  "module" "export" "import"
  "record" "spec" "type" "opaque" "callback"
  "define" "include" "include_lib"
  "ifdef" "ifndef" "else" "endif" "undef"
  "not" "and" "or" "andalso" "orelse"
  "band" "bor" "bxor" "bnot" "bsl" "bsr"
  "div" "rem"
] @keyword

(atom) @string
(string) @string
(char) @string

(integer) @number
(float) @number

(comment) @comment

(function_clause (atom) @function)
(call (atom) @function)
(attribute (atom) @attribute)

(variable) @variable
(macro) @constant

[
  "(" ")" "[" "]" "{" "}" "<<" ">>"
] @punctuation.bracket

[
  "," "." ";" ":" "|" "->" "=>" "::"
] @punctuation.delimiter

[
  "=" "==" "=:=" "=/=" "/="
  "+" "-" "*" "/"
  "<" ">" "=<" ">="
  "++" "--"
  "!" "#"
] @operator
