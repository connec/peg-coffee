(function() {
  'use strict';
  exports.merge = function(target, src) {
    var k, v;
    for (k in src) {
      v = src[k];
      target[k] = v;
    }
    return target;
  };

}).call(this);
