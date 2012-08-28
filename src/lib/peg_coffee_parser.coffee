Parser = require './parser'

module.exports = class PegCoffeeParser extends Parser

  ###
  Matches an entire grammar.
  ###
  Grammar: ->
    action = ({ head, tail }) ->
      type:    'grammar'
      content: [ head ].concat @extract tail, 2

    @action @all, [
      [ @label, 'head', @Rule ]
      [ @label, 'tail', @maybe_some, @all, [
        @NEWLINE
        @NEWLINE
        @Rule
      ] ]
    ], action

  ###
  Matches a rule definition.
  ###
  Rule: ->
    action = ({ name, def }) ->
      type:    'definition'
      name:    name
      content: def

    @action @all, [
      [ @label, 'name', @RuleIdentifier ]
      [ @literal, ':' ]
      @INDENT
      [ @label, 'def', @RuleContent ]
    ], action

  ###
  Matches the content of a rule.
  ###
  RuleContent: ->
    action = ({ head, tail }) ->
      if tail.length is 0
        head
      else
        type:    'choice'
        content: [ head ].concat  @extract tail, 2

    @action @all, [
      [ @label, 'head', @RuleLine ]
      [ @label, 'tail', @maybe_some, @all, [
        @NEWLINE
        [ @literal, '/' ]
        @SPACE
        @RuleLine
      ] ]
    ], action

  ###
  Matches an expression possibly followed by some code.
  ###
  RuleLine: ->
    action = ({ expr, code }) ->
      expr.action = code[1] if code
      expr

    @action @all, [
      [ @label, 'expr', @Expression ]
      [ @label, 'code', @maybe, @all, [
        [ @some, @SPACE ]
        @Code
      ] ]
    ], action

  ###
  Matches a number of sequence delimited by the choice operator.
  ###
  Expression: ->
    action = ({ head, tail }) ->
      if tail.length is 0
        head
      else
        type:    'choice'
        content: [ head ].concat @extract tail, 3

    @action @all, [
      [ @label, 'head', @Sequence ]
      [ @label, 'tail', @maybe_some, @all, [
        [ @some, @SPACE ]
        [ @literal, '/' ]
        [ @some, @SPACE ]
        @Sequence
      ] ]
    ], action

  ###
  Matches a number of Singles delimited by spaces
  ###
  Sequence: ->
    action = ({ head, tail }) ->
      if tail.length is 0
        head
      else
        type:    'sequence'
        content: [ head ].concat @extract tail, 1

    @action @all, [
      [ @label, 'head', @Single ]
      [ @label, 'tail', @maybe_some, @all, [
        [ @some, @SPACE ]
        @Single
      ] ]
    ], action

  ###
  Matches a single complex expression.
  ###
  Single: ->
    action = ({ label, prefix, primary, suffix }) ->
      primary.label  = label[0] if label
      primary.prefix = prefix   if prefix
      primary.suffix = suffix   if suffix
      primary

    @action @all, [
      [ @label, 'label', @maybe, @all, [
        @LabelIdentifier
        [ @literal, ':' ]
      ] ]
      [ @label, 'prefix',  @maybe, @regex, /^[&!]/  ]
      [ @label, 'primary', @Primary                 ]
      [ @label, 'suffix',  @maybe, @regex, /^[?*+]/ ]
    ], action

  ###
  Matches a 'primary' expression.
  ###
  Primary: ->
    action_sub_expression = ({ sub }) ->
      if sub.label
        type:    'subexpression'
        content: sub
      else
        sub

    action_rule = ({ $$ }) ->
      type: 'rule'
      name: $$

    action_string = ({ $$ }) ->
      type:    'literal'
      content: $$

    action_class = ({ $$ }) ->
      type:    'class'
      content: $$

    action_wildcard = ->
      type: 'wildcard'

    action_pass = ->
      type: 'pass'

    @any [
      [ @action, @all, [
        [ @literal, '(' ]
        [ @label, 'sub', @SubExpression ]
        [ @literal, ')' ]
      ], action_sub_expression ]
      [ @action, @RuleIdentifier, action_rule     ]
      [ @action, @String,         action_string   ]
      [ @action, @Class,          action_class    ]
      [ @action, @literal, '.',   action_wildcard ]
      [ @action, @literal, '~',   action_pass     ]
    ]

  ###
  Matches the contents of a parenthesised sub expression.
  ###
  SubExpression: ->
    action = ({ sub }) ->
      sub

    @any [
      [ @action, @all, [
        @SPACE
        [ @label, 'sub', @SubExpression ]
        @SPACE
      ], action ]
      @Expression
    ]

  ###
  Matches code in one of two formats:
  - block
  - inline
  ###
  Code: ->
    action_block = ({ $$ }) ->
      @join($$[2..]).trim()

    action_inline = ({ $$ }) ->
      @join($$[1..]).trim()

    @any [
      [ @action, @all, [
        [ @literal, '->' ]
        @DOUBLE_INDENT
        [ @reject, @WHITESPACE ]
        @advance
        [ @maybe_some, @any, [
          [ @all, [
            [ @reject, @NEWLINE ]
            @advance
          ] ]
          [ @all, [
            [ @maybe_some, @all, [
              [ @reject, @DOUBLE_INDENT ]
              @WHITESPACE
            ] ]
            @DOUBLE_INDENT
          ] ]
        ] ]
      ], action_block ]
      [ @action, @all, [
        [ @literal, '->' ]
        [ @some, @SPACE ]
        [ @some, @all, [
          [ @reject, @NEWLINE ]
          @advance
        ] ]
      ], action_inline ]
    ]

  ###
  Matches a rule identifier.
  ###
  RuleIdentifier: ->
    action = ({ $$ }) ->
      @join $$

    @action @all, [
      [ @regex, /^[A-Z]/ ]
      [ @maybe_some, @regex, /^[_a-zA-Z]/ ]
    ], action

  ###
  Matches a label identifier.
  ###
  LabelIdentifier: ->
    action = ({ $$ }) ->
      @join $$

    @action @some, @regex, /^[_a-z]/, action

  ###
  Matches a string and returns a StringNode.
  ###
  String: ->
    action = ({ content }) ->
      @unescape @join content

    @action @any, [
      [ @all, [
        [ @literal, "'" ]
        [ @label, 'content', @maybe_some, @all, [
          [ @any, [
            [ @literal, '\\' ]
            [ @reject, @literal, "'" ]
          ] ]
          @advance
        ] ]
        [ @literal, "'" ]
      ] ]
      [ @all, [
        [ @literal, '"' ]
        [ @label, 'content', @maybe_some, @all, [
          [ @any, [
            [ @literal, '\\' ]
            [ @reject, @literal, '"' ]
          ] ]
          @advance
        ] ]
        [ @literal, '"' ]
      ] ]
    ], action

  ###
  Matches a character class and returns a ClassNode.
  ###
  Class: ->
    action = ({ content }) ->
      @unescape @join content

    @action @all, [
      [ @literal, '[' ]
      [ @label, 'content', @maybe_some, @all, [
        [ @any, [
          [ @literal, '\\' ]
          [ @reject, @literal, ']' ]
        ] ]
        @advance
      ] ]
      [ @literal, ']' ]
    ], action

  ###
  Matches an indent followed by two spaces.
  ###
  DOUBLE_INDENT: ->
    @action @all, [
      @INDENT
      @SPACE
      @SPACE
    ], -> '\n'

  ###
  Matches a single indent (a newline followed by two space).
  ###
  INDENT: ->
    @token @all, [
      @NEWLINE
      @SPACE
      @SPACE
    ]

  ###
  Matches a single whitespace character (newline or space).
  ###
  WHITESPACE: ->
    @any [
      @NEWLINE
      @SPACE
    ]

  ###
  Matches a single CR/LF newline.
  ###
  NEWLINE: ->
    @action @any, [
      [ @all, [
        [ @literal, '\r' ]
        [ @maybe, @literal, '\n' ]
      ] ]
      [ @literal, '\n' ]
    ], -> '\n'

  ###
  Matches a single space.
  ###
  SPACE: ->
    @token @literal, ' '

  ###
  The initial parsing expression to apply when `parse` is called.
  ###
  Start: @::Grammar