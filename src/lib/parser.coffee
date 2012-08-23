###
Parses grammar files.
###
class Parser

  ###
  Parses the given input and returns the result.
  ###
  parse: (@input) ->
    @position = 0
    @line     = 1
    @column   = 1

    if @Grammar() and @position == @input.length
      true
    else
      @input[@position..@position+10].replace(/\n/g, '\\n').replace(/\r/g, '\\r')

  # Parsing functions

  ###
  Evaluates the given expression, which can be one of:
  - string:   succeeds when the string matches the input starting from the current position
  - regex:    succeeds when the regex matches the input starting from the current position
  - function: succeeds when the function succeeds
  ###
  evaluate: (expression) ->
    if (type = typeof expression) is 'function'
      original_position = @position
      unless result = expression.call @
        @position = original_position
      return result

    else if type is 'string'
      if @input.substr(@position, expression.length) == expression
        @position += expression.length
        return true
      return false

    else
      unless expression instanceof RegExp
        throw new Error "Can't handle expression #{expression}"

      if match = @input.substr(@position).match expression
        @position += match[0].length
        return true
      return false

  ###
  Always succeeds.
  ###
  pass: ->
    true

  ###
  Always fails.
  ###
  fail: ->
    false

  ###
  Succeeds when all the given expressions match in the order given.
  ###
  all: (expressions) ->
    for expression in expressions
      return false unless @evaluate expression
    return true

  ###
  Succeeds when one of the given expressions succeeds. Expressions are attempted in the
  order given.
  ###
  any: (expressions) ->
    for expression in expressions
      return true if @evaluate expression
    return false

  ###
  Tries to match the given expression, but succeeds regardless.
  ###
  maybe: (expression) ->
    @evaluate expression
    return true

  ###
  Matches the given expression as many times as possible, but succeeds regardless.
  ###
  while: (expression) ->
    while @evaluate expression then ;
    return true

  ###
  Tries to match the given expression. Regardless of success, no input is consumed.
  ###
  check: (expression) ->
    original_position = @position
    result            = @evaluate expression
    @position         = original_position
    return result

  ###
  Succeeds when the given expression fails to match. Regardless of success, no input is
  consumed.
  ###
  reject: (expression) ->
    not @check expression

  # Grammar rules

  ###
  Grammar:
    Rule ( NEWLINE NEWLINE Rule )*
  ###
  Grammar: -> @all [
    @Rule
    -> @while -> @all [
      @NEWLINE
      @NEWLINE
      @Rule
    ]
  ]

  ###
  Rule:
    RuleIdentifier ':' INDENT RuleContent
  ###
  Rule: -> @all [
    @RuleIdentifier
    ':'
    @INDENT
    @RuleContent
  ]

  ###
  RuleContent:
    RuleLine ( NEWLINE '/' SPACE RuleLine )*
  ###
  RuleContent: -> @all [
    @RuleLine
    -> @while -> @all [
      @NEWLINE
      '/'
      @SPACE
      @RuleLine
    ]
  ]

  ###
  RuleLine:
    Expression ( SPACE+ Code )?
  ###
  RuleLine: -> @all [
    @Expression
    -> @maybe -> @all [
      @SPACE
      -> @while @SPACE
      @Code
    ]
  ]

  ###
  Expression:
    Sequence ( SPACE+ '/' SPACE+ Sequence )*
  ###
  Expression: -> @all [
    @Sequence
    -> @while -> @all [
      @SPACE
      -> @while @SPACE
      '/'
      @SPACE
      -> @while @SPACE
      @Sequence
    ]
  ]

  ###
  Sequence:
    Single ( SPACE+ Single )*
  ###
  Sequence: -> @all [
    @Single
    -> @while -> @all [
      @SPACE
      -> @while @SPACE
      @Single
    ]
  ]

  ###
  Single:
    ( LabelIdentifier ':' )? [&!]? Primary [?*+]?
  ###
  Single: -> @all [
    -> @maybe -> @all [
      @LabelIdentifier
      ':'
    ]
    -> @maybe /^[&!]/
    @Primary
    -> @maybe /^[?*+]/
  ]

  ###
  Primary:
    '(' SubExpression ')'
  / RuleIdentifier
  / String
  / Class
  / '.'
  / '~'
  ###
  Primary: -> @any [
    -> @all [
      '('
      @SubExpression
      ')'
    ]
    @RuleIdentifier
    @String
    @Class
    '.'
    '~'
  ]

  ###
  SubExpression:
    Space SubExpression Space
  / Expression
  ###
  SubExpression: -> @any [
    -> @all [
      @SPACE
      @SubExpression
      @SPACE
    ]
    @Expression
  ]

  ###
  Code:
    '->' DOUBLE_INDENT !WHITESPACE . ( !NEWLINE . / DOUBLE_INDENT )*
  / '->' !NEWLINE .
  ###
  Code: -> @any [
    -> @all [
      '->'
      @DOUBLE_INDENT
      -> @reject @WHITESPACE
      /^./
      -> @while -> @any [
        -> @all [
          -> @reject @NEWLINE
          /^./
        ]
        @DOUBLE_INDENT
      ]
    ]
    -> @all [
      '->'
      -> @while -> @all [
        -> @reject @NEWLINE
        /^./
      ]
    ]
  ]

  ###
  RuleIdentifier:
    [A-Z] [_a-zA-Z]*
  ###
  RuleIdentifier: -> @all [
    /^[A-Z]/
    -> @while /^[_a-zA-Z]/
  ]

  ###
  LabelIdentifier:
    [_a-z]+
  ###
  LabelIdentifier: -> @all [
    /^[_a-z]/
    -> @while /^[_a-z]/
  ]

  ###
  String:
    "'" ( ( '\\' / !"'" ) . )* "'"
  / '"' ( ( '\\' / !'"' ) . )* '"'
  ###
  String: -> @any [
    -> @all [
      "'"
      -> @while -> @all [
        -> @any [
          '\\'
          -> @reject "'"
        ]
        /^./
      ]
      "'"
    ]
    -> @all [
      '"'
      -> @while -> @all [
        -> @any [
          '\\'
          -> @reject '"'
        ]
        /^./
      ]
      '"'
    ]
  ]

  ###
  Class:
    '[' ( ( '\\' / !']' ) . )* ']'
  ###
  Class: -> @all [
    '['
    -> @while -> @all [
      -> @any [
        '\\'
        -> @reject ']'
      ]
      /^./
    ]
    ']'
  ]

  ###
  DOUBLE_INDENT:
    INDENT SPACE SPACE
  ###
  DOUBLE_INDENT: -> @all [
    @INDENT
    @SPACE
    @SPACE
  ]

  ###
  INDENT:
    NEWLINE SPACE SPACE
  ###
  INDENT: -> @all [
    @NEWLINE
    @SPACE
    @SPACE
  ]

  ###
  WHITESPACE:
    NEWLINE
  / SPACE
  ###
  WHITESPACE: -> @any [
    @NEWLINE
    @SPACE
  ]

  ###
  NEWLINE:
    '\r' '\n'?
  / '\n'
  ###
  NEWLINE: -> @any [
    -> @all [
      '\r'
      -> @maybe '\n'
    ]
    '\n'
  ]

  ###
  SPACE:
    ' '
  ###
  SPACE: ' '

