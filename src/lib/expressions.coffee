###
An `Expression` is a function that takes a `State` and produces a `Result`.

A `Result` is one of:

- `Success = {state: State, value: any}` - An `Expression` that succeeds against a given state
  should return a value and a terminal `State`.
- `Failure = {state: State, reason: string}` - An `Expression` that fails against a given state
  should return the state at which the failure occurred and a descriptive reason for the failure.
###

class Result

class Success extends Result
  constructor: (@state, @value) ->

class Failure extends Result
  constructor: (@state, @reason) ->

###
The `pass` expression will always succeed.

The state is unchanged and the value is `undefined`.
###
@pass = (state) ->
  new Success state, undefined

###
The `next` expression will succeed if there is a next state.

The state is the next state, and the value is the element.
###
@next = (state) ->
  next = state.next()
  if next?
    new Success next.state, next.element
  else
    new Failure state, 'No more elements'

###
The `element` expression will succeed if the state yields the given element.

The state is the next state, and the value is the element.
###
@element = (element) -> (state) ->
  next = state.next()
  if next?.element is element
    new Success next.state, next.element
  else
    new Failure state, "expected #{element}"

###
The `sequence` expression will succeed if a sequence of expressions all succeed.

The state is the state of the result of the final expression, and the value is an array of all the
expression result values.
###
@sequence = (sequence) -> (state) ->
  value  = []

  _state = state
  for expression in sequence
    result = expression _state
    return result if result instanceof Failure

    _state = result.state
    value.push result.value

  new Success _state, value

###
The `alternatives` expression will succeed if any expression in a list of alternatives succeeds.

The result is the result of the successful expression.
###
@alternatives = (alternatives) -> (state) ->
  failures = []

  for expression in alternatives
    result = expression state
    return result if result instanceof Success

    failures.push result

  new Failure state, "failed to any alternative due to:\n#{failures.join '\n'}"

###
The `loop` expression will evaluate the given expression until it fails, then succeed.

The result state is the state of the result of the final successful evaluation, the result value is
an array of all the values of successful evaluations.
###
@loop = (expression) -> (state) ->
  value = []

  _state = state
  loop
    result = expression _state
    break if result instanceof Failure

    _state = result.state
    value.push result.value

  new Success _state, value

###
The `lookahead` expression will evaluate the given expression and return the original state.

The result state is the input state, and the result value is the value of a successful evaluation.
###
@lookahead = (expression) -> (state) ->
  result = expression state
  return result if result instanceof Failure

  new Success state, result.value
