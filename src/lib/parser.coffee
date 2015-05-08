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
    constructor: (value, { @name } = {}) ->
      @named_results = {}
      switch
        when value instanceof ResultArray
          # Unbox ResultArray values but preserve named results
          @value = ( result.value for result in value.value )
          @named_results[k] = v for own k, v of value.named_results
        when value instanceof Result
          # Copy value and preserve named results
          @value = value.value
          @name  = value.name
          @named_results[k] = v for own k, v of value.named_results
        else
          @value = value

      # Object.defineProperty @, 'value',
      #   get: -> value
      #   set: -> throw new Error "Result#value is immutable"

    ###
    Determines whether or not the result is empty (value is undefined).  This is used to filter
    'meaningless' results in certain situations.
    ###
    is_empty: ->
      @value is undefined

  ###
  A ResultArray is a result whose value is an array of results.
  ###
  ResultArray: class ResultArray extends Result

    ###
    Create a new result array for the given array of results.
    ###
    constructor: (value, options = {}) ->
      super

      for result, i in @value
        @value[i] = new Result result if result instanceof ResultArray
        @named_results[result.name] = @value[i].value if result.name?

      # Object.freeze @value
      # Object.freeze @named_results

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
    @action_contexts = []
    null

  ###
  Executes the start parsing expression and returns the result, or false if that start expression
  does not match.
  ###
  parse: (input) ->
    throw new Error 'cannot parse without start expression' unless @Start

    @reset input if input?

    result = @Start()
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
  literal: (literal) ->
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
  all: (expressions) ->
    @_backtrack ->
      results = []
      for expression in expressions
        [ expression, args... ] = expression if Array.isArray expression
        return false unless result = expression.apply @, args
        results.push result unless result.is_empty()
      new @ResultArray results

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
  any: (expressions) ->
    for expression in expressions
      expression = [ expression ] unless Array.isArray expression
      return result if result = @_backtrack.apply @, expression
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
  some: (expression, args...) ->
    result = expression.apply @, args
    if result
      new @ResultArray [ result ].concat @maybe_some.apply(@, arguments).value
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
  maybe_some: (expression, args...) ->
    results = []
    while result = expression.apply @, args
      results.push result unless result.is_empty()
    new @ResultArray results

  ###
  A `some` expression will evaluate the sub-expression once. It always matches.  The result will be
  the result of the sub-expression if it matches, or a result containing null otherwise.

  ```coffee
    new Parser('hello').maybe -> @literal 'world' # Result null
    new Parser('hello').maybe -> @literal 'hello' # Result 'hello'
  ```
  ###
  maybe: (expression, args...) ->
    result = expression.apply @, args
    result or new @Result null

  ###
  A `check` expression will evaluate the sub-expression once.  It matches if the sub-expression
  matches.  No input is consumed.  The result is an empty result.

  ```coffee
    new Parser('world').check -> @literal 'hello' # fail
    new Parser('world').check -> @literal 'world' # Result
  ```
  ###
  check: (expression, args...) ->
    result = null
    @_backtrack ->
      result = expression.apply @, args
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
  reject: (expression, args...) ->
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
  action: (expression, args..., action) ->
    if result = expression.apply @, args
      new @Result action.call @parse_context, make_context result
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
  label: (name, expression, args...) ->
    if result = expression.apply @, args
      new result.constructor result.value, { name }
    else
      result

  ###
  A `token` expression matches if the sub-expression matches.  The result is an empty result.

  ```coffee
    new Parser('hello').token -> @literal 'world' # fail
    new Parser('hello').token -> @literal 'hello' # Result
  ```
  ###
  token: (expression, args...) ->
    if expression.apply @, args
      new @Result()
    else
      false

  ###
  Matches the given regular expression, returning the overall match.
  ###
  regex: (regex) ->
    return false unless match = @input.substr(@position).match regex

    @position += match[0].length
    new @Result match[0]

  ###
  Executes the given sub-expression and returns the result, and resets the position if the
  sub-expression fails.
  ###
  _backtrack: (expression, args...) ->
    origin    = @position
    @position = origin unless result = expression.apply @, args
    result

  ###
  Make an action context for a given result.
  ###
  make_context = (result) ->
    ctx = {}

    if result instanceof ResultArray
      ctx.$$ = new Result(result).value
    else
      ctx.$$ = result.value

    ctx[result.name] = result.value if result.name?
    ctx[k]           = v for own k, v of result.named_results

    ctx