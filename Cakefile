path   = require 'path'
{spawn} = require 'child_process'

task 'test', "Runs the project's tests on the source", ->
  args = [
    path.join 'node_modules', 'mocha', 'bin', 'mocha'
    '--compilers', 'coffee:coffee-script'
  ]
  spawn process.execPath, args, { customFds: [ 0, 1, 2 ] }

task 'test:watch', "Watches the project's source and reruns tests on changes", ->
  args = [
    path.join 'node_modules', 'mocha', 'bin', 'mocha'
    '--compilers', 'coffee:coffee-script'
    '--watch'
  ]
  spawn process.execPath, args, { customFds: [ 0, 1, 2 ] }