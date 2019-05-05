(function() {
  'use strict';
  var Parser, util,
    slice = [].slice,
    hasProp = {}.hasOwnProperty;

  util = require('./util');

  module.exports = Parser = (function() {
    var Context, Failure, Result;

    class Parser {
      /*
      Constructs a parser.
      */
      constructor(input) {
        this.reset(input);
      }

      /*
      Restores the parser to a 'clean' state.
      */
      reset(input) {
        if (input != null) {
          this.input = String(input);
        }
        this.position = 0;
        this.parse_context = new this.Context;
        return null;
      }

      /*
      Executes the start parsing expression and returns the result, or false if that start expression
      does not match.
      */
      parse(input) {
        var result;
        if (!this.Start) {
          throw new Error('cannot parse without start expression');
        }
        if (input != null) {
          this.reset(input);
        }
        result = this.Start({});
        if (result && this.position === this.input.length) {
          return result.value;
        } else {
          return false;
        }
      }

      /*
      A `pass` expression will always match and return an empty result.  It consumes no input.  Parser
      equivalent of `true`.

      ```coffee
        new Parser('').pass() # Result
      ```
      */
      pass() {
        return new Result();
      }

      /*
      An `advance` expression will consume a single character of input and return a result containing
      the consumed character.  The match only fails if the input is empty.

      ```coffee
      new Parser('').advance()  # fail
      new Parser('.').advance() # Result '.'
      ```
      */
      advance() {
        if (this.input[this.position] != null) {
          return new Result(this.input[this.position++]);
        } else {
          return false;
        }
      }

      /*
      A `literal` expression will match if the string is present at the beginning of the input. The
      result contains the parameter.

      ```coffee
        new Parser('world').literal 'hello' # fail
        new Parser('world').literal 'world' # Result 'world'
      ```
      */
      literal(context, literal) {
        if (this.input.substr(this.position, literal.length) !== literal) {
          return false;
        }
        this.position += literal.length;
        return new this.Result(literal);
      }

      /*
      An `all` expression will match if all sub-expressions match.  The result contains an array of
      sub-expression results.

      ```coffee
      new Parser('abc').all ( ( -> @literal c ) for c in 'abcd' ) # fail
      new Parser('abc').all ( ( -> @literal c ) for c in 'abc'  ) # Result [ 'a', 'b', 'c' ]
      ```
      */
      all(context, expressions) {
        return this._backtrack(context, function(context) {
          var args, expression, i, len, result, results;
          results = [];
          for (i = 0, len = expressions.length; i < len; i++) {
            expression = expressions[i];
            if (Array.isArray(expression)) {
              [expression, ...args] = expression;
            }
            if (!(result = expression.call(this, context, ...args))) {
              return false;
            }
            if (!result.is_empty()) {
              results.push(result.value);
            }
          }
          return new this.Result(results);
        });
      }

      /*
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
      */
      any(context, expressions) {
        var expression, i, len, result;
        for (i = 0, len = expressions.length; i < len; i++) {
          expression = expressions[i];
          if (!Array.isArray(expression)) {
            expression = [expression];
          }
          if (result = this._backtrack.call(this, context, ...expression)) {
            return result;
          }
        }
        return false;
      }

      /*
      A `some` expression will evaluate the sub-expression until the sub-expression fails.  It matches
      if the sub-expression matches at least once, and fails otherwise.  The result contains an array of
      the results of the successful sub-expression matches.

      ```coffee
      new Parser('aaa').some -> @literal 'b' # fail
      new Parser('aaa').some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
      ```
      */
      some(context, expression, ...args) {
        var result;
        result = expression.call(this, context, ...args);
        if (result) {
          return new this.Result([result.value].concat(this.maybe_some(...arguments).value));
        } else {
          return false;
        }
      }

      /*
      A `maybe_some` expression will evaluate the sub-expression until the sub-expression fails.  It
      always matches. The result contains an array of the results of the successful sub-expression
      matches.

      ```coffee
        new Parser('aaa').maybe_some -> @literal 'b' # Result []
        new Parser('aaa').maybe_some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
      ```
      */
      maybe_some(context, expression, ...args) {
        var result, results;
        results = [];
        while (result = expression.call(this, context, ...args)) {
          if (!result.is_empty()) {
            results.push(result.value);
          }
        }
        return new this.Result(results);
      }

      /*
      A `some` expression will evaluate the sub-expression once. It always matches.  The result will be
      the result of the sub-expression if it matches, or a result containing null otherwise.

      ```coffee
      new Parser('hello').maybe -> @literal 'world' # Result null
      new Parser('hello').maybe -> @literal 'hello' # Result 'hello'
      ```
      */
      maybe(context, expression, ...args) {
        var result;
        result = expression.call(this, context, ...args);
        return result || new this.Result(null);
      }

      /*
      A `check` expression will evaluate the sub-expression once.  It matches if the sub-expression
      matches.  No input is consumed.  The result is an empty result.

      ```coffee
      new Parser('world').check -> @literal 'hello' # fail
      new Parser('world').check -> @literal 'world' # Result
      ```
      */
      check(context, expression, ...args) {
        var result;
        result = null;
        this._backtrack(context, function() {
          result = expression.call(this, context, ...args);
          return false;
        });
        if (result) {
          return new this.Result();
        } else {
          return false;
        }
      }

      /*
      A `reject` expression will evaluate the sub-expression once.  It matches if the sub-expression
      does not match.  No input is consumed.  The result is an empty result.

      ```coffee
      new Parser('world').check -> @literal 'world' # fail
      new Parser('world').check -> @literal 'hello' # Result
      ```
      */
      reject(context, expression, ...args) {
        if (this.check.apply(this, arguments)) {
          return false;
        } else {
          return new this.Result();
        }
      }

      /*
      An `action` expression matches if the sub-expression matches.  If it matches the action is called
      with the result of the sub-expression.  The result is the return value of the action.

      ```coffee
      action = ({ result }) -> (String.fromCharCode c.charCodeAt(0) + 3 for c in result).join ''
      new Parser('abc').action ( -> @literal 'def' ), action # fail
      new Parser('abc').action ( -> @literal 'abc' ), action # Result 'def'
      ```
      */
      action(context, expression, ...args) {
        var action, action_context, i, k, ref, result, sub_context, v;
        ref = args, args = 2 <= ref.length ? slice.call(ref, 0, i = ref.length - 1) : (i = 0, []), action = ref[i++];
        sub_context = {};
        if (result = expression.call(this, sub_context, ...args)) {
          for (k in sub_context) {
            if (!hasProp.call(sub_context, k)) continue;
            v = sub_context[k];
            // Merge the sub-expression results into the enclosing context
            context[k] = v;
          }
          // The context for this action excludes the enclosing context
          action_context = util.merge({}, sub_context);
          action_context.$$ = result.value;
          return new this.Result(action.call(this.parse_context, action_context));
        } else {
          return result;
        }
      }

      /*
      A `label` expression matches if the sub-expression matches, and the result is the result of the
      sub-expression.  If it matches, the named result is stored on the current action context.

      ```coffee
        new Parser('abc').label 'match', -> @literal 'def' # fail
        new Parser('abc').label 'match', -> @literal 'abc' # Result 'abc'
      ```
      */
      label(context, name, expression, ...args) {
        var result;
        if (result = expression.call(this, context, ...args)) {
          context[name] = result.value;
        }
        return result;
      }

      /*
      A `token` expression matches if the sub-expression matches.  The result is an empty result.

      ```coffee
      new Parser('hello').token -> @literal 'world' # fail
      new Parser('hello').token -> @literal 'hello' # Result
      ```
      */
      token(context, expression, ...args) {
        if (expression.call(this, context, ...args)) {
          return new this.Result();
        } else {
          return false;
        }
      }

      /*
      Matches the given regular expression, returning the overall match.
      */
      regex(context, regex) {
        var match;
        if (!(match = this.input.substr(this.position).match(regex))) {
          return false;
        }
        this.position += match[0].length;
        return new this.Result(match[0]);
      }

      /*
      Executes the given sub-expression and returns the result, and resets the position if the
      sub-expression fails.
      */
      _backtrack(context, expression, ...args) {
        var k, origin, result, sub_context, v;
        origin = this.position;
        sub_context = context != null ? util.merge({}, context) : context;
        if (result = expression.call(this, sub_context, ...args)) {
          for (k in sub_context) {
            if (!hasProp.call(sub_context, k)) continue;
            v = sub_context[k];
            context[k] = v;
          }
        } else {
          this.position = origin;
        }
        return result;
      }

    };

    /*
    A result is a wrapper around a value, indicating that the value came from a successful expression
    match.  A result without a value is an empty result, but still indicates a successful expression
    match.
    */
    Parser.prototype.Result = Result = class Result {
      /*
      Create a new parse result with the given value.
      */
      constructor(value) {
        this.value = value;
        Object.freeze(this);
      }

      /*
      Determines whether or not the result is empty (value is undefined).  This is used to filter
      'meaningless' results in certain situations.
      */
      is_empty() {
        return this.value === void 0;
      }

    };

    /*
    A failure indicates that parsing failed.
    */
    Parser.prototype.Failure = Failure = class Failure {
      /*
      Create a new failure with a given reason.
      */
      constructor(reason) {
        this.reason = reason;
      }

    };

    /*
    Encapsulates a parser context, providing useful helpers for manipulating results.
    */
    Parser.prototype.Context = Context = class Context {
      /*
      Extract the element at the given index from all elements of the given array.
      */
      extract(array, index) {
        var element, i, len, results1;
        results1 = [];
        for (i = 0, len = array.length; i < len; i++) {
          element = array[i];
          results1.push(element[index]);
        }
        return results1;
      }

      /*
      Recursively joins an array into a single string.
      */
      join(array) {
        var member;
        if (array == null) {
          return '';
        }
        if (typeof array === 'string') {
          return array;
        }
        return ((function() {
          var i, len, results1;
          results1 = [];
          for (i = 0, len = array.length; i < len; i++) {
            member = array[i];
            results1.push(this.join(member));
          }
          return results1;
        }).call(this)).join('');
      }

      /*
      Filter falsey values from array.
      */
      compact(array) {
        var i, len, results1, v;
        results1 = [];
        for (i = 0, len = array.length; i < len; i++) {
          v = array[i];
          if (v) {
            results1.push(v);
          }
        }
        return results1;
      }

      /*
      Unescapes a string.
      */
      unescape(string) {
        return string.replace('\\n', '\n').replace('\\r', '\r').replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\');
      }

    };

    return Parser;

  })();

}).call(this);
