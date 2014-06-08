fs              = require 'fs'
path            = require 'path'
PegCoffeeParser = require '../../src/lib/peg_coffee_parser'
Result          = PegCoffeeParser::Result

describe 'PegCoffeeParser', ->

  parser = null

  reset_parser = (input) ->
    parser.reset input

  beforeEach ->
    parser = new PegCoffeeParser

  describe 'integration', ->

    describe 'the peg-coffee grammar', ->

      it 'should be able to parse its own grammar', ->
        grammar = fs.readFileSync path.join(__dirname, '../support/sample.peg-coffee'), 'utf8'
        expect( parser = parser.parse grammar ).to.be.ok
        expect( new parser().parse grammar ).to.be.ok

  describe 'parse functions', ->

    describe '#SPACE()', ->

      it 'should match a single space, and return nothing', ->
        reset_parser '  hello'
        expect( parser.SPACE() ).to.deep.equal new Result()
        expect( parser.SPACE() ).to.deep.equal new Result()
        expect( parser.SPACE() ).to.be.false

        reset_parser ''
        expect( parser.SPACE() ).to.be.false

    describe '#NEWLINE()', ->

      it 'should match a single CR/LF newline', ->
        reset_parser '\r\n\n\n\r'
        expect( parser.NEWLINE() ).to.deep.equal new Result '\n'
        expect( parser.NEWLINE() ).to.deep.equal new Result '\n'
        expect( parser.NEWLINE() ).to.deep.equal new Result '\n'
        expect( parser.NEWLINE() ).to.deep.equal new Result '\n'
        expect( parser.NEWLINE() ).to.be.false

        reset_parser '\nhello'
        expect( parser.NEWLINE() ).to.deep.equal new Result '\n'
        expect( parser.NEWLINE() ).to.be.false

        reset_parser ''
        expect( parser.NEWLINE() ).to.be.false

    describe '#WHITESPACE()', ->

      it 'should match a single whitespace character', ->
        reset_parser ' \r\n\n\rhello'
        expect( parser.WHITESPACE() ).to.deep.equal new Result()
        expect( parser.WHITESPACE() ).to.deep.equal new Result '\n'
        expect( parser.WHITESPACE() ).to.deep.equal new Result '\n'
        expect( parser.WHITESPACE() ).to.deep.equal new Result '\n'
        expect( parser.WHITESPACE() ).to.be.false

        reset_parser ''
        expect( parser.WHITESPACE() ).to.be.false

    describe '#INDENT()', ->

      it 'should match a newline followed by two spaces', ->
        reset_parser '\n  '
        expect( parser.INDENT() ).to.deep.equal new Result()

        reset_parser '\n  hello'
        expect( parser.INDENT() ).to.deep.equal new Result()

        reset_parser '\n '
        expect( parser.INDENT() ).to.be.false

        reset_parser ' \n  '
        expect( parser.INDENT() ).to.be.false

    describe '#DOUBLE_INDENT()', ->

      it 'should match an indent followed by two spaces', ->
        reset_parser '\n    '
        expect( parser.DOUBLE_INDENT() ).to.deep.equal new Result '\n'

        reset_parser '\n    hello'
        expect( parser.DOUBLE_INDENT() ).to.deep.equal new Result '\n'

        reset_parser '\n  '
        expect( parser.DOUBLE_INDENT() ).to.be.false

        reset_parser ' \n    '
        expect( parser.DOUBLE_INDENT() ).to.be.false

    describe '#Class()', ->

      it 'should match a character class and return a character class node', ->
        reset_parser '[a-z]'
        expect( r = parser.Class() ).to.be.ok

        reset_parser 'amz0'
        expect( r.value.call(parser).value ).to.equal c for c in 'amz'
        expect( r.value.call parser        ).to.be.false

        reset_parser '[a-z\\]'
        expect( parser.Class() ).to.be.false

        reset_parser '[a-z\\]]'
        expect( r = parser.Class() ).to.be.ok

        reset_parser 'amz]['
        expect( r.value.call(parser).value ).to.equal c for c in 'amz]'
        expect( r.value.call parser        ).to.be.false

    describe '#Literal()', ->

      it 'should match a single-quoted string', ->
        reset_parser "'hello world'"
        expect( r = parser.Literal() ).to.be.ok

        reset_parser "hello worldabc"
        expect( r.value.call(parser).value ).to.equal 'hello world'
        expect( r.value.call parser        ).to.be.false

        reset_parser "'hello\\'world\"'"
        expect( r = parser.Literal() ).to.be.ok

        reset_parser 'hello\'world"abc'
        expect( r.value.call(parser).value ).to.equal 'hello\'world"'

        reset_parser "'hello\\'"
        expect( parser.Literal() ).to.be.false

      it 'should match a double-quoted string', ->
        reset_parser '"hello world"'
        expect( r = parser.Literal() ).to.be.ok

        reset_parser "hello worldabc"
        expect( r.value.call(parser).value ).to.equal 'hello world'
        expect( r.value.call parser        ).to.be.false

        reset_parser '"hello\\"world\'"'
        expect( r = parser.Literal() ).to.be.ok

        reset_parser 'hello"world\'abc'
        expect( r.value.call(parser).value ).to.equal 'hello"world\''

        reset_parser '"hello\\"'
        expect( parser.Literal() ).to.be.false

    describe '#LabelIdentifier()', ->

      it 'should match a label identifier', ->
        reset_parser 'hello_world'
        expect( parser.LabelIdentifier() ).to.deep.equal new Result 'hello_world'

        reset_parser 'Hello'
        expect( parser.LabelIdentifier() ).to.be.false

    describe '#RuleIdentifier()', ->

      it 'should match a rule identifier', ->
        reset_parser 'HelloWorld '
        expect( parser.RuleIdentifier() ).to.deep.equal new Result 'HelloWorld'

        reset_parser 'HELLO_WORLD '
        expect( parser.RuleIdentifier() ).to.deep.equal new Result 'HELLO_WORLD'

        reset_parser 'hello_world '
        expect( parser.RuleIdentifier() ).to.be.false

    describe '#Comment()', ->

      it 'should match a single line comment', ->
        reset_parser '# hello world  \nsomething else'#
        expect( parser.Comment() ).to.deep.equal new Result 'hello world'
        expect( parser.input[parser.position..] ).to.equal 'something else'

        reset_parser '#hello world'
        expect( parser.Comment() ).to.be.false

    describe '#Action()', ->

      it 'should match inline code', ->
        nonce = Math.random()

        reset_parser input = "-> #{nonce}\n"
        expect( r = parser.Action() ).to.be.ok
        expect( r.value() ).to.equal nonce
        expect( parser.input[parser.position..] ).to.equal '\n'

      it 'should match double indented code', ->
        nonce = Math.random()

        reset_parser "->\n    #{nonce}\n"
        expect( r = parser.Action() ).to.be.ok
        expect( r.value() ).to.equal nonce
        expect( parser.input[parser.position..] ).to.equal '\n'

        reset_parser "->\n    [\n      #{nonce}\n      #{nonce}    ]\n"
        expect( r = parser.Action() ).to.be.ok
        expect( r.value() ).to.deep.equal [ nonce, nonce ]
        expect( parser.input[parser.position..] ).to.equal '\n'

        reset_parser '->\n   console.log "hi"\n'
        expect( parser.Action() ).to.be.false

    describe '#SubExpression()', ->

      beforeEach ->
        # For testing purposes, an expression is a literal 'hello world'
        parser.Expression = -> @literal 'hello world'

      it 'should match an Expression', ->
        reset_parser 'hello worlds'
        expect( parser.SubExpression() ).to.deep.equal new Result 'hello world'
        expect( parser.input[parser.position..] ).to.equal 's'

        reset_parser 'ohello worlds'
        expect( parser.SubExpression() ).to.be.false

      it 'should match balanced spaces around an Expression', ->
        reset_parser '  hello world  s'
        expect( parser.SubExpression() ).to.deep.equal new Result 'hello world'
        expect( parser.input[parser.position..] ).to.equal 's'

        reset_parser '   hello world    s'
        expect( parser.SubExpression() ).to.deep.equal new Result 'hello world'
        expect( parser.input[parser.position..] ).to.equal ' s'

        reset_parser '   hello world    s'
        expect( parser.SubExpression() ).to.deep.equal new Result 'hello world'
        expect( parser.input[parser.position..] ).to.equal ' s'

        reset_parser ' hello worlds'
        expect( parser.SubExpression() ).to.be.false

    describe '#Primary', ->

      beforeEach ->
        # For testing purposes, an expression is a literal 'hello world'
        parser.Expression = -> @literal 'hello world'

      it 'should a SubExpression in brackets', ->
        reset_parser '( hello world )'
        expect( parser.Primary() ).to.deep.equal new Result 'hello world'

        reset_parser '(hello world'
        expect( parser.Primary() ).to.be.false

      it 'should match a RuleIdentifier', ->
        reset_parser 'HelloWorld'
        expect( r = parser.Primary() ).to.be.ok

        parser.HelloWorld = sinon.stub()
        r.value.call parser
        expect( parser.HelloWorld ).to.have.been.calledOnce

        reset_parser 'HELLO_WORLD'
        expect( r = parser.Primary() ).to.be.ok

        parser.HELLO_WORLD = sinon.stub()
        r.value.call parser
        expect( parser.HELLO_WORLD ).to.have.been.calledOnce

        reset_parser 'hELLO_WORLD'
        expect( parser.Primary() ).to.be.false

      it 'should match a String', ->
        reset_parser "'hello world'"
        expect( r = parser.Primary() ).to.be.ok

        reset_parser 'hello world'
        expect( r.value.call(parser).value ).to.equal 'hello world'

        reset_parser '"hello\\"world\'"'
        expect( r = parser.Primary() ).to.be.ok

        reset_parser 'hello"world\''
        expect( r.value.call(parser).value ).to.equal 'hello"world\''

        reset_parser "'hello\\'"
        expect( parser.Primary() ).to.be.false

      it 'should match a character class', ->
        reset_parser '[a-z]'
        expect( r = parser.Primary() ).to.be.ok

        reset_parser 'amz0'
        expect( r.value.call(parser).value ).to.equal c for c in 'amz'
        expect( r.value.call parser        ).to.be.false

        reset_parser '[a-z\\]'
        expect( parser.Primary() ).to.be.false

        reset_parser '[a-z\\]]'
        expect( r = parser.Primary() ).to.be.ok

        reset_parser 'amz]['
        expect( r.value.call(parser).value ).to.equal c for c in 'amz]'
        expect( r.value.call parser        ).to.be.false

      it 'should match a dot wildcard', ->
        reset_parser '..'
        expect( r1 = parser.Primary() ).to.be.ok
        expect( r2 = parser.Primary() ).to.be.ok
        expect( parser.Primary() ).to.be.false

        reset_parser input = Math.random().toString(36)[2..]
        expect( r1.value.call(parser).value ).to.equal input[0]
        expect( r2.value.call(parser).value ).to.equal input[1]

      it 'should match a tilde', ->
        reset_parser '~~'
        expect( r1 = parser.Primary() ).to.be.ok
        expect( r2 = parser.Primary() ).to.be.ok
        expect( parser.Primary() ).to.be.false

        reset_parser input = Math.random().toString(36)[2..]
        expect( r1.value.call(parser).is_empty() ).to.be.true
        expect( r2.value.call(parser).is_empty() ).to.be.true
        expect( parser.position ).to.equal 0

    describe '#Sequence()', ->

      beforeEach ->
        # For testing purposes, an expression is a literal 'hello world'
        # parser.Expression = parser.Expression

      it 'should match a single Single', ->
        reset_parser 'label:&(.)+'
        expect( r = parser.Sequence() ).to.be.ok

        reset_parser 'a'
        expect( r.value.call(parser).is_empty() ).to.be.true
        expect( parser.position ).to.equal 0

        reset_parser '!"hello world"'
        expect( r = parser.Sequence() ).to.be.ok

        reset_parser 'ahello world'
        expect( r.value.call(parser).is_empty() ).to.be.true
        parser.advance()
        expect( r.value.call parser ).to.be.false

        reset_parser 'all_the_things:.*'
        expect( r = parser.Sequence() ).to.be.ok

        reset_parser input = Math.random().toString(36)
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ input... ]
        expect( ctx.all_the_things         ).to.deep.equal [ input... ]

      it 'should match a sequence of Singles delimited by some spaces', ->
        reset_parser '!"hello world"   all_the_things:.*'
        expect( r = parser.Sequence() ).to.be.ok

        reset_parser input = "#{Math.random().toString 36}hello world"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ [ input... ] ]
        expect( ctx.all_the_things         ).to.deep.equal [ input... ]

        reset_parser input = "hello world#{Math.random().toString 36}"
        expect( r.value.call parser ).to.be.false

    describe '#Expression()', ->

      it 'should match a Sequence', ->
        reset_parser 'label:&.+'
        expect( r = parser.Expression() ).to.be.ok

        reset_parser 'a'
        expect( r.value.call(parser).is_empty() ).to.be.true
        expect( parser.position ).to.equal 0

        reset_parser '!"hello world"   all_the_things:.*'
        expect( r = parser.Expression() ).to.be.ok

        reset_parser input = "#{Math.random().toString 36}hello world"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ [ input... ] ]
        expect( ctx.all_the_things         ).to.deep.equal [ input... ]

        reset_parser input = "hello world#{Math.random().toString 36}"
        expect( r.value.call parser ).to.be.false

      it 'should match a number of Sequences delimited by /', ->
        reset_parser '!"hello world"   all_the_things:.* / label:.+'
        expect( r = parser.Expression() ).to.be.ok

        reset_parser input = "#{Math.random().toString 36}hello world"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ [ input... ] ]
        expect( ctx.all_the_things         ).to.deep.equal [ input... ]

        reset_parser input = "hello world#{Math.random().toString 36}"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ input... ]
        expect( ctx.label                  ).to.deep.equal [ input... ]

    describe '#RuleLine()', ->

      it 'should match an expression', ->
        reset_parser '!"hello world"   all_the_things:.* / label:.+'
        expect( r = parser.RuleLine() ).to.be.ok

        reset_parser input = "#{Math.random().toString 36}hello world"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ [ input... ] ]
        expect( ctx.all_the_things         ).to.deep.equal [ input... ]

        reset_parser input = "hello world#{Math.random().toString 36}"
        parser.action_contexts.push ctx = {}
        expect( r.value.call(parser).value ).to.deep.equal [ input... ]
        expect( ctx.label                  ).to.deep.equal [ input... ]

      it 'should match an expression followed by some inline code', ->
        reset_parser 'label:( [A-Z] [a-z]* ) -> @nonce() ; "x#{@join label}x"'

        nonce = sinon.spy()
        parser.Context = class extends parser.Context
          nonce: nonce

        expect( r = parser.RuleLine() ).to.be.ok

        reset_parser input = 'Hello'
        expect( r.value.call(parser).value ).to.equal "x#{input}x"
        expect( parser.Context::nonce      ).to.have.been.calledOnce

      it 'should match an expression followed by a block of code', ->
        reset_parser '''
          label:( [A-Z] [a-z]* ) ->
              @nonce()
              "x#{@join label}x"
        '''

        nonce = sinon.spy()
        parser.Context = class extends parser.Context
          nonce: nonce

        expect( r = parser.RuleLine() ).to.be.ok

        reset_parser input = 'Hello'
        expect( r.value.call(parser).value ).to.equal "x#{input}x"
        expect( parser.Context::nonce      ).to.have.been.calledOnce

    describe '#RuleContent()', ->

      it 'should match a single RuleLine', ->
        reset_parser 'label:( [A-Z] [a-z]* ) -> @nonce() ; "x#{@join label}x"'

        nonce = sinon.spy()
        parser.Context = class extends parser.Context
          nonce: nonce

        expect( r = parser.RuleContent() ).to.be.ok

        reset_parser input = 'Hello'
        expect( r.value.call(parser).value ).to.equal "x#{input}x"
        expect( nonce                      ).to.have.been.calledOnce

      it 'should match multiple, delimited RuleLines', ->
        reset_parser '''
          a:'a' -> @nonce_a() ; a
          / b:'b' -> @nonce_b() ; b
        '''

        nonce_a = sinon.spy()
        nonce_b = sinon.spy()
        parser.Context = class extends parser.Context
          nonce_a: nonce_a
          nonce_b: nonce_b

        expect( r = parser.RuleContent() ).to.be.ok

        reset_parser 'a'
        expect( r.value.call(parser).value ).to.equal 'a'
        expect( parser.Context::nonce_a    ).to.have.been.calledOnce
        expect( parser.Context::nonce_b    ).not.to.have.been.calledOnce

        reset_parser 'b'
        nonce_a.reset()
        nonce_b.reset()
        expect( r.value.call(parser).value ).to.equal 'b'
        expect( parser.Context::nonce_a    ).not.to.have.been.calledOnce
        expect( parser.Context::nonce_b    ).to.have.been.calledOnce

      it 'should match a rule action', ->
        reset_parser '''
          a:'a' -> @nonce_a() ; a
          / b:'b' -> @nonce_b() ; b
            -> @nonce_c() ; $$
        '''

        nonce_a = sinon.spy()
        nonce_b = sinon.spy()
        nonce_c = sinon.spy()
        parser.Context = class extends parser.Context
          nonce_a: nonce_a
          nonce_b: nonce_b
          nonce_c: nonce_c

        expect( r = parser.RuleContent() ).to.be.ok

        reset_parser 'a'
        expect( r.value.call(parser).value ).to.deep.equal 'a'
        expect( nonce_a                    ).to.have.been.calledOnce
        expect( nonce_b                    ).not.to.have.been.calledOnce
        expect( nonce_c                    ).to.have.been.calledOnce

        reset_parser 'b'
        nonce_a.reset()
        nonce_b.reset()
        nonce_c.reset()
        expect( r.value.call(parser).value ).to.equal 'b'
        expect( nonce_a                    ).not.to.have.been.calledOnce
        expect( nonce_b                    ).to.have.been.calledOnce
        expect( nonce_c                    ).to.have.been.calledOnce

    describe '#Rule()', ->

      it 'should match a rule definition', ->
        reset_parser '''
          Rule:
            a:'a' -> a
          / b:'b' -> b
            -> $$
        '''
        expect( r = parser.Rule() ).to.be.ok
        expect( r.value.name      ).to.equal 'Rule'
        expect( r.value.comments  ).to.deep.equal []

        reset_parser 'a'
        expect( r.value.content.call(parser).value ).to.equal 'a'

        reset_parser 'b'
        expect( r.value.content.call(parser).value ).to.equal 'b'

      it 'should match preceeding comments', ->
        reset_parser '''
          # Some rule.
          Rule:
            'a'
        '''
        expect( r = parser.Rule() ).to.be.ok
        expect( r.value.name      ).to.equal 'Rule'
        expect( r.value.comments  ).to.deep.equal [ 'Some rule.' ]

        reset_parser 'a'
        expect( r.value.content.call(parser).value ).to.equal 'a'

    describe '#Grammar()', ->

      it 'should match a number of rules', ->
        reset_parser '''
          # A
          A:
            b:B

          # B
          B:
            'b'
        '''
        expect( r = parser.Grammar() ).to.be.ok
        expect( r.value              ).to.be.an.instanceof Function
        expect( r.value::A           ).to.be.an.instanceof Function
        expect( r.value::B           ).to.be.an.instanceof Function

        parser = new r.value
        parser.reset 'b'
        expect( parser.B().value ).to.equal 'b'

        parser.reset 'b'
        expect( parser.A().value ).to.equal 'b'