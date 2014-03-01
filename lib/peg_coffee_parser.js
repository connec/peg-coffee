(function() {
  var Parser, PegCoffeeParser,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Parser = require('./parser');

  module.exports = PegCoffeeParser = (function(_super) {
    __extends(PegCoffeeParser, _super);

    function PegCoffeeParser() {
      return PegCoffeeParser.__super__.constructor.apply(this, arguments);
    }


    /*
    Matches an entire grammar.
     */

    PegCoffeeParser.prototype.Grammar = function() {
      var action;
      action = function(_arg) {
        var content, head, name, parser, tail, _i, _len, _ref, _ref1;
        head = _arg.head, tail = _arg.tail;
        parser = (function(_super1) {
          __extends(_Class, _super1);

          function _Class() {
            return _Class.__super__.constructor.apply(this, arguments);
          }

          return _Class;

        })(Parser);
        parser.prototype.Start = head.content;
        _ref = [head].concat(this.extract(tail, 2));
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          _ref1 = _ref[_i], name = _ref1.name, content = _ref1.content;
          parser.prototype[name] = content;
        }
        return parser;
      };
      return this.action(this.all, [[this.label, 'head', this.Rule], [this.label, 'tail', this.maybe_some, this.all, [this.NEWLINE, this.NEWLINE, this.Rule]]], action);
    };


    /*
    Matches a rule definition.
     */

    PegCoffeeParser.prototype.Rule = function() {
      var action;
      action = function(_arg) {
        var comments, content, name;
        comments = _arg.comments, name = _arg.name, content = _arg.content;
        return {
          name: name,
          content: content,
          comments: this.compact(comments)
        };
      };
      return this.action(this.all, [[this.label, 'comments', this.maybe_some, this.any, [this.Comment, this.EMPTY_LINE]], [this.label, 'name', this.RuleIdentifier], [this.literal, ':'], this.INDENT, [this.label, 'content', this.RuleContent]], action);
    };


    /*
    Matches the content of a rule.
     */

    PegCoffeeParser.prototype.RuleContent = function() {
      var action;
      action = function(_arg) {
        var extract, head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          extract = this.extract;
          return function() {
            return this.any([head].concat(extract(tail, 2)));
          };
        }
      };
      return this.action(this.all, [[this.label, 'head', this.RuleLine], [this.label, 'tail', this.maybe_some, this.all, [this.NEWLINE, [this.literal, '/'], this.SPACE, this.RuleLine]]], action);
    };


    /*
    Matches an expression possibly followed by some code.
     */

    PegCoffeeParser.prototype.RuleLine = function() {
      var action;
      action = function(_arg) {
        var action, expr;
        expr = _arg.expr, action = _arg.action;
        if (action) {
          return function() {
            return this.action(expr, action);
          };
        } else {
          return expr;
        }
      };
      return this.action(this.all, [[this.label, 'expr', this.Expression], [this.maybe, this.all, [[this.some, this.SPACE], [this.label, 'action', this.Action]]]], action);
    };


    /*
    Matches a number of sequence delimited by the choice operator.
     */

    PegCoffeeParser.prototype.Expression = function() {
      var action;
      action = function(_arg) {
        var extract, head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          extract = this.extract;
          return function() {
            return this.any([head].concat(extract(tail, 3)));
          };
        }
      };
      return this.action(this.all, [[this.label, 'head', this.Sequence], [this.label, 'tail', this.maybe_some, this.all, [[this.some, this.SPACE], [this.literal, '/'], [this.some, this.SPACE], this.Sequence]]], action);
    };


    /*
    Matches a number of Singles delimited by spaces
     */

    PegCoffeeParser.prototype.Sequence = function() {
      var action;
      action = function(_arg) {
        var extract, head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          extract = this.extract;
          return function() {
            return this.all([head].concat(extract(tail, 1)));
          };
        }
      };
      return this.action(this.all, [[this.label, 'head', this.Label], [this.label, 'tail', this.maybe_some, this.all, [[this.some, this.SPACE], this.Label]]], action);
    };


    /*
    Matches a labelled expression.
     */

    PegCoffeeParser.prototype.Label = function() {
      var action;
      action = function(_arg) {
        var expr, label;
        label = _arg.label, expr = _arg.expr;
        return function() {
          return this.label(label, expr);
        };
      };
      return this.any([[this.action, this.all, [[this.label, 'label', this.LabelIdentifier], [this.literal, ':'], [this.label, 'expr', this.Prefix]], action], this.Prefix]);
    };


    /*
    Matches a prefixed expression.
     */

    PegCoffeeParser.prototype.Prefix = function() {
      var action;
      action = function(_arg) {
        var expr, prefix;
        prefix = _arg.prefix, expr = _arg.expr;
        switch (prefix) {
          case '&':
            return function() {
              return this.check(expr);
            };
          case '!':
            return function() {
              return this.reject(expr);
            };
        }
      };
      return this.any([[this.action, this.all, [[this.label, 'prefix', this.regex, /^[&!]/], [this.label, 'expr', this.Suffix]], action], this.Suffix]);
    };


    /*
    Matches a suffixed operator.
     */

    PegCoffeeParser.prototype.Suffix = function() {
      var action;
      action = function(_arg) {
        var expr, suffix;
        suffix = _arg.suffix, expr = _arg.expr;
        switch (suffix) {
          case '?':
            return function() {
              return this.maybe(expr);
            };
          case '*':
            return function() {
              return this.maybe_some(expr);
            };
          case '+':
            return function() {
              return this.some(expr);
            };
        }
      };
      return this.any([[this.action, this.all, [[this.label, 'expr', this.Primary], [this.label, 'suffix', this.regex, /^[?*+]/]], action], this.Primary]);
    };


    /*
    Matches a primary expression.
     */

    PegCoffeeParser.prototype.Primary = function() {
      var action_advance, action_class, action_literal, action_pass, action_rule, action_sub_expression;
      action_sub_expression = function(_arg) {
        var sub;
        sub = _arg.sub;
        return sub;
      };
      action_rule = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return function() {
          return this[$$]();
        };
      };
      action_literal = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return $$;
      };
      action_class = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return $$;
      };
      action_advance = function() {
        return function() {
          return this.advance();
        };
      };
      action_pass = function() {
        return function() {
          return this.pass();
        };
      };
      return this.any([[this.action, this.all, [[this.literal, '('], [this.label, 'sub', this.SubExpression], [this.literal, ')']], action_sub_expression], [this.action, this.RuleIdentifier, action_rule], [this.action, this.Literal, action_literal], [this.action, this.Class, action_class], [this.action, this.literal, '.', action_advance], [this.action, this.literal, '~', action_pass]]);
    };


    /*
    Matches the contents of a parenthesised sub expression.
     */

    PegCoffeeParser.prototype.SubExpression = function() {
      var action;
      action = function(_arg) {
        var sub;
        sub = _arg.sub;
        return sub;
      };
      return this.any([[this.action, this.all, [this.SPACE, [this.label, 'sub', this.SubExpression], this.SPACE], action], this.Expression]);
    };


    /*
    Matches code in one of two formats:
    - block
    - inline
     */

    PegCoffeeParser.prototype.Action = function() {
      var action_block, action_inline;
      action_block = function(_arg) {
        var $$, $code;
        $$ = _arg.$$;
        $code = this.join($$.slice(2)).trim();
        return function(context) {
          var k, v;
          for (k in context) {
            if (!__hasProp.call(context, k)) continue;
            v = context[k];
            eval("var " + k + " = v");
          }
          return eval(require('coffee-script').compile($code, {
            bare: true
          }));
        };
      };
      action_inline = function(_arg) {
        var $$, $code;
        $$ = _arg.$$;
        $code = this.join($$.slice(1)).trim();
        return function(context) {
          var k, v;
          for (k in context) {
            if (!__hasProp.call(context, k)) continue;
            v = context[k];
            eval("var " + k + " = v");
          }
          return eval(require('coffee-script').compile($code, {
            bare: true
          }));
        };
      };
      return this.any([[this.action, this.all, [[this.literal, '->'], this.DOUBLE_INDENT, [this.reject, this.WHITESPACE], this.advance, [this.maybe_some, this.any, [[this.all, [[this.reject, this.NEWLINE], this.advance]], [this.all, [[this.maybe_some, this.all, [[this.reject, this.DOUBLE_INDENT], this.WHITESPACE]], this.DOUBLE_INDENT]]]]], action_block], [this.action, this.all, [[this.literal, '->'], [this.some, this.SPACE], [this.some, this.all, [[this.reject, this.NEWLINE], this.advance]]], action_inline]]);
    };


    /*
    Matches a single line comment.
     */

    PegCoffeeParser.prototype.Comment = function() {
      var action;
      action = function(_arg) {
        var content;
        content = _arg.content;
        return this.join(content).trim();
      };
      return this.action(this.all, [[this.literal, '#'], [this.label, 'content', this.maybe_some, this.all, [[this.reject, this.NEWLINE], this.advance]], this.NEWLINE], action);
    };


    /*
    Matches a rule identifier.
     */

    PegCoffeeParser.prototype.RuleIdentifier = function() {
      var action;
      action = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return this.join($$);
      };
      return this.action(this.all, [[this.regex, /^[A-Z]/], [this.maybe_some, this.regex, /^[_a-zA-Z]/]], action);
    };


    /*
    Matches a label identifier.
     */

    PegCoffeeParser.prototype.LabelIdentifier = function() {
      var action;
      action = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return this.join($$);
      };
      return this.action(this.some, this.regex, /^[_a-z]/, action);
    };


    /*
    Matches a string and returns a StringNode.
     */

    PegCoffeeParser.prototype.Literal = function() {
      var action, p;
      p = this;
      action = function(_arg) {
        var content, literal;
        content = _arg.content;
        literal = this.unescape(this.join(content));
        return function() {
          return this.literal(literal);
        };
      };
      return this.action(this.any, [[this.all, [[this.literal, "'"], [this.label, 'content', this.maybe_some, this.all, [[this.any, [[this.literal, '\\'], [this.reject, this.literal, "'"]]], this.advance]], [this.literal, "'"]]], [this.all, [[this.literal, '"'], [this.label, 'content', this.maybe_some, this.all, [[this.any, [[this.literal, '\\'], [this.reject, this.literal, '"']]], this.advance]], [this.literal, '"']]]], action);
    };


    /*
    Matches a character class and returns a ClassNode.
     */

    PegCoffeeParser.prototype.Class = function() {
      var action;
      action = function(_arg) {
        var content, klass;
        content = _arg.content;
        klass = this.unescape(this.join(content));
        return function() {
          return this.regex(RegExp("^[" + klass + "]"));
        };
      };
      return this.action(this.all, [[this.literal, '['], [this.label, 'content', this.maybe_some, this.all, [[this.any, [[this.literal, '\\'], [this.reject, this.literal, ']']]], this.advance]], [this.literal, ']']], action);
    };


    /*
    Matches an indent followed by two spaces.
     */

    PegCoffeeParser.prototype.DOUBLE_INDENT = function() {
      return this.action(this.all, [this.INDENT, this.SPACE, this.SPACE], function() {
        return '\n';
      });
    };


    /*
    Matches a single indent (a newline followed by two space).
     */

    PegCoffeeParser.prototype.INDENT = function() {
      return this.token(this.all, [this.NEWLINE, this.SPACE, this.SPACE]);
    };


    /*
    Matches whitespace followed eventually by a newline.
     */

    PegCoffeeParser.prototype.EMPTY_LINE = function() {
      return this.token(this.all, [[this.maybe_some, this.SPACE], this.NEWLINE]);
    };


    /*
    Matches a single whitespace character (newline or space).
     */

    PegCoffeeParser.prototype.WHITESPACE = function() {
      return this.any([this.NEWLINE, this.SPACE]);
    };


    /*
    Matches a single CR/LF newline.
     */

    PegCoffeeParser.prototype.NEWLINE = function() {
      return this.action(this.any, [[this.all, [[this.literal, '\r'], [this.maybe, this.literal, '\n']]], [this.literal, '\n']], function() {
        return '\n';
      });
    };


    /*
    Matches a single space.
     */

    PegCoffeeParser.prototype.SPACE = function() {
      return this.token(this.literal, ' ');
    };


    /*
    The initial parsing expression to apply when `parse` is called.
     */

    PegCoffeeParser.prototype.Start = PegCoffeeParser.prototype.Grammar;

    return PegCoffeeParser;

  })(Parser);

}).call(this);
