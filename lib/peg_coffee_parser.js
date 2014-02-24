(function() {
  var Parser, PegCoffeeParser, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Parser = require('./parser');

  module.exports = PegCoffeeParser = (function(_super) {
    __extends(PegCoffeeParser, _super);

    function PegCoffeeParser() {
      _ref = PegCoffeeParser.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    /*
    Matches an entire grammar.
    */


    PegCoffeeParser.prototype.Grammar = function() {
      var action;
      action = function(_arg) {
        var head, tail;
        head = _arg.head, tail = _arg.tail;
        return {
          type: 'grammar',
          content: [head].concat(this.extract(tail, 2))
        };
      };
      return this.action(this.all, [[this.label, 'head', this.Rule], [this.label, 'tail', this.maybe_some, this.all, [this.NEWLINE, this.NEWLINE, this.Rule]]], action);
    };

    /*
    Matches a rule definition.
    */


    PegCoffeeParser.prototype.Rule = function() {
      var action;
      action = function(_arg) {
        var comments, def, name, node;
        comments = _arg.comments, name = _arg.name, def = _arg.def;
        node = {
          type: 'definition',
          name: name,
          content: def
        };
        if ((comments = this.compact(comments)).length) {
          node.comments = comments;
        }
        return node;
      };
      return this.action(this.all, [[this.label, 'comments', this.maybe_some, this.any, [this.Comment, this.EMPTY_LINE]], [this.label, 'name', this.RuleIdentifier], [this.literal, ':'], this.INDENT, [this.label, 'def', this.RuleContent]], action);
    };

    /*
    Matches the content of a rule.
    */


    PegCoffeeParser.prototype.RuleContent = function() {
      var action;
      action = function(_arg) {
        var head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          return {
            type: 'choice',
            content: [head].concat(this.extract(tail, 2))
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
        var code, expr;
        expr = _arg.expr, code = _arg.code;
        if (code) {
          expr.action = code[1];
        }
        return expr;
      };
      return this.action(this.all, [[this.label, 'expr', this.Expression], [this.label, 'code', this.maybe, this.all, [[this.some, this.SPACE], this.Code]]], action);
    };

    /*
    Matches a number of sequence delimited by the choice operator.
    */


    PegCoffeeParser.prototype.Expression = function() {
      var action;
      action = function(_arg) {
        var head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          return {
            type: 'choice',
            content: [head].concat(this.extract(tail, 3))
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
        var head, tail;
        head = _arg.head, tail = _arg.tail;
        if (tail.length === 0) {
          return head;
        } else {
          return {
            type: 'sequence',
            content: [head].concat(this.extract(tail, 1))
          };
        }
      };
      return this.action(this.all, [[this.label, 'head', this.Single], [this.label, 'tail', this.maybe_some, this.all, [[this.some, this.SPACE], this.Single]]], action);
    };

    /*
    Matches a single complex expression.
    */


    PegCoffeeParser.prototype.Single = function() {
      var action;
      action = function(_arg) {
        var label, prefix, primary, suffix;
        label = _arg.label, prefix = _arg.prefix, primary = _arg.primary, suffix = _arg.suffix;
        if (label) {
          primary.label = label[0];
        }
        if (prefix) {
          primary.prefix = prefix;
        }
        if (suffix) {
          primary.suffix = suffix;
        }
        return primary;
      };
      return this.action(this.all, [[this.label, 'label', this.maybe, this.all, [this.LabelIdentifier, [this.literal, ':']]], [this.label, 'prefix', this.maybe, this.regex, /^[&!]/], [this.label, 'primary', this.Primary], [this.label, 'suffix', this.maybe, this.regex, /^[?*+]/]], action);
    };

    /*
    Matches a 'primary' expression.
    */


    PegCoffeeParser.prototype.Primary = function() {
      var action_class, action_pass, action_rule, action_string, action_sub_expression, action_wildcard;
      action_sub_expression = function(_arg) {
        var sub;
        sub = _arg.sub;
        if (sub.label) {
          return {
            type: 'subexpression',
            content: sub
          };
        } else {
          return sub;
        }
      };
      action_rule = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return {
          type: 'rule',
          name: $$
        };
      };
      action_string = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return {
          type: 'literal',
          content: $$
        };
      };
      action_class = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return {
          type: 'class',
          content: $$
        };
      };
      action_wildcard = function() {
        return {
          type: 'wildcard'
        };
      };
      action_pass = function() {
        return {
          type: 'pass'
        };
      };
      return this.any([[this.action, this.all, [[this.literal, '('], [this.label, 'sub', this.SubExpression], [this.literal, ')']], action_sub_expression], [this.action, this.RuleIdentifier, action_rule], [this.action, this.String, action_string], [this.action, this.Class, action_class], [this.action, this.literal, '.', action_wildcard], [this.action, this.literal, '~', action_pass]]);
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


    PegCoffeeParser.prototype.Code = function() {
      var action_block, action_inline;
      action_block = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return this.join($$.slice(2)).trim();
      };
      action_inline = function(_arg) {
        var $$;
        $$ = _arg.$$;
        return this.join($$.slice(1)).trim();
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


    PegCoffeeParser.prototype.String = function() {
      var action;
      action = function(_arg) {
        var content;
        content = _arg.content;
        return this.unescape(this.join(content));
      };
      return this.action(this.any, [[this.all, [[this.literal, "'"], [this.label, 'content', this.maybe_some, this.all, [[this.any, [[this.literal, '\\'], [this.reject, this.literal, "'"]]], this.advance]], [this.literal, "'"]]], [this.all, [[this.literal, '"'], [this.label, 'content', this.maybe_some, this.all, [[this.any, [[this.literal, '\\'], [this.reject, this.literal, '"']]], this.advance]], [this.literal, '"']]]], action);
    };

    /*
    Matches a character class and returns a ClassNode.
    */


    PegCoffeeParser.prototype.Class = function() {
      var action;
      action = function(_arg) {
        var content;
        content = _arg.content;
        return this.unescape(this.join(content));
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
