'use strict'

exports.merge = (target, src) ->
  target[k] = v for k, v of src
  target