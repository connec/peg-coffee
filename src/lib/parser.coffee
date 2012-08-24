module.exports = class Parser

  ###
  The initial parsing expression to apply when `parse` is called.
  ###
  Start: null

  ###
  Constructs a parser, optionally with some parse expression to mix in.
  ###
  constructor: (expressions = {}) ->
    @reset()

    for name, expression of expressions
      @Start ?= expression
      @[name] = expression

  ###
  Executes the start parsing expression on the given input and returns the result.
  ###
  parse: (@input) ->
    @reset()
    if result = @Start()
      return result if @position == @input.length
    return false

  ###
  Restores the parser to a 'clean' state.
  ###
  reset: ->
    @position = 0

  # Parse functions

  ###
  Executes the given sub-expression and returns the result, and resets the position if the
  sub-expression fails.
  ###
  backtrack: (expression, args...) ->
    origin    = @position
    @position = origin unless result = expression.apply @, args
    return result

  ###
  Matches the given sub-expression without consuming any input.
  ###
  check: (expression, args...) ->
    result = null
    @backtrack ->
      result = expression.apply @, args
      false
    if result then { value: null } else false

  ###
  Matches the given sub-expression if it matches without consuming any input.
  ###
  reject: (expression, args...) ->
    if @check.apply @, arguments then false else { value: null }

  ###
  Matches all the given sub-expressions in order and returns an array of the results.
  ###
  all: (expressions) ->
    results = []
    for expression in expressions
      expression = [ expression ] unless Array.isArray expression
      return false unless result = @backtrack.apply @, expression
      results.push result.value
    { value: results }

  ###
  Matches one of the given sub-expression and returns the result of the first successful match.
  ###
  any: (expressions) ->
    for expression in expressions
      expression = [ expression ] unless Array.isArray expression
      return result if result = @backtrack.apply @, expression
    return false

  ###
  Matches the given sub-expression at least once and as many times as possible and returns an array
  of the results.
  ###
  some: (expression, args...) ->
    result = @maybe_some.apply @, arguments
    if result.value.length > 0 then result else false

  ###
  Matches the given sub-expression as many times as possible and returns an array of the results.
  ###
  maybe_some: (expression, args...) ->
    value: (result.value while result = expression.apply @, args)

  ###
  Attempts to match the given sub-expression, returning the sub-expression's result is so or a null
  result otherwise.
  ###
  maybe: (expression, args...) ->
    result = expression.apply @, args
    result or { value: null }

  ###
  Matches the given regular expression, returning the overall match.
  ###
  regex: (regex) ->
    return false unless match = @input.substr(@position).match regex
    @position += match[0].length
    return value: match[0]

  ###
  Matches the given literal string.
  ###
  literal: (literal) ->
    return false unless @input.substr(@position, literal.length) == literal
    @position += literal.length
    return value: literal