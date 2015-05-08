Parser      = require '../../src/lib/parser'
Result      = Parser::Result

describe 'Parser', ->

  parser = null

  reset_parser = (input = 'hello world') ->
    parser.reset input

  beforeEach ->
    parser = new Parser

  describe '#constructor()', ->

    it 'should return a new Parser instance', ->
      expect( new Parser ).to.be.an.instanceof Parser

  describe 'parse functions', ->

    beforeEach ->
      reset_parser()

    describe '#pass()', ->

      it 'should always succeed and match nothing, regardless of input', ->
        expect( parser.pass() ).to.deep.equal new Result()

        reset_parser 'some other string'
        expect( parser.pass() ).to.deep.equal new Result()

        reset_parser ''
        expect( parser.pass() ).to.deep.equal new Result()

    describe '#advance()', ->

      it 'should match a single character', ->
        expect( parser.advance() ).to.deep.equal new Result 'h'
        expect( parser.advance() ).to.deep.equal new Result 'e'
        expect( parser.advance() ).to.deep.equal new Result 'l'

        reset_parser ''
        expect( parser.advance() ).to.be.false

    describe '#literal()', ->

      it 'should match and return the given parameter', ->
        expect( parser.literal null, 'he' ).to.deep.equal new Result 'he'
        expect( parser.literal null, 'l'  ).to.deep.equal new Result 'l'
        expect( parser.literal null, 'o'  ).to.deep.equal false

        reset_parser ''
        expect( parser.literal null, '.' ).to.equal false

    describe '#regex()', ->

      it 'should match the given regular expression and return the overall match', ->
        expect( parser.regex null, /^./      ).to.deep.equal new Result 'h'
        expect( parser.regex null, /^.*?\s/  ).to.deep.equal new Result 'ello '
        expect( parser.regex null, /^\s/     ).to.deep.equal false
        expect( parser.regex null, /^world/  ).to.deep.equal new Result 'world'
        expect( parser.regex null, /./       ).to.deep.equal false

    describe '#maybe()', ->

      it 'should match the given expression and return the result of the expression or a null value', ->
        expect( parser.maybe null, parser.literal, 'he' ).to.deep.equal new Result 'he'
        expect( parser.maybe null, parser.literal, 'he' ).to.deep.equal new Result null
        expect( parser.maybe null, parser.regex, /^./   ).to.deep.equal new Result 'l'

    describe '#maybe_some()', ->

      it 'should match the given expression as many times as possible and return an array of matches', ->
        expect( parser.maybe_some null, parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
        expect( parser.maybe_some null, parser.literal, 'n'   ).to.deep.equal new Result []
        expect( parser.maybe_some null, parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
        expect( parser.maybe_some null, parser.regex, /^[^ ]/ ).to.deep.equal new Result []

    describe '#some()', ->

      it 'should match the given expression at least once and as many times as possible and return an array of matches', ->
        expect( parser.some null, parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
        expect( parser.some null, parser.literal, 'n'   ).to.deep.equal false
        expect( parser.some null, parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
        expect( parser.some null, parser.regex, /^[^ ]/ ).to.deep.equal false

    describe '#any()', ->

      it 'should match one of the given sub expression and return the result', ->
        expect( parser.any null, [ [ parser.literal, 'h'   ], [ parser.literal, 'n'   ] ] ).to.deep.equal new Result 'h'
        expect( parser.any null, [ [ parser.literal, 'n'   ], [ parser.literal, 'e'   ] ] ).to.deep.equal new Result 'e'
        expect( parser.any null, [ [ parser.regex, /^ll/   ], [ parser.regex, /^l/    ] ] ).to.deep.equal new Result 'll'
        expect( parser.any null, [ [ parser.literal, 'h'   ], [ parser.regex, /^[^o]/ ] ] ).to.deep.equal false
        expect( parser.any null, [ [ parser.literal, 'h'   ], [ parser.regex, /^./    ] ] ).to.deep.equal new Result 'o'
        expect( parser.any null, [ [ parser.maybe, parser.literal, 'n' ], [ parser.regex, /^./    ] ] ).to.deep.equal new Result null

    describe '#all()', ->

      it 'should match all the given sub expression and return an array of the results', ->
        expect( parser.all null, [ [ parser.literal, 'h'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal new Result [ 'h' , 'e' ]
        expect( parser.all null, [ [ parser.literal, 'l'   ], [ parser.literal, 'n'    ] ] ).to.deep.equal false
        expect( parser.all null, [ [ parser.regex, /^l/    ], [ parser.regex, /^l/     ] ] ).to.deep.equal new Result [ 'l' , 'l' ]
        expect( parser.all null, [ [ parser.literal, 'o'   ], [ parser.regex, /^[^o]/  ] ] ).to.deep.equal new Result [ 'o' , ' ' ]
        expect( parser.all null, [ [ parser.maybe, parser.literal, ' ' ], [ parser.regex, /^./ ] ] ).to.deep.equal new Result [ null, 'w' ]

      it 'should not keep anything in context if a sub expression doesn\'t match', ->
        ctx = {}

        expect( parser.all ctx, [ [ parser.label, 'label', parser.literal, 'h' ], [ parser.literal, 'l' ] ] ).to.deep.equal false
        expect( ctx.label ).to.deep.equal undefined

    describe '#check()', ->

      it 'should try and match the given sub-expression without consuming any input', ->
        expect( parser.check null, parser.literal, 'h'     ).to.deep.equal new Result()
        expect( parser.check null, parser.literal, 'h'     ).to.deep.equal new Result()
        expect( parser.check null, parser.literal, 'e'     ).to.deep.equal false
        expect( parser.check null, parser.literal, 'h'     ).to.deep.equal new Result()
        expect( parser.check null, parser.regex, /^hello / ).to.deep.equal new Result()
        expect( parser.check null, parser.regex, /^world/  ).to.deep.equal false

      it 'should keep context if the expression matches', ->
        ctx = {}

        expect( parser.check ctx, parser.label, 'label', parser.literal, 'h' ).to.deep.equal new Result()
        expect( ctx.label ).to.deep.equal 'h'

    describe '#reject()', ->

      it 'should try and reject the given sub-expression without consuming any input', ->
        expect( parser.reject null, parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject null, parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject null, parser.literal, 'e'     ).to.deep.equal new Result()
        expect( parser.reject null, parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject null, parser.regex, /^hello / ).to.deep.equal false
        expect( parser.reject null, parser.regex, /^world/  ).to.deep.equal new Result()

    describe '#label()', ->

      it 'should remember the sub-expression result if it matches', ->
        ctx = {}

        expect( parser.label ctx, 'label1', parser.literal, 'h' ).to.deep.equal new Result 'h'
        expect( ctx.label1 ).to.equal 'h'

        expect( parser.label ctx, 'label2', parser.literal, 'h' ).to.deep.equal false
        expect( ctx.label2 ).to.equal undefined

    describe '#action()', ->

      it 'should record labelled expressions and pass them to the action', ->
        expect(
          parser.action null, parser.label, 'label', parser.literal, 'h', ({label}) ->
            expect( label ).to.equal 'h'
            'override'
        ).to.deep.equal new Result 'override'

      it 'should isolate context from siblings', ->
        ctx = null
        parser.all null, [
          [ parser.action, parser.label, 'label1', parser.literal, 'h', -> ]
          [ parser.action, parser.label, 'label2', parser.literal, 'e', (o) -> ctx = o ]
        ]
        expect( ctx.label1 ).to.deep.equal undefined

      it 'should isolate context from parents', ->
        ctx = null
        parser.action null, parser.all, [
          [ parser.label, 'label1', parser.literal, 'h' ]
          [ parser.action, parser.label, 'label2', parser.literal, 'e', (o) -> ctx = o ]
        ], ->
        expect( ctx.label1 ).to.deep.equal undefined

      it 'should isolate context from parents', ->
        ctx = null
        parser.action null, parser.all, [
          [ parser.label, 'label1', parser.literal, 'h' ]
          [ parser.action, parser.label, 'label2', parser.literal, 'e', -> ]
        ], (o) -> ctx = o
        expect( ctx.label2 ).to.deep.equal undefined

    describe '#token()', ->

      it 'should match the given sub-expression and return an empty result', ->
        expect( parser.token null, parser.literal, 'hello' ).to.deep.equal new Result()
        expect( parser.token null, parser.literal, 'hello' ).to.deep.equal false
        expect( parser.token null, parser.regex, /\sworld/ ).to.deep.equal new Result()

    describe '(integration)', ->

      describe 'string syntax', ->

        it 'should match valid strings and reject invalid strings', ->
          # String:
          #   "'" string:( ( '\\\\' / !"'" ) . )* "'" -> @join string
          # / '"' string:( ( '\\\\' / !'"' ) . )* '"' -> @join string
          parser.Start = (context) -> @any context, [
            [ @action, @all, [
              [ @literal, "'" ]
              [ @label, 'string', @maybe_some, @all, [
                [ @any, [
                  [ @literal, '\\' ]
                  [ @reject, @literal, "'" ]
                ] ]
                [ @advance ]
              ] ]
              [ @literal, "'" ]
            ], ({string}) -> @join string ]
            [ @action, @all, [
              [ @literal, '"' ]
              [ @label, 'string', @maybe_some, @all, [
                [ @any, [
                  [ @literal, '\\' ]
                  [ @reject, @literal, '"' ]
                ] ]
                [ @advance ]
              ] ]
              [ @literal, '"' ]
            ], ({string}) -> @join string ]
          ]

          expect( parser.parse "'hello world'"   ).to.deep.equal 'hello world'
          # expect( parser.parse "'hello\\'"       ).to.be.false
          # expect( parser.parse "'hello\\'world'" ).to.be.ok

          # expect( parser.parse '"hello world"'   ).to.deep.equal 'hello world'
          # expect( parser.parse '"hello\\"'       ).to.be.false
          # expect( parser.parse '"hello\\"world"' ).to.be.ok