path   = require 'path'
{spawn} = require 'child_process'

mocha_args = [
  path.join 'node_modules', 'mocha', 'bin', 'mocha'
  '-R', 'spec'
  '--recursive'
  '--compilers', 'coffee:coffee-script'
]

task 'test', "Runs the project's tests on the source", ->
  spawn process.execPath, mocha_args, { customFds: [ 0, 1, 2 ] }

task 'test:watch', "Watches the project's source and reruns tests on changes", ->
  spawn process.execPath, mocha_args.concat([ '--watch' ]), { customFds: [ 0, 1, 2 ] }