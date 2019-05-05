(function() {
  /*
  A parse expression is a function that transforms a `State` into a `Result`.
  */
  var pass;

  /*
  The `pass` expression will always succeed.

  The state is unchanged and the value is `null`.
  */
  this.pass = pass = function(state) {
    return succeed(state, null);
  };

  /*
  The `advance` expression will succeed if there is any input left.

  The state is advanced by one position and the value is a single character from the input.
  */
  this.advance = function(state) {
    var char;
    char = state.peek(1);
    if (char != null) {
      return succeed(state.advance(1), char);
    } else {
      return fail_unexpected(state, '<end of input>');
    }
  };

  /*
  The `literal` expression will succeed if the given literal is present at the current input position.

  The state is advanced by the length of the literal and the value is the literal.
  */
  this.sequence = function(sequence, state) {
    if (literal === state.peek(literal.length)) {
      return succeed(state.advance(literal.length), literal);
    } else {
      return fail_expected(state, literal);
    }
  };

  this.all = function(expressions, state) {
    var _state, expression, i, len, result, results;
    _state = state;
    results = [];
    for (i = 0, len = expressions.length; i < len; i++) {
      expression = expressions[i];
      result = expression(_state);
      if (result instanceof Failure) {
        return result;
      }
      results.push(result.value);
      _state = result.state;
    }
    return succeed(_state, results);
  };

  this.any = function(expressions, state) {
    var errors, expression, i, len, result;
    errors = [];
    for (i = 0, len = expressions.length; i < len; i++) {
      expression = expressions[i];
      result = expression(state);
      if (result instanceof Success) {
        return result;
      }
      errors.push(result.error);
    }
    return fail_any(state, errors);
  };

}).call(this);
