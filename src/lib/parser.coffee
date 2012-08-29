_ = require 'underscore'

module.exports = class Parser

  ###
  Encapsulates a result from a parse function.
  ###
  Result: class Result

    ###
    Create a new parse result with the given value.
    ###
    constructor: (@value) ->

    ###
    Determines whether or not the result is empty.
    ###
    is_empty: ->
      @value is undefined

  ###
  Encapsulates a parser context, providing useful helpers.
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
    Proxy of _.compact.
    ###
    compact: (array) ->
      _.compact array

    ###
    Unescapes a string.
    ###
    unescape: (string) ->
      string.replace /\\(.)/, '$1'

  ###
  Constructs a parser, optionally with some parse expression to mix in.
  ###
  constructor: (options = {}) ->
    @options = _.extend {}, options
    @_reset()

  ###
  Executes the start parsing expression on the given input and returns the result.
  ###
  parse: (@input) ->
    throw new Error 'cannot parse without start expression' unless @Start

    @_reset()
    if result = @Start()
      return result if @position == @input.length
    return false

  ###
  Matches the given sub-expression and returns an empty result.
  ###
  token: (expression, args...) ->
    if expression.apply @, args
      new @Result()
    else
      false

  ###
  Matches the given sub-expression and, if successful, executes the given action.
  ###
  action: (expression, args..., action) ->
    @action_contexts.push {}
    if result = expression.apply @, args
      new @Result action.call @parse_context, _.extend @action_contexts.pop(), $$: result.value
    else
      @action_contexts.pop()
      result

  ###
  Matches the given sub-expression and stores the result as a parameter.
  ###
  label: (name, expression, args...) ->
    if result = expression.apply @, args
      @_add_parameter name, result.value
    result

  ###
  Matches the given sub-expression without consuming any input.
  ###
  check: (expression, args...) ->
    result = null
    @_backtrack ->
      result = expression.apply @, args
      false
    if result then new @Result() else false

  ###
  Matches the given sub-expression if it matches without consuming any input.
  ###
  reject: (expression, args...) ->
    if @check.apply @, arguments then false else new @Result()

  ###
  Matches all the given sub-expressions in order and returns an array of the results.
  ###
  all: (expressions) ->
    @_backtrack ->
      results = []
      for expression in expressions
        [ expression, args... ] = expression if Array.isArray expression
        return false unless result = expression.apply @, args
        results.push result.value unless result.is_empty()
      new @Result results

  ###
  Matches one of the given sub-expression and returns the result of the first successful match.
  ###
  any: (expressions) ->
    for expression in expressions
      expression = [ expression ] unless Array.isArray expression
      return result if result = @_backtrack.apply @, expression
    false

  ###
  Matches the given sub-expression at least once and as many times as possible and returns an array
  of the results.
  ###
  some: (expression, args...) ->
    result = expression.apply @, args
    if result
      new Result [ result.value ].concat @maybe_some.apply(@, arguments).value
    else
      false

  ###
  Matches the given sub-expression as many times as possible and returns an array of the results.
  ###
  maybe_some: (expression, args...) ->
    results = []
    while result = expression.apply @, args
      results.push result.value unless result.is_empty()
    new @Result results

  ###
  Attempts to match the given sub-expression, returning the sub-expression's result is so or a null
  result otherwise.
  ###
  maybe: (expression, args...) ->
    result = expression.apply @, args
    result or new @Result null

  ###
  Matches the given regular expression, returning the overall match.
  ###
  regex: (regex) ->
    return false unless match = @input.substr(@position).match regex

    @position += match[0].length
    new @Result match[0]

  ###
  Matches the given literal string.
  ###
  literal: (literal) ->
    return false unless @input.substr(@position, literal.length) == literal

    @position += literal.length
    new @Result literal

  ###
  Matches a single character.
  ###
  advance: ->
    if @input[@position]?
      new Result @input[@position++]
    else
      false

  ###
  Always matches nothing.
  ###
  pass: ->
    new Result()

  ###
  Restores the parser to a 'clean' state.
  ###
  _reset: ->
    @position        = 0
    @parse_context   = new @Context
    @action_contexts = []
    null

  ###
  Executes the given sub-expression and returns the result, and resets the position if the
  sub-expression fails.
  ###
  _backtrack: (expression, args...) ->
    origin    = @position
    @position = origin unless result = expression.apply @, args
    result

  ###
  Adds the given parameter to the current action context.
  ###
  _add_parameter: (name, result) ->
    return if @action_contexts.length is 0
    @action_contexts[-1..][0][name] = result