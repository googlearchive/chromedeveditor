/*
 * Copyright 2013 The Polymer Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

(function() {

function reflect(element, name, meta) {
  return {
    obj: element,
    name: name,
    value: element[name],
    meta: meta && meta[name]
  };
}

function reflectProperty(element, name, meta) {
  try {
    if (name[0] === '_' || name[name.length-1] === '_') {
      return;
    }
    var v = element[name];
    if (((v !== null
        && v !== undefined
        && typeof v !== 'function'
        && typeof v !== 'object')
        || Bindings.getBinding(element, name))
        //&& element.propertyIsEnumerable(k)
        && !reflectProperty.blacklist[name]) {
      var prop = reflect(element, name, meta);
    }
  } catch(x) {
    // squelch
  }
  return prop;
}

reflectProperty.blacklist = {
  EVENT_PREFIX: 1, 
  DELEGATES: 1, 
  PUBLISHED: 1,
  INSTANCE_ATTRIBUTES: 1, 
  PolymerBase: 1, 
  STYLE_SCOPE_ATTRIBUTE: 1
};

if (!window.designWindow) {
  designWindow = window;
}

var defaultMeta = {
  id: {},
  className: {kind: 'classname-editor'}
}

function reflectProperties(element) {
  var props = [];
  if (element) {
    var found = {};
    var meta = element._designMeta && element._designMeta.properties;
    meta = Platform.mixin({}, defaultMeta, meta);

    var hep = designWindow.HTMLElement.prototype;
    var hiep = designWindow.HTMLInputElement.prototype;
    // TODO(sjmiles): beware alternate-window `p` that will != window.HTMLElement.prototype
    var p = element.__proto__;
    while (p && !p.hasOwnProperty('PolymerBase') && p != hep && p != hiep) {
      var k = Object.keys(p);
      k.forEach(function(k) {
        if (found[k]) {
          return;
        }
        var prop = reflectProperty(element, k, meta);
        if (prop) {
          props.push(prop);
          found[k] = true;
        }
      });
      p = p.__proto__;
    }
    //
    var more = [];
    if (!element.firstElementChild) {
      more.push('textContent');
    }
    var whitelist = {};
    //
    meta && Object.keys(meta).forEach(function(n) {
      if (!found[n] && more.indexOf(n) === -1) {
        more.push(n);
        whitelist[n] = true;
      }
    });
    //
    more.forEach(function(k) {
      var v = element[k];
      if ((typeof v !== 'function' && typeof v !== 'object') || whitelist[k]) {
        props.push(reflect(element, k, meta));
      }
    });
  }
  return props;
}

function reflectObject(obj, meta) {
  var props = [];
  if (obj && meta) {
    Object.keys(meta).forEach(function(name) {
      props.push(reflect(obj, name, meta));
    });
  }
  return props;
}

function reflectObjectProperties(obj) {
  var props = [];
  if (obj) {
    Object.keys(obj).forEach(function(name) {
      var p = reflectProperty(obj, name, {});
      if (p) {
        props.push(p);
      }
    });
  }
  return props;
}

function reflectStyles(element, meta) {
  if (element) {
    var style = element.__styleRule ? element.__styleRule.style : element.style;
    return reflectObject(style, meta);
  }
}

window.Reflection = {
  properties: reflectProperties,
  styles: reflectStyles,
  object: reflectObject,
  objectProperties: reflectObjectProperties
};

})();