start_time = Date.now()
console.log new Parser().parse '''
  Grammar:
    Rule (NEWLINE NEWLINE Rule)*

  Rule:
    RuleIdentifier ':' INDENT RuleContent

  RuleContent:
    RuleLine ( NEWLINE '/' SPACE RuleLine )*

  RuleLine:
    Expression ( SPACE+ Code )?

  Expression:
    Sequence ( SPACE+ '/' SPACE+ Sequence )*

  Sequence:
    Single (SPACE+ Single)*

  Single:
    ( LabelIdentifier ':' )? [&!]? Primary [?*+]?

  Primary:
    '(' SubExpression ')'
  / RuleIdentifier
  / String
  / Class
  / '.'
  / '~'

  SubExpression:
    SPACE SubExpression SPACE
  / Expression

  Code:
    '->' DOUBLE_INDENT !WHITESPACE . ( !NEWLINE . / DOUBLE_INDENT )*
  / '->' ( !NEWLINE . )*

  RuleIdentifier:
    [A-Z] [a-zA-Z]*

  LabelIdentifier:
    [_a-z]+

  String:
    "'" ( ( '\\\\' / !"'" ) . )* "'"
  / '"' ( ( '\\\\' / !'"' ) . )* '"'

  Class:
    '[' ( ( '\\\\' / !']' ) . )* ']'

  DOUBLE_INDENT:
    INDENT SPACE SPACE

  INDENT:
    NEWLINE SPACE SPACE

  WHITESPACE:
    NEWLINE / SPACE

  NEWLINE:
    '\\r' '\\n'? / '\\n'

  SPACE:
    ' '
'''
console.log "Took #{Date.now() - start_time}"
console.log process.memoryUsage()