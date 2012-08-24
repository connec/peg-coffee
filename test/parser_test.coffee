{expect} = require 'chai'
Parser   = require '../src/lib/parser'

describe 'Parser', ->

  describe '#constructor()', ->

    it 'should return a new Parser instance', ->
      expect(new Parser).to.be.an.instanceof Parser

    it 'should mix-in any given values', ->
      parser = new Parser ParsingExpression: 'hello'
      expect(parser.ParsingExpression).to.equal 'hello'

      parser = new Parser input: 'hello'
      expect(parser.input).to.equal 'hello'

  describe '#position', ->

    it 'should return the parser\'s position in the input', ->
      parser = new Parser input: 'hello'

      expect( parser.position ).to.equal 0

      parser.literal 'he'
      expect( parser.position ).to.equal 2

      parser.literal 'llo'
      expect( parser.position ).to.equal 5

  describe '#reset()', ->

    it 'should set the parser\'s position back to 0', ->
      parser = new Parser input: 'hello'

      parser.literal 'he'
      expect( parser.position ).to.equal 2

      parser.reset()
      expect( parser.position ).to.equal 0

  describe 'parse functions', ->

    parser = null

    beforeEach ->
      parser = new Parser input: 'hello world'

    describe '#literal()', ->

      it 'should match and return the given parameter', ->
        expect( parser.literal 'he' ).to.deep.equal { value: 'he' }
        expect( parser.literal 'l'  ).to.deep.equal { value: 'l' }
        expect( parser.literal 'o'  ).to.deep.equal false

        parser.input = ''
        expect( parser.literal '.' ).to.equal false

    describe '#regex()', ->

      it 'should match the given regular expression and return the overall match', ->
        expect( parser.regex /^./      ).to.deep.equal { value: 'h' }
        expect( parser.regex /^.*?\s/  ).to.deep.equal { value: 'ello ' }
        expect( parser.regex /^\s/     ).to.deep.equal false
        expect( parser.regex /^world/  ).to.deep.equal { value: 'world' }
        expect( parser.regex /./       ).to.deep.equal false

    describe '#maybe()', ->

      it 'should match the given expression and return the result of the expression or a null value', ->
        expect( parser.maybe parser.literal, 'he' ).to.deep.equal { value: 'he' }
        expect( parser.maybe parser.literal, 'he' ).to.deep.equal { value: null }
        expect( parser.maybe parser.regex, /^./   ).to.deep.equal { value: 'l' }

    describe '#maybe_some()', ->

      it 'should match the given expression as many times as possible and return an array of matches', ->
        expect( parser.maybe_some parser.literal, 'h'   ).to.deep.equal { value: [ 'h' ] }
        expect( parser.maybe_some parser.literal, 'n'   ).to.deep.equal { value: [] }
        expect( parser.maybe_some parser.regex, /^[^ ]/ ).to.deep.equal { value: [ 'e', 'l', 'l', 'o' ] }
        expect( parser.maybe_some parser.regex, /^[^ ]/ ).to.deep.equal { value: [] }

    describe '#some()', ->

      it 'should match the given expression at least once and as many times as possible and return an array of matches', ->
        expect( parser.some parser.literal, 'h'   ).to.deep.equal { value: [ 'h' ] }
        expect( parser.some parser.literal, 'n'   ).to.deep.equal false
        expect( parser.some parser.regex, /^[^ ]/ ).to.deep.equal { value: [ 'e', 'l', 'l', 'o' ] }
        expect( parser.some parser.regex, /^[^ ]/ ).to.deep.equal false

    describe '#any()', ->

      it 'should match one of the given sub expression and return the result', ->
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.literal, 'n'   ] ] ).to.deep.equal { value: 'h' }
        expect( parser.any [ [ parser.literal, 'n'   ], [ parser.literal, 'e'   ] ] ).to.deep.equal { value: 'e' }
        expect( parser.any [ [ parser.regex, /^ll/   ], [ parser.regex, /^l/    ] ] ).to.deep.equal { value: 'll' }
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.regex, /^[^o]/ ] ] ).to.deep.equal false
        expect( parser.any [ [ parser.literal, 'h'   ], [ parser.regex, /^./    ] ] ).to.deep.equal { value: 'o' }
        expect( parser.any [ (-> @maybe @literal, 'n'), [ parser.regex, /^./    ] ] ).to.deep.equal { value: null }

    describe '#all()', ->

      it 'should match all the given sub expression and return an array of the results', ->
        expect( parser.all [ [ parser.literal, 'h'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal { value: [ 'h', 'e' ] }
        expect( parser.all [ [ parser.literal, 'n'   ], [ parser.literal, 'e'    ] ] ).to.deep.equal false
        expect( parser.all [ [ parser.regex, /^l/    ], [ parser.regex, /^l/     ] ] ).to.deep.equal { value: [ 'l', 'l' ] }
        expect( parser.all [ [ parser.literal, 'o'   ], [ parser.regex, /^[^o]/  ] ] ).to.deep.equal { value: [ 'o', ' ' ] }
        expect( parser.all [ (-> @maybe @literal, ' '), [ parser.regex, /^./     ] ] ).to.deep.equal { value: [ null, 'w' ] }

    describe '#check()', ->

      it 'should try and match the given sub-expression without consuming any input', ->
        expect( parser.check parser.literal, 'h'     ).to.deep.equal { value: null }
        expect( parser.check parser.literal, 'h'     ).to.deep.equal { value: null }
        expect( parser.check parser.literal, 'e'     ).to.deep.equal false
        expect( parser.check parser.literal, 'h'     ).to.deep.equal { value: null }
        expect( parser.check parser.regex, /^hello / ).to.deep.equal { value: null }
        expect( parser.check parser.regex, /^world/  ).to.deep.equal false

    describe '#reject()', ->

      it 'should try and reject the given sub-expression without consuming any input', ->
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.literal, 'e'     ).to.deep.equal { value: null }
        expect( parser.reject parser.literal, 'h'     ).to.deep.equal false
        expect( parser.reject parser.regex, /^hello / ).to.deep.equal false
        expect( parser.reject parser.regex, /^world/  ).to.deep.equal { value: null }

  describe 'more complex parsing expressions', ->

    describe 'string syntax', ->

      it 'should match valid strings and reject invalid strings', ->
        ###
        String:
          "'" ( ( '\\\\' / !"'" ) . )* "'"
        / '"' ( ( '\\\\' / !'"' ) . )* '"'
        ###
        parser = new Parser String: -> @any [
          [ @all, [
            [ @literal, "'" ]
            [ @maybe_some, @all, [
              [ @any, [
                [ @literal, '\\' ]
                [ @reject, @literal, "'" ]
              ] ]
              [ @regex, /^./ ]
            ] ]
            [ @literal, "'" ]
          ] ]
          [ @all, [
            [ @literal, '"' ]
            [ @maybe_some, @all, [
              [ @any, [
                [ @literal, '\\' ]
                [ @reject, @literal, '"' ]
              ] ]
              [ @regex, /^./ ]
            ] ]
            [ @literal, '"' ]
          ] ]
        ]

        expect( parser.parse "'hello world'" ).to.deep.equal { value: [
          "'"
          [
            [ null, 'h' ], [ null, 'e' ], [ null, 'l' ], [ null, 'l' ], [ null, 'o' ], [ null, ' ' ]
            [ null, 'w' ], [ null, 'o' ], [ null, 'r' ], [ null, 'l' ], [ null, 'd' ]
          ]
          "'"
        ] }
        expect( parser.parse "'hello\\'"       ).to.be.false
        expect( parser.parse "'hello\\'world'" ).to.be.ok

        expect( parser.parse '"hello world"' ).to.deep.equal { value: [
          '"'
          [
            [ null, 'h' ], [ null, 'e' ], [ null, 'l' ], [ null, 'l' ], [ null, 'o' ], [ null, ' ' ]
            [ null, 'w' ], [ null, 'o' ], [ null, 'r' ], [ null, 'l' ], [ null, 'd' ]
          ]
          '"'
        ] }
        expect( parser.parse '"hello\\"'       ).to.be.false
        expect( parser.parse '"hello\\"world"' ).to.be.ok