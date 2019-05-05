###
A `State` is an object with three fields:

- `name: string` - A descriptive name for the state.
- `next: () -> {element: any, state: State}` - Get a single element and the next state.
- `get_context: () -> string` - Get additional descriptive context for the state.

This module exports some useful `State` creation functions.
###

###
Represents the state of a parser as progress through a string.

The elements from the state will be the characters in the string.
###
class StringState
  CONTEXT_MAX_COLUMNS = 80
  CONTEXT_MARKER      = '^'

  constructor: (@_name, @_string, @_index, @_line, @_column) ->
    @name = "#{@_name}:#{@_line}:#{@_column}"

  ###
  Get a single element and the next state.

  The element will be the character at the current index, and the next state will be a `StringState`
  at the next index in the string.
  ###
  next: ->
    return undefined if @_index is @_string.length

    element    = @_string[@_index]
    next_index = @_index + 1

    if element is '\r' or (element is '\n' and @_string[@_index - 1] isnt '\r')
      next_line   = @_line + 1
      next_column = 1
    else
      next_line   = @_line
      next_column = @_column + 1

    next_state = new @constructor @_name, @_string, next_index, next_line, next_column
    return { element, state: next_state }

  ###
  Get additional descriptive context for the state.

  This will be the current line of the input string with a marker pointed to the current column.
  ###
  get_context: ->
    from_index = @_index
    from_index-- while (c = @_string[from_index - 1]) and c not in '\r\n'

    to_index = @_index
    to_index++ while (c = @_string[to_index]) and c not in '\r\n'

    difference = CONTEXT_MAX_COLUMNS - (to_index - from_index)
    if difference < 0
      # If we exceed the maximum columns take a slice of the line proportional to the current index
      ratio       = (@_index - from_index) / (to_index - from_index)
      from_index += Math.round ratio * -difference
      to_index   -= Math.round (1 - ratio) * -difference

    marker = "#{' '.repeat @_index - from_index}^"
    return "#{@_string[from_index...to_index]}\n#{marker}"

@from_string = (string, {name = '<string>'} = {}) ->
  return new StringState name, string, 0, 1, 1
