[
  "if" "elif" "else"
  "for" "while"
  "match"
  "break" "continue" "pass"
  "return"
  "class" "class_name" "extends"
  "func" "static" "const" "var" "onready"
  "signal" "export" "enum"
  "await" "yield"
  "in" "is" "as" "not" "and" "or"
  "true" "false" "null"
  "self"
  "breakpoint"
  "preload" "load"
] @keyword

(function_definition (name) @function)
(constructor_definition (name) @function)
(call (name) @function)
(attribute_call (name) @function)

(class_definition (name) @type)
(type) @type
(class_name_statement (name) @type)

(string) @string
(node_path) @string
(string_name) @string
(escape_sequence) @string.special

(integer) @number
(float) @number
(true) @boolean
(false) @boolean
(null) @constant.builtin

(comment) @comment

(identifier) @variable
(attribute) @property

(annotation) @attribute

[
  "(" ")" "[" "]" "{" "}"
] @punctuation.bracket

[
  "," "." ":" "->" ";"
] @punctuation.delimiter

[
  "=" "+=" "-=" "*=" "/=" "%="
  "+" "-" "*" "/" "%"
  "==" "!=" "<" ">" "<=" ">="
  "&&" "||" "!"
  "&" "|" "^" "~" "<<" ">>"
] @operator
