[
  "if" "else"
  "for" "while" "do"
  "switch" "case" "default" "break" "continue"
  "return" "discard"
  "struct" "typedef" "cbuffer" "tbuffer"
  "register" "packoffset"
  "in" "out" "inout"
  "static" "const" "extern" "volatile"
  "inline"
  "true" "false"
] @keyword

(type_identifier) @type
(primitive_type) @type.builtin

(function_declarator (identifier) @function)
(call_expression (identifier) @function)

(string_literal) @string

(number_literal) @number

(comment) @comment

(identifier) @variable
(field_expression (identifier) @property)

(preproc_directive) @keyword
(preproc_include) @keyword

[
  "(" ")" "[" "]" "{" "}"
] @punctuation.bracket

[
  "," "." ";" ":"
] @punctuation.delimiter

[
  "=" "+=" "-=" "*=" "/=" "%="
  "+" "-" "*" "/" "%"
  "==" "!=" "<" ">" "<=" ">="
  "&&" "||" "!"
  "&" "|" "^" "~" "<<" ">>"
  "?" ":"
] @operator
