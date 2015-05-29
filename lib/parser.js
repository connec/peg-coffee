(function() {
  'use strict';
  var Parser, util,
    slice = [].slice,
    hasProp = {}.hasOwnProperty;

  util = require('util');

  module.exports = Parser = (function() {

    /*
    A result is a wrapper around a value, indicating that the value came from a successful expression
    match.  A result without a value is an empty result, but still indicates a successful expression
    match.
     */
    var Context, Failure, Result;

    Parser.prototype.Result = Result = (function() {

      /*
      Create a new parse result with the given value.
       */
      function Result(value) {
        this.value = value;
        Object.freeze(this);
      }


      /*
      Determines whether or not the result is empty (value is undefined).  This is used to filter
      'meaningless' results in certain situations.
       */

      Result.prototype.is_empty = function() {
        return this.value === void 0;
      };

      return Result;

    })();


    /*
    A failure indicates that parsing failed.
     */

    Parser.prototype.Failure = Failure = (function() {

      /*
      Create a new failure with a given reason.
       */
      function Failure(reason) {
        this.reason = reason;
      }

      return Failure;

    })();


    /*
    Encapsulates a parser context, providing useful helpers for manipulating results.
     */

    Parser.prototype.Context = Context = (function() {
      function Context() {}


      /*
      Extract the element at the given index from all elements of the given array.
       */

      Context.prototype.extract = function(array, index) {
        var element, i, len, results1;
        results1 = [];
        for (i = 0, len = array.length; i < len; i++) {
          element = array[i];
          results1.push(element[index]);
        }
        return results1;
      };


      /*
      Recursively joins an array into a single string.
       */

      Context.prototype.join = function(array) {
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
      };


      /*
      Filter falsey values from array.
       */

      Context.prototype.compact = function(array) {
        var i, len, results1, v;
        results1 = [];
        for (i = 0, len = array.length; i < len; i++) {
          v = array[i];
          if (v) {
            results1.push(v);
          }
        }
        return results1;
      };


      /*
      Unescapes a string.
       */

      Context.prototype.unescape = function(string) {
        return string.replace('\\n', '\n').replace('\\r', '\r').replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\');
      };

      return Context;

    })();


    /*
    Constructs a parser.
     */

    function Parser(input) {
      this.reset(input);
    }


    /*
    Restores the parser to a 'clean' state.
     */

    Parser.prototype.reset = function(input) {
      if (input != null) {
        this.input = String(input);
      }
      this.position = 0;
      this.parse_context = new this.Context;
      return null;
    };


    /*
    Executes the start parsing expression and returns the result, or false if that start expression
    does not match.
     */

    Parser.prototype.parse = function(input) {
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
    };


    /*
    A `pass` expression will always match and return an empty result.  It consumes no input.  Parser
    equivalent of `true`.
    
    ```coffee
      new Parser('').pass() # Result
    ```
     */

    Parser.prototype.pass = function() {
      return new Result();
    };


    /*
    An `advance` expression will consume a single character of input and return a result containing
    the consumed character.  The match only fails if the input is empty.
    
    ```coffee
      new Parser('').advance()  # fail
      new Parser('.').advance() # Result '.'
    ```
     */

    Parser.prototype.advance = function() {
      if (this.input[this.position] != null) {
        return new Result(this.input[this.position++]);
      } else {
        return false;
      }
    };


    /*
    A `literal` expression will match if the string is present at the beginning of the input. The
    result contains the parameter.
    
    ```coffee
      new Parser('world').literal 'hello' # fail
      new Parser('world').literal 'world' # Result 'world'
    ```
     */

    Parser.prototype.literal = function(context, literal) {
      if (this.input.substr(this.position, literal.length) !== literal) {
        return false;
      }
      this.position += literal.length;
      return new this.Result(literal);
    };


    /*
    An `all` expression will match if all sub-expressions match.  The result contains an array of
    sub-expression results.
    
    ```coffee
      new Parser('abc').all ( ( -> @literal c ) for c in 'abcd' ) # fail
      new Parser('abc').all ( ( -> @literal c ) for c in 'abc'  ) # Result [ 'a', 'b', 'c' ]
    ```
     */

    Parser.prototype.all = function(context, expressions) {
      return this._backtrack(context, function(context) {
        var args, expression, i, len, ref, result, results;
        results = [];
        for (i = 0, len = expressions.length; i < len; i++) {
          expression = expressions[i];
          if (Array.isArray(expression)) {
            ref = expression, expression = ref[0], args = 2 <= ref.length ? slice.call(ref, 1) : [];
          }
          if (!(result = expression.call.apply(expression, [this, context].concat(slice.call(args))))) {
            return false;
          }
          if (!result.is_empty()) {
            results.push(result.value);
          }
        }
        return new this.Result(results);
      });
    };


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

    Parser.prototype.any = function(context, expressions) {
      var expression, i, len, ref, result;
      for (i = 0, len = expressions.length; i < len; i++) {
        expression = expressions[i];
        if (!Array.isArray(expression)) {
          expression = [expression];
        }
        if (result = (ref = this._backtrack).call.apply(ref, [this, context].concat(slice.call(expression)))) {
          return result;
        }
      }
      return false;
    };


    /*
    A `some` expression will evaluate the sub-expression until the sub-expression fails.  It matches
    if the sub-expression matches at least once, and fails otherwise.  The result contains an array of
    the results of the successful sub-expression matches.
    
    ```coffee
      new Parser('aaa').some -> @literal 'b' # fail
      new Parser('aaa').some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
    ```
     */

    Parser.prototype.some = function() {
      var args, context, expression, result;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      result = expression.call.apply(expression, [this, context].concat(slice.call(args)));
      if (result) {
        return new this.Result([result.value].concat(this.maybe_some.apply(this, arguments).value));
      } else {
        return false;
      }
    };


    /*
    A `maybe_some` expression will evaluate the sub-expression until the sub-expression fails.  It
    always matches. The result contains an array of the results of the successful sub-expression
    matches.
    
    ```coffee
      new Parser('aaa').maybe_some -> @literal 'b' # Result []
      new Parser('aaa').maybe_some -> @literal 'a' # Result [ 'a', 'a', 'a' ]
    ```
     */

    Parser.prototype.maybe_some = function() {
      var args, context, expression, result, results;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      results = [];
      while (result = expression.call.apply(expression, [this, context].concat(slice.call(args)))) {
        if (!result.is_empty()) {
          results.push(result.value);
        }
      }
      return new this.Result(results);
    };


    /*
    A `some` expression will evaluate the sub-expression once. It always matches.  The result will be
    the result of the sub-expression if it matches, or a result containing null otherwise.
    
    ```coffee
      new Parser('hello').maybe -> @literal 'world' # Result null
      new Parser('hello').maybe -> @literal 'hello' # Result 'hello'
    ```
     */

    Parser.prototype.maybe = function() {
      var args, context, expression, result;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      result = expression.call.apply(expression, [this, context].concat(slice.call(args)));
      return result || new this.Result(null);
    };


    /*
    A `check` expression will evaluate the sub-expression once.  It matches if the sub-expression
    matches.  No input is consumed.  The result is an empty result.
    
    ```coffee
      new Parser('world').check -> @literal 'hello' # fail
      new Parser('world').check -> @literal 'world' # Result
    ```
     */

    Parser.prototype.check = function() {
      var args, context, expression, result;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      result = null;
      this._backtrack(context, function() {
        result = expression.call.apply(expression, [this, context].concat(slice.call(args)));
        return false;
      });
      if (result) {
        return new this.Result();
      } else {
        return false;
      }
    };


    /*
    A `reject` expression will evaluate the sub-expression once.  It matches if the sub-expression
    does not match.  No input is consumed.  The result is an empty result.
    
    ```coffee
      new Parser('world').check -> @literal 'world' # fail
      new Parser('world').check -> @literal 'hello' # Result
    ```
     */

    Parser.prototype.reject = function() {
      var args, context, expression;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      if (this.check.apply(this, arguments)) {
        return false;
      } else {
        return new this.Result();
      }
    };


    /*
    An `action` expression matches if the sub-expression matches.  If it matches the action is called
    with the result of the sub-expression.  The result is the return value of the action.
    
    ```coffee
      action = ({ result }) -> (String.fromCharCode c.charCodeAt(0) + 3 for c in result).join ''
      new Parser('abc').action ( -> @literal 'def' ), action # fail
      new Parser('abc').action ( -> @literal 'abc' ), action # Result 'def'
    ```
     */

    Parser.prototype.action = function() {
      var action, action_context, args, context, expression, i, k, result, sub_context, v;
      context = arguments[0], expression = arguments[1], args = 4 <= arguments.length ? slice.call(arguments, 2, i = arguments.length - 1) : (i = 2, []), action = arguments[i++];
      sub_context = {};
      if (result = expression.call.apply(expression, [this, sub_context].concat(slice.call(args)))) {
        for (k in sub_context) {
          if (!hasProp.call(sub_context, k)) continue;
          v = sub_context[k];
          context[k] = v;
        }
        action_context = util.merge({}, sub_context);
        action_context.$$ = result.value;
        return new this.Result(action.call(this.parse_context, action_context));
      } else {
        return result;
      }
    };


    /*
    A `label` expression matches if the sub-expression matches, and the result is the result of the
    sub-expression.  If it matches, the named result is stored on the current action context.
    
    ```coffee
      new Parser('abc').label 'match', -> @literal 'def' # fail
      new Parser('abc').label 'match', -> @literal 'abc' # Result 'abc'
    ```
     */

    Parser.prototype.label = function() {
      var args, context, expression, name, result;
      context = arguments[0], name = arguments[1], expression = arguments[2], args = 4 <= arguments.length ? slice.call(arguments, 3) : [];
      if (result = expression.call.apply(expression, [this, context].concat(slice.call(args)))) {
        context[name] = result.value;
      }
      return result;
    };


    /*
    A `token` expression matches if the sub-expression matches.  The result is an empty result.
    
    ```coffee
      new Parser('hello').token -> @literal 'world' # fail
      new Parser('hello').token -> @literal 'hello' # Result
    ```
     */

    Parser.prototype.token = function() {
      var args, context, expression;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      if (expression.call.apply(expression, [this, context].concat(slice.call(args)))) {
        return new this.Result();
      } else {
        return false;
      }
    };


    /*
    Matches the given regular expression, returning the overall match.
     */

    Parser.prototype.regex = function(context, regex) {
      var match;
      if (!(match = this.input.substr(this.position).match(regex))) {
        return false;
      }
      this.position += match[0].length;
      return new this.Result(match[0]);
    };


    /*
    Executes the given sub-expression and returns the result, and resets the position if the
    sub-expression fails.
     */

    Parser.prototype._backtrack = function() {
      var args, context, expression, k, origin, result, sub_context, v;
      context = arguments[0], expression = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      origin = this.position;
      sub_context = context != null ? util.merge({}, context) : context;
      if (result = expression.call.apply(expression, [this, sub_context].concat(slice.call(args)))) {
        for (k in sub_context) {
          if (!hasProp.call(sub_context, k)) continue;
          v = sub_context[k];
          context[k] = v;
        }
      } else {
        this.position = origin;
      }
      return result;
    };

    return Parser;

  })();

}).call(this);
