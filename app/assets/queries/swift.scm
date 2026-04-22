[
  "if" "else" "guard"
  "for" "while" "repeat"
  "switch" "case" "default" "fallthrough"
  "break" "continue" "return" "throw"
  "do" "catch" "try" "defer"
  "import"
  "class" "struct" "enum" "protocol" "extension" "typealias" "associatedtype"
  "func" "init" "deinit" "subscript" "operator"
  "var" "let"
  "static" "override" "mutating" "nonmutating"
  "public" "private" "fileprivate" "internal" "open"
  "final" "required" "convenience" "lazy" "weak" "unowned"
  "async" "await"
  "where" "in" "is" "as"
  "self" "super" "Self"
  "nil"
  "true" "false"
  "inout" "some" "any"
  "get" "set" "willSet" "didSet"
  "throws" "rethrows"
  "indirect"
  "precedencegroup" "infix" "prefix" "postfix"
] @keyword

(function_declaration (identifier) @function)
(initializer_declaration "init" @function)

(class_declaration (identifier) @type)
(struct_declaration (identifier) @type)
(enum_declaration (identifier) @type)
(protocol_declaration (identifier) @type)
(typealias_declaration (identifier) @type)
(type_identifier) @type
(standard_type) @type.builtin

(string) @string
(static_string_literal) @string

(number) @number
(boolean_literal) @boolean

(identifier) @variable

(modifier) @keyword

[
  "(" ")" "[" "]" "{" "}"
] @punctuation.bracket

[
  "," "." ":" ";" "->" "=>"
] @punctuation.delimiter

[
  "=" "+" "-" "*" "/" "%"
  "==" "!=" "<" ">" "<=" ">="
  "&&" "||" "!"
  "&" "|" "^" "~"
  "?" "??"
  "..<" "..."
] @operator
