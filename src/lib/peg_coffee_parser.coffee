Parser = require './parser'

module.exports = class PegCoffeeParser extends Parser

  ###
  Matches an entire grammar.
  ###
  Grammar: ->
    action = ({ head, tail }) ->
      parser         = class extends Parser
      parser::Start  = head.content
      parser::[name] = content for { name, content } in [ head ].concat @extract tail, 2
      parser

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
    action = ({ comments, name, content }) ->
      name:     name
      content:  content
      comments: @compact comments

    @action @all, [
      [ @label, 'comments', @maybe_some, @any, [
        @Comment
        @EMPTY_LINE
      ] ]
      [ @label, 'name', @RuleIdentifier ]
      [ @literal, ':' ]
      @INDENT
      [ @label, 'content', @RuleContent ]
    ], action

  ###
  Matches the content of a rule.
  ###
  RuleContent: ->
    action = ({ head, tail, action }) ->
      if action? and tail.length > 0
        extract = @extract
        -> @action @any, [ head ].concat(extract tail, 2), action
      else if tail.length > 0
        extract = @extract
        -> @any [ head ].concat extract tail, 2
      else if action?
        -> @action head, action
      else
        head

    @action @all, [
      [ @label, 'head', @RuleLine ]
      [ @label, 'tail', @maybe_some, @all, [
        @NEWLINE
        [ @literal, '/' ]
        @SPACE
        @RuleLine
      ] ]
      [ @maybe, @all, [
        @INDENT
        [ @label, 'action', @Action ]
      ] ]
    ], action

  ###
  Matches an expression possibly followed by some code.
  ###
  RuleLine: ->
    action = ({ expr, action }) ->
      if action
        -> @action expr, action
      else
        expr

    @action @all, [
      [ @label, 'expr', @Expression ]
      [ @maybe, @all, [
        [ @some, @SPACE ]
        [ @label, 'action', @Action ]
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
        extract = @extract
        -> @any [ head ].concat extract tail, 3

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
        extract = @extract
        -> @all [ head ].concat extract tail, 1

    @action @all, [
      [ @label, 'head', @Label ]
      [ @label, 'tail', @maybe_some, @all, [
        [ @some, @SPACE ]
        @Label
      ] ]
    ], action

  ###
  Matches a labelled expression.
  ###
  Label: ->
    action = ({ label, expr }) ->
      -> @label label, expr

    @any [
      [ @action, @all, [
        [ @label, 'label', @LabelIdentifier ]
        [ @literal, ':' ]
        [ @label, 'expr', @Prefix ]
      ], action ]
      @Prefix
    ]

  ###
  Matches a prefixed expression.
  ###
  Prefix: ->
    action = ({ prefix, expr }) ->
      switch prefix
        when '&' then -> @check expr
        when '!' then -> @reject expr

    @any [
      [ @action, @all, [
        [ @label, 'prefix', @regex, /^[&!]/ ]
        [ @label, 'expr', @Suffix ]
      ], action ]
      @Suffix
    ]

  ###
  Matches a suffixed operator.
  ###
  Suffix: ->
    action = ({ suffix, expr }) ->
      switch suffix
        when '?' then -> @maybe expr
        when '*' then -> @maybe_some expr
        when '+' then -> @some expr

    @any [
      [ @action, @all, [
        [ @label, 'expr', @Primary ]
        [ @label, 'suffix', @regex, /^[?*+]/ ]
      ], action ]
      @Primary
    ]

  ###
  Matches a primary expression.
  ###
  Primary: ->
    action_sub_expression = ({ sub }) ->
      sub

    action_rule = ({ $$ }) ->
      -> @[$$]()

    action_literal = ({ $$ }) ->
      $$

    action_class = ({ $$ }) ->
      $$

    action_advance = ->
      -> @advance()

    action_pass = ->
      -> @pass()

    @any [
      [ @action, @all, [
        [ @literal, '(' ]
        [ @label, 'sub', @SubExpression ]
        [ @literal, ')' ]
      ], action_sub_expression ]
      [ @action, @RuleIdentifier, action_rule     ]
      [ @action, @Literal,        action_literal  ]
      [ @action, @Class,          action_class    ]
      [ @action, @literal, '.',   action_advance  ]
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
  Action: ->
    action_block = ({ $$ }) ->
      $code = @join($$[2..]).trim().replace /^    /gm, ''
      (context) ->
        eval "var #{k} = v" for own k, v of context
        eval require('coffee-script').compile $code, bare: true

    action_inline = ({ $$ }) ->
      $code = @join($$[1..]).trim().replace /^    /gm, ''
      (context) ->
        eval "var #{k} = v" for own k, v of context
        eval require('coffee-script').compile $code, bare: true

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
  Matches a single line comment.
  ###
  Comment: ->
    action = ({ content }) ->
      @join(content).trim()

    @action @all, [
      [ @literal, '#' ]
      [ @label, 'content', @maybe_some, @all, [
        [ @reject, @NEWLINE ]
        @advance
      ] ]
      @NEWLINE
    ], action

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
  Literal: ->
    p = @
    action = ({ content }) ->
      literal = @unescape @join content
      -> @literal literal

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
      klass = @unescape @join content
      -> @regex /// ^ [#{klass}] ///

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
  Matches whitespace followed eventually by a newline.
  ###
  EMPTY_LINE: ->
    @token @all, [
      [ @maybe_some, @SPACE ]
      @NEWLINE
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