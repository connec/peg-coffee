{ expect }      = require 'chai'
fs              = require 'fs'
path            = require 'path'
PegCoffeeParser = require '../../src/lib/peg_coffee_parser'
Result          = PegCoffeeParser::Result

describe 'PegCoffeeParser', ->

  parser = null

  reset_parser = (input) ->
    parser._reset()
    parser.input = input

  beforeEach ->
    parser = new PegCoffeeParser

  describe 'integration', ->

    describe 'the peg-coffee grammar', ->

      it 'should be able to parse its own grammar', ->
        result = parser.parse fs.readFileSync path.join(path.dirname(__filename), '../support/sample.peg-coffee'), 'utf8'
        expect( result ).to.deep.equal require '../support/sample-parsed'

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
        expect( parser.Class() ).to.deep.equal new Result 'a-z'

        reset_parser '[a-z\\]'
        expect( parser.Class() ).to.be.false

        reset_parser '[a-z\\]]'
        expect( parser.Class() ).to.deep.equal new Result 'a-z]'

    describe '#String()', ->

      it 'should match a single-quoted string', ->
        reset_parser "'hello world'"
        expect( parser.String() ).to.deep.equal new Result 'hello world'

        reset_parser "'hello\\'world\"'"
        expect( parser.String() ).to.deep.equal new Result 'hello\'world"'

        reset_parser "'hello\\'"
        expect( parser.String() ).to.be.false

      it 'should match a double-quoted string', ->
        reset_parser '"hello world"'
        expect( parser.String() ).to.deep.equal new Result 'hello world'

        reset_parser '"hello\\"world\'"'
        expect( parser.String() ).to.deep.equal new Result "hello\"world'"

        reset_parser '"hello\\"'
        expect( parser.String() ).to.be.false

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

    describe '#Code()', ->

      it 'should match inline code', ->
        reset_parser '-> console.log "hi"\n'
        expect( parser.Code() ).to.deep.equal new Result 'console.log "hi"'
        expect( parser.input[parser.position..] ).to.equal '\n'

      it 'should match double indented code', ->
        reset_parser '->\n    console.log "hi"\n'
        expect( parser.Code() ).to.deep.equal new Result 'console.log "hi"'
        expect( parser.input[parser.position..] ).to.equal '\n'

        reset_parser '->\n    console.log "hi"\n  \n    console.log "world"\n'
        expect( parser.Code() ).to.deep.equal new Result 'console.log "hi"\n\nconsole.log "world"'
        expect( parser.input[parser.position..] ).to.equal '\n'

        reset_parser '->\n   console.log "hi"\n'
        expect( parser.Code() ).to.be.false

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
        expect( parser.Primary() ).to.deep.equal new Result type: 'rule', name: 'HelloWorld'

        reset_parser 'HELLO_WORLD'
        expect( parser.Primary() ).to.deep.equal new Result type: 'rule', name: 'HELLO_WORLD'

        reset_parser 'hELLO_WORLD'
        expect( parser.Primary() ).to.be.false

      it 'should match a String', ->
        reset_parser "'hello world'"
        expect( parser.Primary() ).to.deep.equal new Result type: 'literal', content: 'hello world'

        reset_parser '"hello\\"world\'"'
        expect( parser.Primary() ).to.deep.equal new Result type: 'literal', content: "hello\"world'"

        reset_parser "'hello\\'"
        expect( parser.Primary() ).to.be.false

      it 'should match a character class', ->
        reset_parser '[a-z]'
        expect( parser.Primary() ).to.deep.equal new Result type: 'class', content: 'a-z'

        reset_parser '[a-z\\]'
        expect( parser.Primary() ).to.be.false

        reset_parser '[a-z\\]]'
        expect( parser.Primary() ).to.deep.equal new Result type: 'class', content: 'a-z]'

      it 'should match a dot wildcard', ->
        reset_parser '..'
        expect( parser.Primary() ).to.deep.equal new Result type: 'wildcard'
        expect( parser.Primary() ).to.deep.equal new Result type: 'wildcard'
        expect( parser.Primary() ).to.be.false

      it 'should match a tilde', ->
        reset_parser '~~'
        expect( parser.Primary() ).to.deep.equal new Result type: 'pass'
        expect( parser.Primary() ).to.deep.equal new Result type: 'pass'
        expect( parser.Primary() ).to.be.false

    describe '#Single()', ->

      beforeEach ->
        # For testing purposes, an expression is a literal 'hello world'
        parser.Expression = parser.Primary

      it 'should match a primary with an optional label, prefix and/or suffix', ->
        reset_parser 'label:&(~)+'
        expect( parser.Single() ).to.deep.equal new Result
          type:   'pass'
          label:  'label'
          prefix: '&'
          suffix: '+'

        reset_parser '!"hello world"'
        expect( parser.Single() ).to.deep.equal new Result
          type:    'literal'
          prefix:  '!'
          content: 'hello world'

        reset_parser 'all_the_things:.*'
        expect( parser.Single() ).to.deep.equal new Result
          type:   'wildcard'
          label:  'all_the_things'
          suffix: '*'

    describe '#Sequence()', ->

      beforeEach ->
        # For testing purposes, an expression is a literal 'hello world'
        parser.Expression = parser.Expression

      it 'should match a single Single', ->
        reset_parser 'label:&(~)+'
        expect( parser.Sequence() ).to.deep.equal new Result
          type:   'pass'
          label:  'label'
          prefix: '&'
          suffix: '+'

        reset_parser '!"hello world"'
        expect( parser.Sequence() ).to.deep.equal new Result
          type:    'literal'
          prefix:  '!'
          content: 'hello world'

        reset_parser 'all_the_things:.*'
        expect( parser.Sequence() ).to.deep.equal new Result
          type:   'wildcard'
          label:  'all_the_things'
          suffix: '*'

      it 'should match a sequence of Singles delimited by some spaces', ->
        reset_parser '!"hello world"   all_the_things:.*'
        expect( parser.Sequence() ).to.deep.equal new Result
          type:    'sequence'
          content: [
            {
              type:    'literal'
              prefix:  '!'
              content: 'hello world'
            }
            {
              type:   'wildcard'
              label:  'all_the_things'
              suffix: '*'
            }
          ]

    describe '#Expression()', ->

      it 'should match a Sequence', ->
        reset_parser 'label:&~+'
        expect( parser.Expression() ).to.deep.equal new Result
          type:   'pass'
          label:  'label'
          prefix: '&'
          suffix: '+'

        reset_parser '!"hello world"   all_the_things:.*'
        expect( parser.Expression() ).to.deep.equal new Result
          type:    'sequence'
          content: [
            {
              type:    'literal'
              prefix:  '!'
              content: 'hello world'
            }
            {
              type:   'wildcard'
              label:  'all_the_things'
              suffix: '*'
            }
          ]

      it 'should match a number of Sequences delimited by /', ->
        reset_parser 'label:&~+ / !"hello world"   all_the_things:.*'
        expect( parser.Expression() ).to.deep.equal new Result
          type:    'choice'
          content: [
            {
              type:   'pass'
              label:  'label'
              prefix: '&'
              suffix: '+'
            }
            {
              type:    'sequence'
              content: [
                {
                  type:    'literal'
                  prefix:  '!'
                  content: 'hello world'
                }
                {
                  type:   'wildcard'
                  label:  'all_the_things'
                  suffix: '*'
                }
              ]
            }
          ]

    describe '#RuleLine()', ->

      it 'should match an expression', ->
        reset_parser 'label:&~+ / !"hello world"   all_the_things:.*'
        expect( parser.RuleLine() ).to.deep.equal new Result
          type:    'choice'
          content: [
            {
              type:   'pass'
              label:  'label'
              prefix: '&'
              suffix: '+'
            }
            {
              type:    'sequence'
              content: [
                {
                  type:    'literal'
                  prefix:  '!'
                  content: 'hello world'
                }
                {
                  type:   'wildcard'
                  label:  'all_the_things'
                  suffix: '*'
                }
              ]
            }
          ]

      it 'should match an expression followed by some inline code', ->
        reset_parser 'label:( [A-Z] [a-z]* ) -> console.log "hello world"'
        expect( parser.RuleLine() ).to.deep.equal new Result
          type:    'sequence'
          label:   'label'
          action:  'console.log "hello world"'
          content: [
            {
              type:    'class'
              content: 'A-Z'
            }
            {
              type:    'class'
              suffix:  '*'
              content: 'a-z'
            }
          ]

      it 'should match an expression followed by a block of code', ->
        reset_parser '''
          head:Rule tail:Rule* ->
              if tail.length is 0
                head
              else
                [ head ].concat tail
        '''
        expect( parser.RuleLine() ).to.deep.equal new Result
          type:   'sequence'
          action: '''
            if tail.length is 0
              head
            else
              [ head ].concat tail
          '''
          content: [
            {
              type:  'rule'
              label: 'head'
              name:  'Rule'
            }
            {
              type:   'rule'
              label:  'tail'
              suffix: '*'
              name:   'Rule'
            }
          ]

    describe '#RuleContest()', ->

      it 'should match an indent followed by a single RuleLine', ->
        reset_parser 'label:( [A-Z] [a-z]* ) -> console.log "hello world"'
        expect( parser.RuleContent() ).to.deep.equal new Result
          type:    'sequence'
          label:   'label'
          action:  'console.log "hello world"'
          content: [
            {
              type:    'class'
              content: 'A-Z'
            }
            {
              type:    'class'
              suffix:  '*'
              content: 'a-z'
            }
          ]

      it 'should match multiple RuleLines delimited by \'\\n/ \'', ->
        reset_parser '''
          content:( !NEWLINE . )* -> console.log content
          / head:Rule tail:Rule*  ->
              if tail.length is 0
                head
              else
                [ head ].concat tail
        '''
        expect( parser.RuleContent() ).to.deep.equal new Result
          type:    'choice'
          content: [
            {
              type:    'sequence'
              label:   'content'
              suffix:  '*'
              action:  'console.log content'
              content: [
                {
                  type:   'rule'
                  name:   'NEWLINE'
                  prefix: '!'
                }
                {
                  type: 'wildcard'
                }
              ]
            }
            {
              type:   'sequence'
              action: '''
                if tail.length is 0
                  head
                else
                  [ head ].concat tail
              '''
              content: [
                {
                  type:  'rule'
                  label: 'head'
                  name:  'Rule'
                }
                {
                  type:   'rule'
                  label:  'tail'
                  suffix: '*'
                  name:   'Rule'
                }
              ]
            }
          ]

    describe '#Rule()', ->

      it 'should match a rule definition', ->
        reset_parser '''
          Rule:
            content:( !NEWLINE . )* -> console.log content
          / head:Rule tail:Rule*    ->
              if tail.length is 0
                head
              else
                [ head ].concat tail
        '''
        expect( parser.Rule() ).to.deep.equal new Result
          type: 'definition'
          name: 'Rule'
          content:
            type:    'choice'
            content: [
              {
                type:    'sequence'
                label:   'content'
                suffix:  '*'
                action:  'console.log content'
                content: [
                  {
                    type:   'rule'
                    name:   'NEWLINE'
                    prefix: '!'
                  }
                  {
                    type: 'wildcard'
                  }
                ]
              }
              {
                type:   'sequence'
                action: '''
                  if tail.length is 0
                    head
                  else
                    [ head ].concat tail
                '''
                content: [
                  {
                    type:  'rule'
                    label: 'head'
                    name:  'Rule'
                  }
                  {
                    type:   'rule'
                    label:  'tail'
                    suffix: '*'
                    name:   'Rule'
                  }
                ]
              }
            ]

      it 'should match preceeding comments', ->
        reset_parser '''
          # Some rule.
          Rule:
            'a'
        '''
        expect( parser.Rule() ).to.deep.equal new Result
          type:     'definition'
          name:     'Rule'
          comments: [ 'Some rule.' ]
          content:
            type:    'literal'
            content: 'a'

    describe '#Grammar()', ->

      it 'should match a number of rules', ->
        expect( parser.parse '''
          A:
            b:C*

          D:
            !E 'f'
        ''' ).to.deep.equal new Result
          type:    'grammar'
          content: [
            {
              type: 'definition'
              name: 'A'
              content:
                type:   'rule'
                name:   'C'
                label:  'b'
                suffix: '*'
            }
            {
              type: 'definition'
              name: 'D'
              content:
                type:    'sequence'
                content: [
                  {
                    type:   'rule'
                    name:   'E'
                    prefix: '!'
                  }
                  {
                    type:    'literal'
                    content: 'f'
                  }
                ]
            }
          ]