/*
 * @license
 * Copyright (c) 2014 The Polymer Project Authors. All rights reserved.
 * This code may only be used under the BSD style license found at http://polymer.github.io/LICENSE.txt
 * The complete set of authors may be found at http://polymer.github.io/AUTHORS.txt
 * The complete set of contributors may be found at http://polymer.github.io/CONTRIBUTORS.txt
 * Code distributed by Google as part of the polymer project is also
 * subject to an additional IP rights grant found at http://polymer.github.io/PATENTS.txt
 */

#!/usr/bin/env node

var fs = require('fs');
var cheerio = require('cheerio');
var path = require('path');

var cheerioOptions = {xmlMode: true};
var files = process.argv.slice(2);

function read(file, name) {
  var content = fs.readFileSync(file, 'utf8');
  // replace SVGIDs with icon name
  content = content.replace(/SVGID/g, name);
  return cheerio.load(content, cheerioOptions);
}

function transmogrify($, name) {
  var node = $('svg');
  var innerHTML = $.xml(node.children());
  // remove extraneous whitespace
  innerHTML = innerHTML.replace(/\t|\r|\n/g, '');
  var output = '<g id="' + name + '">' + innerHTML + '</g>';
  // print icon svg
  console.log(output);
}

function path2IconName(file) {
  parts = path.basename(file, '.svg').split('-');
  parts.pop();
  return parts.join('-');
}
[
  '<link rel="import" href="../core-iconset-svg/core-iconset-svg.html">',
  '<core-iconset-svg id="category-icons" iconSize="256">',
  '<svg><defs>'
].forEach(function(l) {
  console.log(l);
});
files.forEach(function(file) {
  var name = path2IconName(file);
  var $ = read(file, name);
  transmogrify($, name);
});
console.log('</defs></svg></core-iconset-svg>');
