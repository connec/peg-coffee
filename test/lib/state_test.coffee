describe 'state', ->
  state = require '../../src/lib/state'

  describe 'from_string', ->
    from_string = null

    beforeEach ->
      from_string = state.from_string

    it 'returns a valid state', ->
      s = from_string ''

      expect(s).to.have.property('name').that.is.a 'string'
      expect(s).to.have.property('next').that.is.a 'function'
      expect(s).to.have.property('get_context').that.is.a 'function'

    it 'has the given name, with initial line and column', ->
      s = from_string '', name: 'test'

      expect(s.name).to.equal 'test:1:1'

    it 'has the default name, when none given, with initial line and column', ->
      s = from_string ''

      expect(s.name).to.equal '<string>:1:1'

    describe '#next()', ->
      it 'yields the first character and subsequent state', ->
        s = from_string 'hello'
        next = s.next()

        expect(next.element).to.equal 'h'
        expect(next.state).to.be.an 'object'
        expect(next.state.next().element).to.equal 'e'

    describe '#get_context()', ->
      it 'returns the first line with the first character marked', ->
        s = from_string 'hello\nworld'
        context = s.get_context()

        expect(context).to.equal '''
          hello
          ^
        '''
