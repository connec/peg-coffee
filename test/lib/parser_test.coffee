Parser      = require '../../src/lib/parser'
Result      = Parser::Result

describe 'Parser', ->

  parser = null

  reset_parser = (input = 'hello world') ->
    parser.reset input

  beforeEach ->
    parser = new Parser
    reset_parser()

  describe '#constructor()', ->

    it 'should return a new Parser instance', ->
      expect( new Parser ).to.be.an.instanceof Parser

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
      expect( parser.literal {}, 'he' ).to.deep.equal new Result 'he'
      expect( parser.literal {}, 'l'  ).to.deep.equal new Result 'l'
      expect( parser.literal {}, 'o'  ).to.deep.equal false

      reset_parser ''
      expect( parser.literal {}, '.' ).to.equal false

  describe '#regex()', ->

    it 'should match the given regular expression and return the overall match', ->
      expect( parser.regex {}, /^./      ).to.deep.equal new Result 'h'
      expect( parser.regex {}, /^.*?\s/  ).to.deep.equal new Result 'ello '
      expect( parser.regex {}, /^\s/     ).to.deep.equal false
      expect( parser.regex {}, /^world/  ).to.deep.equal new Result 'world'
      expect( parser.regex {}, /./       ).to.deep.equal false

  describe '#maybe()', ->

    it 'should match the given expression and return the result of the expression or a null value', ->
      expect( parser.maybe {}, parser.literal, 'he' ).to.deep.equal new Result 'he'
      expect( parser.maybe {}, parser.literal, 'he' ).to.deep.equal new Result null
      expect( parser.maybe {}, parser.regex, /^./   ).to.deep.equal new Result 'l'

  describe '#maybe_some()', ->

    it 'should match the given expression as many times as possible and return an array of matches', ->
      expect( parser.maybe_some {}, parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
      expect( parser.maybe_some {}, parser.literal, 'n'   ).to.deep.equal new Result []
      expect( parser.maybe_some {}, parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
      expect( parser.maybe_some {}, parser.regex, /^[^ ]/ ).to.deep.equal new Result []

  describe '#some()', ->

    it 'should match the given expression at least once and as many times as possible and return an array of matches', ->
      expect( parser.some {}, parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
      expect( parser.some {}, parser.literal, 'n'   ).to.deep.equal false
      expect( parser.some {}, parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
      expect( parser.some {}, parser.regex, /^[^ ]/ ).to.deep.equal false

  describe '#any()', ->

    it 'should match one of the given sub expression and return the result', ->
      expect( parser.any {}, [ [ parser.literal, 'h'   ], [ parser.literal, 'n'   ] ] ).to.deep.equal new Result 'h'
      expect( parser.any {}, [ [ parser.literal, 'n'   ], [ parser.literal, 'e'   ] ] ).to.deep.equal new Result 'e'
      expect( parser.any {}, [ [ parser.regex, /^ll/   ], [ parser.regex, /^l/    ] ] ).to.deep.equal new Result 'll'
      expect( parser.any {}, [ [ parser.literal, 'h'   ], [ parser.regex, /^[^o]/ ] ] ).to.deep.equal false
      expect( parser.any {}, [ [ parser.literal, 'h'   ], [ parser.regex, /^./    ] ] ).to.deep.equal new Result 'o'
      expect( parser.any {}, [ [ parser.maybe, parser.literal, 'n' ], [ parser.regex, /^./    ] ] ).to.deep.equal new Result null

    it 'should only remember labels for matching sub-expressions', ->
      ctx = {}

      expect( parser.any ctx, [
        [ parser.label, 'l1', parser.literal, 'e' ]
        [ parser.label, 'l2', parser.literal, 'h' ]
        [ parser.label, 'l3', parser.literal, 'e' ]
      ] )
        .to.deep.equal new Result 'h'

      expect( ctx ).to.deep.equal l2: 'h'

  describe '#all()', ->

    it 'should match all the given sub expression and return an array of the results', ->
      expect( parser.all {}, [ [ parser.literal, 'h'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal new Result [ 'h' , 'e' ]
      expect( parser.all {}, [ [ parser.literal, 'l'   ], [ parser.literal, 'n'    ] ] ).to.deep.equal false
      expect( parser.all {}, [ [ parser.regex, /^l/    ], [ parser.regex, /^l/     ] ] ).to.deep.equal new Result [ 'l' , 'l' ]
      expect( parser.all {}, [ [ parser.literal, 'o'   ], [ parser.regex, /^[^o]/  ] ] ).to.deep.equal new Result [ 'o' , ' ' ]
      expect( parser.all {}, [ [ parser.maybe, parser.literal, ' ' ], [ parser.regex, /^./ ] ] ).to.deep.equal new Result [ null, 'w' ]

    it 'should only remember labels for matching sub-expressions', ->
      ctx = {}

      expect( parser.all ctx, [
        [ parser.label, 'l1', parser.literal, 'h' ]
        [ parser.literal, 'h' ]
      ] ).to.deep.equal false
      expect( ctx ).to.deep.equal {}

    it 'should keep everything in context if the sub expressions do match', ->
      ctx = {}

      expect(parser.all ctx, [
        [ parser.label, 'l1', parser.literal, 'h' ]
        [ parser.all, [ [ parser.label, 'l2', parser.literal, 'e' ] ] ]
      ])
        .to.deep.equal new Result [ 'h', [ 'e' ] ]

      expect( ctx ).to.deep.equal l1: 'h', l2: 'e'

      expect( ctx.l1 ).to.deep.equal 'h'
      expect( ctx.l2 ).to.deep.equal 'e'

  describe '#check()', ->

    it 'should try and match the given sub-expression without consuming any input', ->
      expect( parser.check {}, parser.literal, 'h'     ).to.deep.equal new Result()
      expect( parser.check {}, parser.literal, 'h'     ).to.deep.equal new Result()
      expect( parser.check {}, parser.literal, 'e'     ).to.deep.equal false
      expect( parser.check {}, parser.literal, 'h'     ).to.deep.equal new Result()
      expect( parser.check {}, parser.regex, /^hello / ).to.deep.equal new Result()
      expect( parser.check {}, parser.regex, /^world/  ).to.deep.equal false

    it 'should remember labels if the expression matches', ->
      ctx = {}

      expect( parser.check ctx, parser.label, 'l1', parser.literal, 'h' ).to.deep.equal new Result()
      expect( ctx ).to.deep.equal l1: 'h'

    it 'should not remember labels if the expression does not match', ->
      ctx = {}

      expect( parser.check ctx, parser.label, 'l1', parser.literal, 'e' ).to.deep.equal false
      expect( ctx ).to.deep.equal {}

  describe '#reject()', ->

    it 'should try and reject the given sub-expression without consuming any input', ->
      expect( parser.reject {}, parser.literal, 'h'     ).to.deep.equal false
      expect( parser.reject {}, parser.literal, 'h'     ).to.deep.equal false
      expect( parser.reject {}, parser.literal, 'e'     ).to.deep.equal new Result()
      expect( parser.reject {}, parser.literal, 'h'     ).to.deep.equal false
      expect( parser.reject {}, parser.regex, /^hello / ).to.deep.equal false
      expect( parser.reject {}, parser.regex, /^world/  ).to.deep.equal new Result()

  describe '#label()', ->

    it 'should remember the sub-expression result if it matches', ->
      ctx = {}

      expect( parser.label ctx, 'l1', parser.literal, 'h' ).to.deep.equal new Result 'h'
      expect( ctx ).to.deep.equal l1: 'h'

      expect( parser.label ctx, 'l2', parser.literal, 'h' ).to.deep.equal false
      expect( ctx ).to.deep.equal l1: 'h'

  describe '#action()', ->

    it 'should record labelled expressions and pass them to the action', ->
      parser.action {}, parser.label, 'label', parser.literal, 'h', ({label}) ->
        expect( label ).to.equal 'h'

    it 'should return the result of the callback as the result of the expression', ->
      expect( parser.action {}, parser.literal, 'h', -> 'override' ).to.deep.equal new Result 'override'

    it 'should isolate context from siblings', ->
      ctx = null

      parser.all {}, [
        [ parser.action, parser.label, 'l1', parser.literal, 'h', -> ]
        [ parser.action, parser.label, 'l2', parser.literal, 'e', (o) -> ctx = o ]
      ]
      expect( ctx ).to.deep.equal '$$': 'e', l2: 'e'

    it 'should isolate context from children', ->
      ctx = null

      child  = [ parser.action, parser.label, 'l2', parser.literal, 'e', (o) -> ctx = o ]
      parent = [ parser.all, [ [ parser.label, 'l1', parser.literal, 'h' ], child ] ]
      parser.action {}, parent..., ->

      expect( ctx ).to.deep.equal '$$': 'e', l2: 'e'

    it 'should not isolate context from parents', ->
      ctx = null

      child  = [ parser.action, parser.label, 'l2', parser.literal, 'e', -> ]
      parent = [ parser.all, [ [ parser.label, 'l1', parser.literal, 'h' ], child ] ]
      parser.action {}, parent..., (o) -> ctx = o

      expect( ctx ).to.deep.equal '$$': [ 'h' ], l1: 'h', l2: 'e'

  describe '#token()', ->

    it 'should match the given sub-expression and return an empty result', ->
      expect( parser.token {}, parser.literal, 'hello' ).to.deep.equal new Result()
      expect( parser.token {}, parser.literal, 'hello' ).to.deep.equal false
      expect( parser.token {}, parser.regex, /\sworld/ ).to.deep.equal new Result()

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
        expect( parser.parse "'hello\\'"       ).to.be.false
        expect( parser.parse "'hello\\'world'" ).to.be.ok

        expect( parser.parse '"hello world"'   ).to.deep.equal 'hello world'
        expect( parser.parse '"hello\\"'       ).to.be.false
        expect( parser.parse '"hello\\"world"' ).to.be.ok