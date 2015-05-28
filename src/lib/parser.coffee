'use strict'

module.exports = class Parser

  ###
  A result is a wrapper around a value, indicating that the value came from a successful expression
  match.  A result without a value is an empty result, but still indicates a successful expression
  match.
  ###
  Result: class Result

    ###
    Create a new parse result with the given value.
    ###
    constructor: (@value) ->
      Object.freeze @

    ###
    Determines whether or not the result is empty (value is undefined).  This is used to filter
    'meaningless' results in certain situations.
    ###
    is_empty: ->
      @value is undefined

  ###
  A failure indicates that parsing failed.
  ###
  Failure: class Failure

    ###
    Create a new failure with a given reason.
    ###
    constructor: (@reason) ->

  ###
  Encapsulates a parser context, providing useful helpers for manipulating results.
  ###
  Context: class Context

    ###
    Extract the element at the given index from all elements of the given array.
    ###
    extract: (array, index) ->
      element[index] for element in array

    ###
    Recursively joins an array into a single string.
    ###
    join: (array) ->
      return '' unless array?
      return array if typeof array is 'string'
      (@join member for member in array).join ''

    ###
    Filter falsey values from array.
    ###
    compact: (array) ->
      (v for v in array when v)

    ###
    Unescapes a string.
    ###
    unescape: (string) ->
      string
        .replace '\\n',  '\n'
        .replace '\\r',  '\r'
        .replace "\\'",  "'"
        .replace '\\"',  '"'
        .replace '\\\\', '\\'

  ###
  Constructs a parser.
  ###
  constructor: (input) ->
    @reset input

  ###
  Restores the parser to a 'clean' state.
  ###
  reset: (input) ->
    @input           = String input if input?
    @position        = 0
    @parse_context   = new @Context
    null

  ###
  Executes the start parsing expression and returns the result, or false if that start expression
  does not match.
  ###
  parse: (input) ->
    throw new Error 'cannot parse without start expression' unless @Start

    @reset input if input?

    result = @Start {}
    if result and @position == @input.length
      result.value
    else
      false

  ###
  A `pass` expression will always match and return an empty result.  It consumes no input.  Parser
  equivalent of `true`.

  ```coffee
    new Parser('').pass() # Result
  ```
  ###
  pass: ->
    new Result()

  ###
  An `advance` expression will consume a single character of input and return a result containing
  the consumed character.  The match only fails if the input is empty.

  ```coffee
    new Parser('').advance()  # fail
    new Parser('.').advance() # Result '.'
  ```
  ###
  advance: ->
    if @input[@position]?
      new Result @input[@position++]
    else
      false

  ###
  A `literal` expression will match if the string is present at the beginning of the input. The
  result contains the parameter.

  ```coffee
    new Parser('world').literal 'hello' # fail
    new Parser('world').literal 'world' # Result 'world'
  ```
  ###
  literal: (context, literal) ->
    return false unless @input.substr(@position, literal.length) == literal

    @position += literal.length
    new @Result literal

  ###
  An `all` expression will match if all sub-expressions match.  The result contains an array of
  sub-expression results.

  ```coffee
    new Parser('abc').all ( ( -> @literal c ) for c in 'abcd' ) # fail
    new Parser('abc').all ( ( -> @literal c ) for c in 'abc'  ) # Result [ 'a', 'b', 'c' ]
  ```
  ###
  all: (context, expressions) ->
    @_backtrack context, (context) ->
      results = []
      for expression in expressions
        [ expression, args... ] = expression if Array.isArray expression
        return false unless result = expression.call @, context, args...
        results.push result.value unless result.is_empty()
      new @Result results

  ###
  An `any` expression will match if any sub-expression matches.  The result is the result of the
  first matching expression.  Sub-expressions are evaluated in order, and expressions after the
  first matching expression are not evaluated.

  ```coffee
    new Parser('bar').any [
      -> @literal 'foo'
      -> @literal 'baz'
    ]                       # fail
    new Parser('bar').any [
      -> @literal 'foo'
      -> @literal 'bar'
    ]                       # Result 'bar'
  ```
  ###
  any: (context, expressions) ->
    for expression in expressions
      expression = [ expression ] unless Array.isArray expression
      return result if result = @_backtrack.call @, context, expression...
    false

  ###
  A `some` expression will evaluate the sub-expression until the sub-expression fails.  It matches
  if the sub-expression matches at least once, and fails otherwise.  The result contains an array of
  the results of the successful sub-expression matches.

  ```coffee
    new Parser('aaa').some -> @literal 'b' # fail
    new Parser('aaa').some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
  ```
  ###
  some: (context, expression, args...) ->
    result = expression.call @, context, args...
    if result
      new @Result [ result.value ].concat @maybe_some(arguments...).value
    else
      false

  ###
  A `maybe_some` expression will evaluate the sub-expression until the sub-expression fails.  It
  always matches. The result contains an array of the results of the successful sub-expression
  matches.

  ```coffee
    new Parser('aaa').maybe_some -> @literal 'b' # Result []
    new Parser('aaa').maybe_some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
  ```
  ###
  maybe_some: (context, expression, args...) ->
    results = []
    while result = expression.call @, context, args...
      results.push result.value unless result.is_empty()
    new @Result results

  ###
  A `some` expression will evaluate the sub-expression once. It always matches.  The result will be
  the result of the sub-expression if it matches, or a result containing null otherwise.

  ```coffee
    new Parser('hello').maybe -> @literal 'world' # Result null
    new Parser('hello').maybe -> @literal 'hello' # Result 'hello'
  ```
  ###
  maybe: (context, expression, args...) ->
    result = expression.call @, context, args...
    result or new @Result null

  ###
  A `check` expression will evaluate the sub-expression once.  It matches if the sub-expression
  matches.  No input is consumed.  The result is an empty result.

  ```coffee
    new Parser('world').check -> @literal 'hello' # fail
    new Parser('world').check -> @literal 'world' # Result
  ```
  ###
  check: (context, expression, args...) ->
    result = null
    @_backtrack context, ->
      result = expression.call @, context, args...
      false
    if result then new @Result() else false

  ###
  A `reject` expression will evaluate the sub-expression once.  It matches if the sub-expression
  does not match.  No input is consumed.  The result is an empty result.

  ```coffee
    new Parser('world').check -> @literal 'world' # fail
    new Parser('world').check -> @literal 'hello' # Result
  ```
  ###
  reject: (context, expression, args...) ->
    if @check.apply @, arguments then false else new @Result()

  ###
  An `action` expression matches if the sub-expression matches.  If it matches the action is called
  with the result of the sub-expression.  The result is the return value of the action.

  ```coffee
    action = ({ result }) -> (String.fromCharCode c.charCodeAt(0) + 3 for c in result).join ''
    new Parser('abc').action ( -> @literal 'def' ), action # fail
    new Parser('abc').action ( -> @literal 'abc' ), action # Result 'def'
  ```
  ###
  action: (context, expression, args..., action) ->
    sub_context = {}
    if result = expression.call @, sub_context, args...
      # Merge the sub-expression results into the enclosing context
      context[k]        = v for own k, v of sub_context

      # The context for this action excludes the enclosing context
      action_context    = Object.create sub_context
      action_context.$$ = result.value
      new @Result action.call @parse_context, action_context
    else
      result

  ###
  A `label` expression matches if the sub-expression matches, and the result is the result of the
  sub-expression.  If it matches, the named result is stored on the current action context.

  ```coffee
    new Parser('abc').label 'match', -> @literal 'def' # fail
    new Parser('abc').label 'match', -> @literal 'abc' # Result 'abc'
  ```
  ###
  label: (context, name, expression, args...) ->
    if result = expression.call @, context, args...
      context[name] = result.value
    result

  ###
  A `token` expression matches if the sub-expression matches.  The result is an empty result.

  ```coffee
    new Parser('hello').token -> @literal 'world' # fail
    new Parser('hello').token -> @literal 'hello' # Result
  ```
  ###
  token: (context, expression, args...) ->
    if expression.call @, context, args...
      new @Result()
    else
      false

  ###
  Matches the given regular expression, returning the overall match.
  ###
  regex: (context, regex) ->
    return false unless match = @input.substr(@position).match regex

    @position += match[0].length
    new @Result match[0]

  ###
  Executes the given sub-expression and returns the result, and resets the position if the
  sub-expression fails.
  ###
  _backtrack: (context, expression, args...) ->
    origin      = @position
    sub_context = if context? then Object.create context else context

    if result = expression.call @, sub_context, args...
      context[k] = v for own k, v of sub_context
    else
      @position = origin

    result