(function() {
  /*
  A `State` is an object with three fields:

  - `name: string` - A descriptive name for the state.
  - `next: () -> {element: any, state: State}` - Get a single element and the next state.
  - `get_context: () -> string` - Get additional descriptive context for the state.

  This module exports some useful `state` creation functions.
  */
  /*
  Represents the state of a parser as progress through a string.

  The elements from the state will be the characters in the string.
  */
  var StringState,
    indexOf = [].indexOf;

  StringState = (function() {
    var CONTEXT_MARKER, CONTEXT_MAX_COLUMNS;

    class StringState {
      constructor(_name, _string, _index, _line, _column) {
        this._name = _name;
        this._string = _string;
        this._index = _index;
        this._line = _line;
        this._column = _column;
        this.name = `${this._name}:${this._line}:${this._column}`;
      }

      /*
      Get a single element and the next state.

      The element will be the character at the current index, and the next state will be a `StringState`
      at the next index in the string.
      */
      next() {
        var element, next_column, next_index, next_line, next_state;
        if (this._index === this._string.length) {
          return void 0;
        }
        element = this._string[this._index];
        next_index = this._index + 1;
        if (element === '\r' || (element === '\n' && this._string[this._index - 1] !== '\r')) {
          next_line = this._line + 1;
          next_column = 1;
        } else {
          next_line = this._line;
          next_column = this._column + 1;
        }
        next_state = new this.constructor(this._name, this._string, next_index, next_line, next_column);
        return {
          element,
          state: next_state
        };
      }

      /*
      Get additional descriptive context for the state.

      This will be the current line of the input string with a marker pointed to the current column.
      */
      get_context() {
        var difference, from_index, marker, ratio, ref, ref1, to_index;
        from_index = this._index;
        while (ref = this._string[from_index - 1], indexOf.call('\r\n', ref) < 0) {
          from_index--;
        }
        to_index = this._index;
        while (ref1 = this._string[to_index], indexOf.call('\r\n', ref1) < 0) {
          to_index++;
        }
        difference = CONTEXT_MAX_COLUMNS - (to_index - from_index);
        if (difference < 0) {
          // If we exceed the maximum columns take a slice of the line proportional to the current index
          ratio = (this._index - from_index) / (to_index - from_index);
          from_index += Math.round(ratio * difference);
          to_index -= Math.round((1 - ratio) * difference);
        }
        marker = `${' '.repeat(this._index - from_index - 1)}^`;
        return `${this._string.slice(from_index, to_index)}\n${marker}`;
      }

    };

    CONTEXT_MAX_COLUMNS = 80;

    CONTEXT_MARKER = '^';

    return StringState;

  })();

}).call(this);
