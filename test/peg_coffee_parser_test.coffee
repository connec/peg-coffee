{expect}        = require 'chai'
PegCoffeeParser = require '../src/lib/peg_coffee_parser'
Result          = PegCoffeeParser::Result

describe 'PegCoffeeParser', ->

  parser = null

  reset_parser = (input) ->
    parser._reset()
    parser.input = input

  beforeEach ->
    parser = new PegCoffeeParser

  describe '#SPACE()', ->

    it 'should match a single space, and return nothing', ->
      reset_parser '  '
      expect( parser.SPACE() ).to.deep.equal new Result()
      expect( parser.SPACE() ).to.deep.equal new Result()
      expect( parser.SPACE() ).to.deep.equal false

      reset_parser 'hello'
      expect( parser.SPACE() ).to.deep.equal false

      reset_parser ''
      expect( parser.SPACE() ).to.deep.equal false

  describe '#NEWLINE()', ->

    it 'should match a single CR/LF newline', ->
      reset_parser '\r\n\n\r'
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser '\r\n\r\n'
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser '\n\r\n\r\n'
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser '''

        hello
      '''
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser 'hello\n'
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser ''
      expect( parser.NEWLINE() ).to.deep.equal false

  describe '#WHITESPACE()', ->

    it 'should match a single whitespace character', ->
      reset_parser '  '
      expect( parser.SPACE() ).to.deep.equal new Result()
      expect( parser.SPACE() ).to.deep.equal new Result()
      expect( parser.SPACE() ).to.deep.equal false

      reset_parser '\r\n\r\n'
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal new Result()
      expect( parser.NEWLINE() ).to.deep.equal false

      reset_parser ' \r\n '
      expect( parser.WHITESPACE() ).to.deep.equal new Result()
      expect( parser.WHITESPACE() ).to.deep.equal new Result()
      expect( parser.WHITESPACE() ).to.deep.equal new Result()
      expect( parser.WHITESPACE() ).to.deep.equal false

      reset_parser ' hello\n'
      expect( parser.WHITESPACE() ).to.deep.equal new Result()
      expect( parser.WHITESPACE() ).to.deep.equal false

      reset_parser ''
      expect( parser.WHITESPACE() ).to.deep.equal false

  describe '#INDENT()', ->

    it 'should match a newline followed by two spaces', ->
      reset_parser '\n  '
      expect( parser.INDENT() ).to.deep.equal new Result()

      reset_parser '\n  hello'
      expect( parser.INDENT() ).to.deep.equal new Result()

      reset_parser '\n '
      expect( parser.INDENT() ).to.deep.equal false

      reset_parser ' \n  '
      expect( parser.INDENT() ).to.deep.equal false

  describe '#DOUBLE_INDENT()', ->

    it 'should match an indent followed by two spaces', ->
      reset_parser '\n    '
      expect( parser.DOUBLE_INDENT() ).to.deep.equal new Result()

      reset_parser '\n    hello'
      expect( parser.DOUBLE_INDENT() ).to.deep.equal new Result()

      reset_parser '\n  '
      expect( parser.DOUBLE_INDENT() ).to.deep.equal false

      reset_parser ' \n    '
      expect( parser.DOUBLE_INDENT() ).to.deep.equal false