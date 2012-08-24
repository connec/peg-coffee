{expect} = require 'chai'
Parser   = require '../src/lib/parser'
Result   = Parser::Result

describe 'Parser', ->

  parser = null

  beforeEach ->
    parser = new Parser

  describe '#constructor()', ->

    it 'should return a new Parser instance', ->
      expect( new Parser ).to.be.an.instanceof Parser

    it 'should store a clone any given options', ->
      options =
        option1: 'value1'
        option2: 'value2'
      parser = new Parser options
      expect( parser.options ).to.deep.equal { option1: 'value1', option2: 'value2' }
      expect( parser.options ).not.to.equal options

  describe 'parse functions', ->

    beforeEach ->
      parser.input = 'hello world'

    describe '#literal()', ->

      it 'should match and return the given parameter', ->
        expect( parser.literal 'he' ).to.deep.equal new Result 'he'
        expect( parser.literal 'l'  ).to.deep.equal new Result 'l'
        expect( parser.literal 'o'  ).to.deep.equal false

        parser.input = ''
        expect( parser.literal '.' ).to.equal false

    describe '#regex()', ->

      it 'should match the given regular expression and return the overall match', ->
        expect( parser.regex /^./      ).to.deep.equal new Result 'h'
        expect( parser.regex /^.*?\s/  ).to.deep.equal new Result 'ello '
        expect( parser.regex /^\s/     ).to.deep.equal false
        expect( parser.regex /^world/  ).to.deep.equal new Result 'world'
        expect( parser.regex /./       ).to.deep.equal false

    describe '#maybe()', ->

      it 'should match the given expression and return the result of the expression or a null value', ->
        expect( parser.maybe parser.literal, 'he' ).to.deep.equal new Result 'he'
        expect( parser.maybe parser.literal, 'he' ).to.deep.equal new Result null
        expect( parser.maybe parser.regex, /^./   ).to.deep.equal new Result 'l'

    describe '#maybe_some()', ->

      it 'should match the given expression as many times as possible and return an array of matches', ->
        expect( parser.maybe_some parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
        expect( parser.maybe_some parser.literal, 'n'   ).to.deep.equal new Result []
        expect( parser.maybe_some parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
        expect( parser.maybe_some parser.regex, /^[^ ]/ ).to.deep.equal new Result []

    describe '#some()', ->

      it 'should match the given expression at least once and as many times as possible and return an array of matches', ->
        expect( parser.some parser.literal, 'h'   ).to.deep.equal new Result [ 'h' ]
        expect( parser.some parser.literal, 'n'   ).to.deep.equal false
        expect( parser.some parser.regex, /^[^ ]/ ).to.deep.equal new Result [ 'e', 'l', 'l', 'o' ]
        expect( parser.some parser.regex, /^[^ ]/ ).to.deep.equal false

    describe '#any()', ->

      it 'should match one of the given sub expression and return the result', ->
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.literal, 'n'   ] ] ).to.deep.equal new Result 'h'
        expect( parser.any [ [ parser.literal, 'n'   ], [ parser.literal, 'e'   ] ] ).to.deep.equal new Result 'e'
        expect( parser.any [ [ parser.regex, /^ll/   ], [ parser.regex, /^l/    ] ] ).to.deep.equal new Result 'll'
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.regex, /^[^o]/ ] ] ).to.deep.equal false
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.regex, /^./    ] ] ).to.deep.equal new Result 'o'
        expect( parser.any [ (-> @maybe @literal, 'n'), [ parser.regex, /^./    ] ] ).to.deep.equal new Result null

    describe '#all()', ->

      it 'should match all the given sub expression and return an array of the results', ->
        expect( parser.all [ [ parser.literal, 'h'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal new Result [ 'h' , 'e' ]
        expect( parser.all [ [ parser.literal, 'n'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal false
        expect( parser.all [ [ parser.regex, /^l/    ], [ parser.regex, /^l/     ] ] ).to.deep.equal new Result [ 'l' , 'l' ]
        expect( parser.all [ [ parser.literal, 'o'   ], [ parser.regex, /^[^o]/  ] ] ).to.deep.equal new Result [ 'o' , ' ' ]
        expect( parser.all [ (-> @maybe @literal, ' '), [ parser.regex, /^./     ] ] ).to.deep.equal new Result [ null, 'w' ]

    describe '#check()', ->

      it 'should try and match the given sub-expression without consuming any input', ->
        expect( parser.check parser.literal, 'h'     ).to.deep.equal new Result null
        expect( parser.check parser.literal, 'h'     ).to.deep.equal new Result null
        expect( parser.check parser.literal, 'e'     ).to.deep.equal false
        expect( parser.check parser.literal, 'h'     ).to.deep.equal new Result null
        expect( parser.check parser.regex, /^hello / ).to.deep.equal new Result null
        expect( parser.check parser.regex, /^world/  ).to.deep.equal false

    describe '#reject()', ->

      it 'should try and reject the given sub-expression without consuming any input', ->
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.literal, 'e'     ).to.deep.equal new Result null
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.regex, /^hello / ).to.deep.equal false
        expect( parser.reject parser.regex, /^world/  ).to.deep.equal new Result null

    describe '#label() and #action()', ->

      it 'should record labelled expressions and pass them to the action', ->
        expect(
          parser.action parser.label, 'label', parser.literal, 'h', ({label}) ->
            expect( label ).to.equal 'h'
            'override'
        ).to.deep.equal new Result 'override'

    describe '(integration)', ->

      describe 'string syntax', ->

        it 'should match valid strings and reject invalid strings', ->
          # String:
          #   "'" string:( ( '\\\\' / !"'" ) . )* "'" -> @join string
          # / '"' string:( ( '\\\\' / !'"' ) . )* '"' -> @join string
          parser.Start = -> @any [
            [ @action, @all, [
              [ @literal, "'" ]
              [ @label, 'string', @maybe_some, @all, [
                [ @any, [
                  [ @literal, '\\' ]
                  [ @reject, @literal, "'" ]
                ] ]
                [ @regex, /^./ ]
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
                [ @regex, /^./ ]
              ] ]
              [ @literal, '"' ]
            ], ({string}) -> @join string ]
          ]

          expect( parser.parse "'hello world'" ).to.deep.equal new Result 'hello world'
          expect( parser.parse "'hello\\'"       ).to.be.false
          expect( parser.parse "'hello\\'world'" ).to.be.ok

          expect( parser.parse '"hello world"' ).to.deep.equal new Result 'hello world'
          expect( parser.parse '"hello\\"'       ).to.be.false
          expect( parser.parse '"hello\\"world"' ).to.be.ok