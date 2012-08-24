Parser = require './parser'

module.exports = class PegCoffeeParser extends Parser

  ###
  Namespace for node classes.
  ###
  nodes:

    ###
    Encapsulates a node in a grammar's AST.
    ###
    AstNode: class AstNode

    ###
    Encapsulates a Grammar (root) node in a grammar AST.
    ###
    GrammarNode: class GrammarNode extends AstNode

  ###
  Matches the given sub-expression and returns an empty result.
  ###
  token: (expression, args...) ->
    if expression.apply @, args
      new @Result()
    else
      false

  ###
  Matches an indent followed by two spaces.
  ###
  DOUBLE_INDENT: ->
    @token @all, [
      @INDENT
      @SPACE
      @SPACE
    ]

  ###
  Matches a single indent (a newline followed by two space).
  ###
  INDENT: ->
    @token @all, [
      @NEWLINE
      @SPACE
      @SPACE
    ]

  ###
  Matches a single whitespace character (newline or space).
  ###
  WHITESPACE: ->
    @token @any, [
      @NEWLINE
      @SPACE
    ]

  ###
  Matches a single CR/LF newline.
  ###
  NEWLINE: ->
    @token @any, [
      [ @all, [
        [ @literal, '\r' ]
        [ @maybe, @literal, '\n' ]
      ] ]
      [ @literal, '\n' ]
    ]

  ###
  Matches a single space.
  ###
  SPACE: ->
    @token @literal, ' '

  ###
  The initial parsing expression to apply when `parse` is called.
  ###
  Start: @::Grammar