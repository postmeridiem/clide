[
  "true" "false" "null"
  "if" "else" "endif"
  "for" "in" "endfor"
] @keyword

(block (identifier) @keyword)
(block (body (block (identifier) @type)))

(string_lit) @string
(template_literal) @string
(heredoc_template) @string
(template_interpolation) @string.special

(numeric_lit) @number

(comment) @comment

(function_call (identifier) @function)

(identifier) @variable
(variable_expr) @variable

(attribute (identifier) @property)

[
  "(" ")" "[" "]" "{" "}"
] @punctuation.bracket

[
  "." "," ":" "=>"
] @punctuation.delimiter

[
  "=" "==" "!=" "<" ">" "<=" ">="
  "+" "-" "*" "/" "%"
  "&&" "||" "!"
  "?" ":"
] @operator
