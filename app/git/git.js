(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
        //Allow using this built library as an AMD module
        //in another project. That other project will only
        //see this AMD call, not the internal modules in
        //the closure below.
        define(factory);
    } else {
        //Browser globals case. Just assign the
        //result to a property on the global.
        root.GitApi = factory();
    }
}(this, function () {
/**
 * almond 0.2.5 Copyright (c) 2011-2012, The Dojo Foundation All Rights Reserved.
 * Available via the MIT or new BSD license.
 * see: http://github.com/jrburke/almond for details
 */
//Going sloppy to avoid 'use strict' string cost, but strict practices should
//be followed.
/*jslint sloppy: true */
/*global setTimeout: false */

var requirejs, require, define;
(function (undef) {
    var main, req, makeMap, handlers,
        defined = {},
        waiting = {},
        config = {},
        defining = {},
        hasOwn = Object.prototype.hasOwnProperty,
        aps = [].slice;

    function hasProp(obj, prop) {
        return hasOwn.call(obj, prop);
    }

    /**
     * Given a relative module name, like ./something, normalize it to
     * a real name that can be mapped to a path.
     * @param {String} name the relative name
     * @param {String} baseName a real name that the name arg is relative
     * to.
     * @returns {String} normalized name
     */
    function normalize(name, baseName) {
        var nameParts, nameSegment, mapValue, foundMap,
            foundI, foundStarMap, starI, i, j, part,
            baseParts = baseName && baseName.split("/"),
            map = config.map,
            starMap = (map && map['*']) || {};

        //Adjust any relative paths.
        if (name && name.charAt(0) === ".") {
            //If have a base name, try to normalize against it,
            //otherwise, assume it is a top-level require that will
            //be relative to baseUrl in the end.
            if (baseName) {
                //Convert baseName to array, and lop off the last part,
                //so that . matches that "directory" and not name of the baseName's
                //module. For instance, baseName of "one/two/three", maps to
                //"one/two/three.js", but we want the directory, "one/two" for
                //this normalization.
                baseParts = baseParts.slice(0, baseParts.length - 1);

                name = baseParts.concat(name.split("/"));

                //start trimDots
                for (i = 0; i < name.length; i += 1) {
                    part = name[i];
                    if (part === ".") {
                        name.splice(i, 1);
                        i -= 1;
                    } else if (part === "..") {
                        if (i === 1 && (name[2] === '..' || name[0] === '..')) {
                            //End of the line. Keep at least one non-dot
                            //path segment at the front so it can be mapped
                            //correctly to disk. Otherwise, there is likely
                            //no path mapping for a path starting with '..'.
                            //This can still fail, but catches the most reasonable
                            //uses of ..
                            break;
                        } else if (i > 0) {
                            name.splice(i - 1, 2);
                            i -= 2;
                        }
                    }
                }
                //end trimDots

                name = name.join("/");
            } else if (name.indexOf('./') === 0) {
                // No baseName, so this is ID is resolved relative
                // to baseUrl, pull off the leading dot.
                name = name.substring(2);
            }
        }

        //Apply map config if available.
        if ((baseParts || starMap) && map) {
            nameParts = name.split('/');

            for (i = nameParts.length; i > 0; i -= 1) {
                nameSegment = nameParts.slice(0, i).join("/");

                if (baseParts) {
                    //Find the longest baseName segment match in the config.
                    //So, do joins on the biggest to smallest lengths of baseParts.
                    for (j = baseParts.length; j > 0; j -= 1) {
                        mapValue = map[baseParts.slice(0, j).join('/')];

                        //baseName segment has  config, find if it has one for
                        //this name.
                        if (mapValue) {
                            mapValue = mapValue[nameSegment];
                            if (mapValue) {
                                //Match, update name to the new value.
                                foundMap = mapValue;
                                foundI = i;
                                break;
                            }
                        }
                    }
                }

                if (foundMap) {
                    break;
                }

                //Check for a star map match, but just hold on to it,
                //if there is a shorter segment match later in a matching
                //config, then favor over this star map.
                if (!foundStarMap && starMap && starMap[nameSegment]) {
                    foundStarMap = starMap[nameSegment];
                    starI = i;
                }
            }

            if (!foundMap && foundStarMap) {
                foundMap = foundStarMap;
                foundI = starI;
            }

            if (foundMap) {
                nameParts.splice(0, foundI, foundMap);
                name = nameParts.join('/');
            }
        }

        return name;
    }

    function makeRequire(relName, forceSync) {
        return function () {
            //A version of a require function that passes a moduleName
            //value for items that may need to
            //look up paths relative to the moduleName
            return req.apply(undef, aps.call(arguments, 0).concat([relName, forceSync]));
        };
    }

    function makeNormalize(relName) {
        return function (name) {
            return normalize(name, relName);
        };
    }

    function makeLoad(depName) {
        return function (value) {
            defined[depName] = value;
        };
    }

    function callDep(name) {
        if (hasProp(waiting, name)) {
            var args = waiting[name];
            delete waiting[name];
            defining[name] = true;
            main.apply(undef, args);
        }

        if (!hasProp(defined, name) && !hasProp(defining, name)) {
            throw new Error('No ' + name);
        }
        return defined[name];
    }

    //Turns a plugin!resource to [plugin, resource]
    //with the plugin being undefined if the name
    //did not have a plugin prefix.
    function splitPrefix(name) {
        var prefix,
            index = name ? name.indexOf('!') : -1;
        if (index > -1) {
            prefix = name.substring(0, index);
            name = name.substring(index + 1, name.length);
        }
        return [prefix, name];
    }

    /**
     * Makes a name map, normalizing the name, and using a plugin
     * for normalization if necessary. Grabs a ref to plugin
     * too, as an optimization.
     */
    makeMap = function (name, relName) {
        var plugin,
            parts = splitPrefix(name),
            prefix = parts[0];

        name = parts[1];

        if (prefix) {
            prefix = normalize(prefix, relName);
            plugin = callDep(prefix);
        }

        //Normalize according
        if (prefix) {
            if (plugin && plugin.normalize) {
                name = plugin.normalize(name, makeNormalize(relName));
            } else {
                name = normalize(name, relName);
            }
        } else {
            name = normalize(name, relName);
            parts = splitPrefix(name);
            prefix = parts[0];
            name = parts[1];
            if (prefix) {
                plugin = callDep(prefix);
            }
        }

        //Using ridiculous property names for space reasons
        return {
            f: prefix ? prefix + '!' + name : name, //fullName
            n: name,
            pr: prefix,
            p: plugin
        };
    };

    function makeConfig(name) {
        return function () {
            return (config && config.config && config.config[name]) || {};
        };
    }

    handlers = {
        require: function (name) {
            return makeRequire(name);
        },
        exports: function (name) {
            var e = defined[name];
            if (typeof e !== 'undefined') {
                return e;
            } else {
                return (defined[name] = {});
            }
        },
        module: function (name) {
            return {
                id: name,
                uri: '',
                exports: defined[name],
                config: makeConfig(name)
            };
        }
    };

    main = function (name, deps, callback, relName) {
        var cjsModule, depName, ret, map, i,
            args = [],
            usingExports;

        //Use name if no relName
        relName = relName || name;

        //Call the callback to define the module, if necessary.
        if (typeof callback === 'function') {

            //Pull out the defined dependencies and pass the ordered
            //values to the callback.
            //Default to [require, exports, module] if no deps
            deps = !deps.length && callback.length ? ['require', 'exports', 'module'] : deps;
            for (i = 0; i < deps.length; i += 1) {
                map = makeMap(deps[i], relName);
                depName = map.f;

                //Fast path CommonJS standard dependencies.
                if (depName === "require") {
                    args[i] = handlers.require(name);
                } else if (depName === "exports") {
                    //CommonJS module spec 1.1
                    args[i] = handlers.exports(name);
                    usingExports = true;
                } else if (depName === "module") {
                    //CommonJS module spec 1.1
                    cjsModule = args[i] = handlers.module(name);
                } else if (hasProp(defined, depName) ||
                           hasProp(waiting, depName) ||
                           hasProp(defining, depName)) {
                    args[i] = callDep(depName);
                } else if (map.p) {
                    map.p.load(map.n, makeRequire(relName, true), makeLoad(depName), {});
                    args[i] = defined[depName];
                } else {
                    throw new Error(name + ' missing ' + depName);
                }
            }

            ret = callback.apply(defined[name], args);

            if (name) {
                //If setting exports via "module" is in play,
                //favor that over return value and exports. After that,
                //favor a non-undefined return value over exports use.
                if (cjsModule && cjsModule.exports !== undef &&
                        cjsModule.exports !== defined[name]) {
                    defined[name] = cjsModule.exports;
                } else if (ret !== undef || !usingExports) {
                    //Use the return value from the function.
                    defined[name] = ret;
                }
            }
        } else if (name) {
            //May just be an object definition for the module. Only
            //worry about defining if have a module name.
            defined[name] = callback;
        }
    };

    requirejs = require = req = function (deps, callback, relName, forceSync, alt) {
        if (typeof deps === "string") {
            if (handlers[deps]) {
                //callback in this case is really relName
                return handlers[deps](callback);
            }
            //Just return the module wanted. In this scenario, the
            //deps arg is the module name, and second arg (if passed)
            //is just the relName.
            //Normalize module name, if it contains . or ..
            return callDep(makeMap(deps, callback).f);
        } else if (!deps.splice) {
            //deps is a config object, not an array.
            config = deps;
            if (callback.splice) {
                //callback is an array, which means it is a dependency list.
                //Adjust args if there are dependencies
                deps = callback;
                callback = relName;
                relName = null;
            } else {
                deps = undef;
            }
        }

        //Support require(['a'])
        callback = callback || function () {};

        //If relName is a function, it is an errback handler,
        //so remove it.
        if (typeof relName === 'function') {
            relName = forceSync;
            forceSync = alt;
        }

        //Simulate async callback;
        if (forceSync) {
            main(undef, deps, callback, relName);
        } else {
            //Using a non-zero value because of concern for what old browsers
            //do, and latest browsers "upgrade" to 4 if lower value is used:
            //http://www.whatwg.org/specs/web-apps/current-work/multipage/timers.html#dom-windowtimers-settimeout:
            //If want a value immediately, use require('id') instead -- something
            //that works in almond on the global level, but not guaranteed and
            //unlikely to work in other AMD implementations.
            setTimeout(function () {
                main(undef, deps, callback, relName);
            }, 4);
        }

        return req;
    };

    /**
     * Just drops the config on the floor, but returns req in case
     * the config return value is used.
     */
    req.config = function (cfg) {
        config = cfg;
        if (config.deps) {
            req(config.deps, config.callback);
        }
        return req;
    };

    define = function (name, deps, callback) {

        //This module may not have dependencies
        if (!deps.splice) {
            //deps is not an array, so probably means
            //an object literal or factory function for
            //the value. Adjust args.
            callback = deps;
            deps = [];
        }

        if (!hasProp(defined, name) && !hasProp(waiting, name)) {
            waiting[name] = [name, deps, callback];
        }
    };

    define.amd = {
        jQuery: true
    };
}());

define("thirdparty/almond", function(){});

/** @license zlib.js 2012 - imaya [ https://github.com/imaya/zlib.js ] The MIT License */
(function() {var COMPILED = !0, goog = goog || {};
goog.global = this;
goog.DEBUG = !1;
goog.LOCALE = "en";
goog.provide = function(a) {
  if(!COMPILED) {
    if(goog.isProvided_(a)) {
      throw Error('Namespace "' + a + '" already declared.');
    }
    delete goog.implicitNamespaces_[a];
    for(var b = a;(b = b.substring(0, b.lastIndexOf("."))) && !goog.getObjectByName(b);) {
      goog.implicitNamespaces_[b] = !0
    }
  }
  goog.exportPath_(a)
};
goog.setTestOnly = function(a) {
  if(COMPILED && !goog.DEBUG) {
    throw a = a || "", Error("Importing test-only code into non-debug environment" + a ? ": " + a : ".");
  }
};
COMPILED || (goog.isProvided_ = function(a) {
  return!goog.implicitNamespaces_[a] && !!goog.getObjectByName(a)
}, goog.implicitNamespaces_ = {});
goog.exportPath_ = function(a, b, c) {
  a = a.split(".");
  c = c || goog.global;
  !(a[0] in c) && c.execScript && c.execScript("var " + a[0]);
  for(var d;a.length && (d = a.shift());) {
    !a.length && goog.isDef(b) ? c[d] = b : c = c[d] ? c[d] : c[d] = {}
  }
};
goog.getObjectByName = function(a, b) {
  for(var c = a.split("."), d = b || goog.global, e;e = c.shift();) {
    if(goog.isDefAndNotNull(d[e])) {
      d = d[e]
    }else {
      return null
    }
  }
  return d
};
goog.globalize = function(a, b) {
  var c = b || goog.global, d;
  for(d in a) {
    c[d] = a[d]
  }
};
goog.addDependency = function(a, b, c) {
  if(!COMPILED) {
    for(var d, a = a.replace(/\\/g, "/"), e = goog.dependencies_, f = 0;d = b[f];f++) {
      e.nameToPath[d] = a, a in e.pathToNames || (e.pathToNames[a] = {}), e.pathToNames[a][d] = !0
    }
    for(d = 0;b = c[d];d++) {
      a in e.requires || (e.requires[a] = {}), e.requires[a][b] = !0
    }
  }
};
goog.ENABLE_DEBUG_LOADER = !0;
goog.require = function(a) {
  if(!COMPILED && !goog.isProvided_(a)) {
    if(goog.ENABLE_DEBUG_LOADER) {
      var b = goog.getPathFromDeps_(a);
      if(b) {
        goog.included_[b] = !0;
        goog.writeScripts_();
        return
      }
    }
    a = "goog.require could not find: " + a;
    goog.global.console && goog.global.console.error(a);
    throw Error(a);
  }
};
goog.basePath = "";
goog.nullFunction = function() {
};
goog.identityFunction = function(a) {
  return a
};
goog.abstractMethod = function() {
  throw Error("unimplemented abstract method");
};
goog.addSingletonGetter = function(a) {
  a.getInstance = function() {
    if(a.instance_) {
      return a.instance_
    }
    goog.DEBUG && (goog.instantiatedSingletons_[goog.instantiatedSingletons_.length] = a);
    return a.instance_ = new a
  }
};
goog.instantiatedSingletons_ = [];
!COMPILED && goog.ENABLE_DEBUG_LOADER && (goog.included_ = {}, goog.dependencies_ = {pathToNames:{}, nameToPath:{}, requires:{}, visited:{}, written:{}}, goog.inHtmlDocument_ = function() {
  var a = goog.global.document;
  return"undefined" != typeof a && "write" in a
}, goog.findBasePath_ = function() {
  if(goog.global.CLOSURE_BASE_PATH) {
    goog.basePath = goog.global.CLOSURE_BASE_PATH
  }else {
    if(goog.inHtmlDocument_()) {
      for(var a = goog.global.document.getElementsByTagName("script"), b = a.length - 1;0 <= b;--b) {
        var c = a[b].src, d = c.lastIndexOf("?"), d = -1 == d ? c.length : d;
        if("base.js" == c.substr(d - 7, 7)) {
          goog.basePath = c.substr(0, d - 7);
          break
        }
      }
    }
  }
}, goog.importScript_ = function(a) {
  var b = goog.global.CLOSURE_IMPORT_SCRIPT || goog.writeScriptTag_;
  !goog.dependencies_.written[a] && b(a) && (goog.dependencies_.written[a] = !0)
}, goog.writeScriptTag_ = function(a) {
  return goog.inHtmlDocument_() ? (goog.global.document.write('<script type="text/javascript" src="' + a + '"><\/script>'), !0) : !1
}, goog.writeScripts_ = function() {
  function a(e) {
    if(!(e in d.written)) {
      if(!(e in d.visited) && (d.visited[e] = !0, e in d.requires)) {
        for(var g in d.requires[e]) {
          if(!goog.isProvided_(g)) {
            if(g in d.nameToPath) {
              a(d.nameToPath[g])
            }else {
              throw Error("Undefined nameToPath for " + g);
            }
          }
        }
      }
      e in c || (c[e] = !0, b.push(e))
    }
  }
  var b = [], c = {}, d = goog.dependencies_, e;
  for(e in goog.included_) {
    d.written[e] || a(e)
  }
  for(e = 0;e < b.length;e++) {
    if(b[e]) {
      goog.importScript_(goog.basePath + b[e])
    }else {
      throw Error("Undefined script input");
    }
  }
}, goog.getPathFromDeps_ = function(a) {
  return a in goog.dependencies_.nameToPath ? goog.dependencies_.nameToPath[a] : null
}, goog.findBasePath_(), goog.global.CLOSURE_NO_DEPS || goog.importScript_(goog.basePath + "deps.js"));
goog.typeOf = function(a) {
  var b = typeof a;
  if("object" == b) {
    if(a) {
      if(a instanceof Array) {
        return"array"
      }
      if(a instanceof Object) {
        return b
      }
      var c = Object.prototype.toString.call(a);
      if("[object Window]" == c) {
        return"object"
      }
      if("[object Array]" == c || "number" == typeof a.length && "undefined" != typeof a.splice && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("splice")) {
        return"array"
      }
      if("[object Function]" == c || "undefined" != typeof a.call && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("call")) {
        return"function"
      }
    }else {
      return"null"
    }
  }else {
    if("function" == b && "undefined" == typeof a.call) {
      return"object"
    }
  }
  return b
};
goog.isDef = function(a) {
  return void 0 !== a
};
goog.isNull = function(a) {
  return null === a
};
goog.isDefAndNotNull = function(a) {
  return null != a
};
goog.isArray = function(a) {
  return"array" == goog.typeOf(a)
};
goog.isArrayLike = function(a) {
  var b = goog.typeOf(a);
  return"array" == b || "object" == b && "number" == typeof a.length
};
goog.isDateLike = function(a) {
  return goog.isObject(a) && "function" == typeof a.getFullYear
};
goog.isString = function(a) {
  return"string" == typeof a
};
goog.isBoolean = function(a) {
  return"boolean" == typeof a
};
goog.isNumber = function(a) {
  return"number" == typeof a
};
goog.isFunction = function(a) {
  return"function" == goog.typeOf(a)
};
goog.isObject = function(a) {
  var b = typeof a;
  return"object" == b && null != a || "function" == b
};
goog.getUid = function(a) {
  return a[goog.UID_PROPERTY_] || (a[goog.UID_PROPERTY_] = ++goog.uidCounter_)
};
goog.removeUid = function(a) {
  "removeAttribute" in a && a.removeAttribute(goog.UID_PROPERTY_);
  try {
    delete a[goog.UID_PROPERTY_]
  }catch(b) {
  }
};
goog.UID_PROPERTY_ = "closure_uid_" + Math.floor(2147483648 * Math.random()).toString(36);
goog.uidCounter_ = 0;
goog.getHashCode = goog.getUid;
goog.removeHashCode = goog.removeUid;
goog.cloneObject = function(a) {
  var b = goog.typeOf(a);
  if("object" == b || "array" == b) {
    if(a.clone) {
      return a.clone()
    }
    var b = "array" == b ? [] : {}, c;
    for(c in a) {
      b[c] = goog.cloneObject(a[c])
    }
    return b
  }
  return a
};
goog.bindNative_ = function(a, b, c) {
  return a.call.apply(a.bind, arguments)
};
goog.bindJs_ = function(a, b, c) {
  if(!a) {
    throw Error();
  }
  if(2 < arguments.length) {
    var d = Array.prototype.slice.call(arguments, 2);
    return function() {
      var c = Array.prototype.slice.call(arguments);
      Array.prototype.unshift.apply(c, d);
      return a.apply(b, c)
    }
  }
  return function() {
    return a.apply(b, arguments)
  }
};
goog.bind = function(a, b, c) {
  goog.bind = Function.prototype.bind && -1 != Function.prototype.bind.toString().indexOf("native code") ? goog.bindNative_ : goog.bindJs_;
  return goog.bind.apply(null, arguments)
};
goog.partial = function(a, b) {
  var c = Array.prototype.slice.call(arguments, 1);
  return function() {
    var b = Array.prototype.slice.call(arguments);
    b.unshift.apply(b, c);
    return a.apply(this, b)
  }
};
goog.mixin = function(a, b) {
  for(var c in b) {
    a[c] = b[c]
  }
};
goog.now = Date.now || function() {
  return+new Date
};
goog.globalEval = function(a) {
  if(goog.global.execScript) {
    goog.global.execScript(a, "JavaScript")
  }else {
    if(goog.global.eval) {
      if(null == goog.evalWorksForGlobals_ && (goog.global.eval("var _et_ = 1;"), "undefined" != typeof goog.global._et_ ? (delete goog.global._et_, goog.evalWorksForGlobals_ = !0) : goog.evalWorksForGlobals_ = !1), goog.evalWorksForGlobals_) {
        goog.global.eval(a)
      }else {
        var b = goog.global.document, c = b.createElement("script");
        c.type = "text/javascript";
        c.defer = !1;
        c.appendChild(b.createTextNode(a));
        b.body.appendChild(c);
        b.body.removeChild(c)
      }
    }else {
      throw Error("goog.globalEval not available");
    }
  }
};
goog.evalWorksForGlobals_ = null;
goog.getCssName = function(a, b) {
  var c = function(a) {
    return goog.cssNameMapping_[a] || a
  }, d = function(a) {
    for(var a = a.split("-"), b = [], d = 0;d < a.length;d++) {
      b.push(c(a[d]))
    }
    return b.join("-")
  }, d = goog.cssNameMapping_ ? "BY_WHOLE" == goog.cssNameMappingStyle_ ? c : d : function(a) {
    return a
  };
  return b ? a + "-" + d(b) : d(a)
};
goog.setCssNameMapping = function(a, b) {
  goog.cssNameMapping_ = a;
  goog.cssNameMappingStyle_ = b
};
!COMPILED && goog.global.CLOSURE_CSS_NAME_MAPPING && (goog.cssNameMapping_ = goog.global.CLOSURE_CSS_NAME_MAPPING);
goog.getMsg = function(a, b) {
  var c = b || {}, d;
  for(d in c) {
    var e = ("" + c[d]).replace(/\$/g, "$$$$"), a = a.replace(RegExp("\\{\\$" + d + "\\}", "gi"), e)
  }
  return a
};
goog.exportSymbol = function(a, b, c) {
  goog.exportPath_(a, b, c)
};
goog.exportProperty = function(a, b, c) {
  a[b] = c
};
goog.inherits = function(a, b) {
  function c() {
  }
  c.prototype = b.prototype;
  a.superClass_ = b.prototype;
  a.prototype = new c;
  a.prototype.constructor = a
};
goog.base = function(a, b, c) {
  var d = arguments.callee.caller;
  if(d.superClass_) {
    return d.superClass_.constructor.apply(a, Array.prototype.slice.call(arguments, 1))
  }
  for(var e = Array.prototype.slice.call(arguments, 2), f = !1, g = a.constructor;g;g = g.superClass_ && g.superClass_.constructor) {
    if(g.prototype[b] === d) {
      f = !0
    }else {
      if(f) {
        return g.prototype[b].apply(a, e)
      }
    }
  }
  if(a[b] === d) {
    return a.constructor.prototype[b].apply(a, e)
  }
  throw Error("goog.base called from a method of one name to a method of a different name");
};
goog.scope = function(a) {
  a.call(goog.global)
};
var USE_TYPEDARRAY = "undefined" !== typeof Uint8Array && "undefined" !== typeof Uint16Array && "undefined" !== typeof Uint32Array;
var Zlib = {BitStream:function(a, b) {
  this.index = "number" === typeof b ? b : 0;
  this.bitindex = 0;
  this.buffer = a instanceof (USE_TYPEDARRAY ? Uint8Array : Array) ? a : new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.BitStream.DefaultBlockSize);
  if(2 * this.buffer.length <= this.index) {
    throw Error("invalid index");
  }
  this.buffer.length <= this.index && this.expandBuffer()
}};
Zlib.BitStream.DefaultBlockSize = 32768;
Zlib.BitStream.prototype.expandBuffer = function() {
  var a = this.buffer, b, c = a.length, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(c << 1);
  if(USE_TYPEDARRAY) {
    d.set(a)
  }else {
    for(b = 0;b < c;++b) {
      d[b] = a[b]
    }
  }
  return this.buffer = d
};
Zlib.BitStream.prototype.writeBits = function(a, b, c) {
  var d = this.buffer, e = this.index, f = this.bitindex, g = d[e];
  c && 1 < b && (a = 8 < b ? (Zlib.BitStream.ReverseTable[a & 255] << 24 | Zlib.BitStream.ReverseTable[a >>> 8 & 255] << 16 | Zlib.BitStream.ReverseTable[a >>> 16 & 255] << 8 | Zlib.BitStream.ReverseTable[a >>> 24 & 255]) >> 32 - b : Zlib.BitStream.ReverseTable[a] >> 8 - b);
  if(8 > b + f) {
    g = g << b | a, f += b
  }else {
    for(c = 0;c < b;++c) {
      g = g << 1 | a >> b - c - 1 & 1, 8 === ++f && (f = 0, d[e++] = Zlib.BitStream.ReverseTable[g], g = 0, e === d.length && (d = this.expandBuffer()))
    }
  }
  d[e] = g;
  this.buffer = d;
  this.bitindex = f;
  this.index = e
};
Zlib.BitStream.prototype.finish = function() {
  var a = this.buffer, b = this.index;
  0 < this.bitindex && (a[b] <<= 8 - this.bitindex, a[b] = Zlib.BitStream.ReverseTable[a[b]], b++);
  USE_TYPEDARRAY ? a = a.subarray(0, b) : a.length = b;
  return a
};
Zlib.BitStream.ReverseTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(256), b;
  for(b = 0;256 > b;++b) {
    for(var c = a, d = b, e = b, f = e, g = 7, e = e >>> 1;e;e >>>= 1) {
      f <<= 1, f |= e & 1, --g
    }
    c[d] = (f << g & 255) >>> 0
  }
  return a
}());
Zlib.CRC32 = {};
Zlib.CRC32.calc = function(a, b, c) {
  return Zlib.CRC32.update(a, 0, b, c)
};
Zlib.CRC32.update = function(a, b, c, d) {
  for(var e = Zlib.CRC32.Table, f = "number" === typeof c ? c : c = 0, d = "number" === typeof d ? d : a.length, b = b ^ 4294967295, f = d & 7;f--;++c) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255]
  }
  for(f = d >> 3;f--;c += 8) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 1]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 2]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 3]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 4]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 5]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 6]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 7]) & 255]
  }
  return(b ^ 4294967295) >>> 0
};
Zlib.CRC32.Table = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}([0, 1996959894, 3993919788, 2567524794, 124634137, 1886057615, 3915621685, 2657392035, 249268274, 2044508324, 3772115230, 2547177864, 162941995, 2125561021, 3887607047, 2428444049, 498536548, 1789927666, 4089016648, 2227061214, 450548861, 1843258603, 4107580753, 2211677639, 325883990, 1684777152, 4251122042, 2321926636, 335633487, 1661365465, 4195302755, 2366115317, 997073096, 1281953886, 3579855332, 2724688242, 1006888145, 1258607687, 3524101629, 2768942443, 901097722, 1119000684, 3686517206, 
2898065728, 853044451, 1172266101, 3705015759, 2882616665, 651767980, 1373503546, 3369554304, 3218104598, 565507253, 1454621731, 3485111705, 3099436303, 671266974, 1594198024, 3322730930, 2970347812, 795835527, 1483230225, 3244367275, 3060149565, 1994146192, 31158534, 2563907772, 4023717930, 1907459465, 112637215, 2680153253, 3904427059, 2013776290, 251722036, 2517215374, 3775830040, 2137656763, 141376813, 2439277719, 3865271297, 1802195444, 476864866, 2238001368, 4066508878, 1812370925, 453092731, 
2181625025, 4111451223, 1706088902, 314042704, 2344532202, 4240017532, 1658658271, 366619977, 2362670323, 4224994405, 1303535960, 984961486, 2747007092, 3569037538, 1256170817, 1037604311, 2765210733, 3554079995, 1131014506, 879679996, 2909243462, 3663771856, 1141124467, 855842277, 2852801631, 3708648649, 1342533948, 654459306, 3188396048, 3373015174, 1466479909, 544179635, 3110523913, 3462522015, 1591671054, 702138776, 2966460450, 3352799412, 1504918807, 783551873, 3082640443, 3233442989, 3988292384, 
2596254646, 62317068, 1957810842, 3939845945, 2647816111, 81470997, 1943803523, 3814918930, 2489596804, 225274430, 2053790376, 3826175755, 2466906013, 167816743, 2097651377, 4027552580, 2265490386, 503444072, 1762050814, 4150417245, 2154129355, 426522225, 1852507879, 4275313526, 2312317920, 282753626, 1742555852, 4189708143, 2394877945, 397917763, 1622183637, 3604390888, 2714866558, 953729732, 1340076626, 3518719985, 2797360999, 1068828381, 1219638859, 3624741850, 2936675148, 906185462, 1090812512, 
3747672003, 2825379669, 829329135, 1181335161, 3412177804, 3160834842, 628085408, 1382605366, 3423369109, 3138078467, 570562233, 1426400815, 3317316542, 2998733608, 733239954, 1555261956, 3268935591, 3050360625, 752459403, 1541320221, 2607071920, 3965973030, 1969922972, 40735498, 2617837225, 3943577151, 1913087877, 83908371, 2512341634, 3803740692, 2075208622, 213261112, 2463272603, 3855990285, 2094854071, 198958881, 2262029012, 4057260610, 1759359992, 534414190, 2176718541, 4139329115, 1873836001, 
414664567, 2282248934, 4279200368, 1711684554, 285281116, 2405801727, 4167216745, 1634467795, 376229701, 2685067896, 3608007406, 1308918612, 956543938, 2808555105, 3495958263, 1231636301, 1047427035, 2932959818, 3654703836, 1088359270, 936918E3, 2847714899, 3736837829, 1202900863, 817233897, 3183342108, 3401237130, 1404277552, 615818150, 3134207493, 3453421203, 1423857449, 601450431, 3009837614, 3294710456, 1567103746, 711928724, 3020668471, 3272380065, 1510334235, 755167117]);
Zlib.exportObject = function(a, b) {
  var c, d, e, f;
  if(Object.keys) {
    c = Object.keys(b)
  }else {
    for(d in c = [], e = 0, b) {
      c[e++] = d
    }
  }
  e = 0;
  for(f = c.length;e < f;++e) {
    d = c[e], goog.exportSymbol(a + "." + d, b[d])
  }
};
Zlib.GunzipMember = function() {
};
Zlib.GunzipMember.prototype.getName = function() {
  return this.name
};
Zlib.GunzipMember.prototype.getData = function() {
  return this.data
};
Zlib.GunzipMember.prototype.getMtime = function() {
  return this.mtime
};
Zlib.Heap = function(a) {
  this.buffer = new (USE_TYPEDARRAY ? Uint16Array : Array)(2 * a);
  this.length = 0
};
Zlib.Heap.prototype.getParent = function(a) {
  return 2 * ((a - 2) / 4 | 0)
};
Zlib.Heap.prototype.getChild = function(a) {
  return 2 * a + 2
};
Zlib.Heap.prototype.push = function(a, b) {
  var c, d, e = this.buffer, f;
  c = this.length;
  e[this.length++] = b;
  for(e[this.length++] = a;0 < c;) {
    if(d = this.getParent(c), e[c] > e[d]) {
      f = e[c], e[c] = e[d], e[d] = f, f = e[c + 1], e[c + 1] = e[d + 1], e[d + 1] = f, c = d
    }else {
      break
    }
  }
  return this.length
};
Zlib.Heap.prototype.pop = function() {
  var a, b, c = this.buffer, d, e, f;
  b = c[0];
  a = c[1];
  this.length -= 2;
  c[0] = c[this.length];
  c[1] = c[this.length + 1];
  for(f = 0;;) {
    e = this.getChild(f);
    if(e >= this.length) {
      break
    }
    e + 2 < this.length && c[e + 2] > c[e] && (e += 2);
    if(c[e] > c[f]) {
      d = c[f], c[f] = c[e], c[e] = d, d = c[f + 1], c[f + 1] = c[e + 1], c[e + 1] = d
    }else {
      break
    }
    f = e
  }
  return{index:a, value:b, length:this.length}
};
Zlib.Huffman = {};
Zlib.Huffman.buildHuffmanTable = function(a) {
  var b = a.length, c = 0, d = Number.POSITIVE_INFINITY, e, f, g, h, i, j, l, m, k;
  for(m = 0;m < b;++m) {
    a[m] > c && (c = a[m]), a[m] < d && (d = a[m])
  }
  e = 1 << c;
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(e);
  g = 1;
  h = 0;
  for(i = 2;g <= c;) {
    for(m = 0;m < b;++m) {
      if(a[m] === g) {
        j = 0;
        l = h;
        for(k = 0;k < g;++k) {
          j = j << 1 | l & 1, l >>= 1
        }
        for(k = j;k < e;k += i) {
          f[k] = g << 16 | m
        }
        ++h
      }
    }
    ++g;
    h <<= 1;
    i <<= 1
  }
  return[f, c, d]
};
Zlib.RawDeflate = function(a, b) {
  this.compressionType = Zlib.RawDeflate.CompressionType.DYNAMIC;
  this.lazy = 0;
  this.input = a;
  this.op = 0;
  b && (b.lazy && (this.lazy = b.lazy), "number" === typeof b.compressionType && (this.compressionType = b.compressionType), b.outputBuffer && (this.output = USE_TYPEDARRAY && b.outputBuffer instanceof Array ? new Uint8Array(b.outputBuffer) : b.outputBuffer), "number" === typeof b.outputIndex && (this.op = b.outputIndex));
  this.output || (this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(32768))
};
Zlib.RawDeflate.CompressionType = {NONE:0, FIXED:1, DYNAMIC:2, RESERVED:3};
Zlib.RawDeflate.Lz77MinLength = 3;
Zlib.RawDeflate.Lz77MaxLength = 258;
Zlib.RawDeflate.WindowSize = 32768;
Zlib.RawDeflate.MaxCodeLength = 16;
Zlib.RawDeflate.HUFMAX = 286;
Zlib.RawDeflate.FixedHuffmanTable = function() {
  var a = [], b;
  for(b = 0;288 > b;b++) {
    switch(!0) {
      case 143 >= b:
        a.push([b + 48, 8]);
        break;
      case 255 >= b:
        a.push([b - 144 + 400, 9]);
        break;
      case 279 >= b:
        a.push([b - 256 + 0, 7]);
        break;
      case 287 >= b:
        a.push([b - 280 + 192, 8]);
        break;
      default:
        throw"invalid literal: " + b;
    }
  }
  return a
}();
Zlib.RawDeflate.prototype.compress = function() {
  var a, b, c, d = this.input;
  switch(this.compressionType) {
    case Zlib.RawDeflate.CompressionType.NONE:
      b = 0;
      for(c = d.length;b < c;) {
        a = USE_TYPEDARRAY ? d.subarray(b, b + 65535) : d.slice(b, b + 65535), b += a.length, this.makeNocompressBlock(a, b === c)
      }
      break;
    case Zlib.RawDeflate.CompressionType.FIXED:
      this.output = this.makeFixedHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    case Zlib.RawDeflate.CompressionType.DYNAMIC:
      this.output = this.makeDynamicHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    default:
      throw"invalid compression type";
  }
  return this.output
};
Zlib.RawDeflate.prototype.makeNocompressBlock = function(a, b) {
  var c, d, e = this.output, f = this.op;
  if(USE_TYPEDARRAY) {
    for(e = new Uint8Array(this.output.buffer);e.length <= f + a.length + 5;) {
      e = new Uint8Array(e.length << 1)
    }
    e.set(this.output)
  }
  c = Zlib.RawDeflate.CompressionType.NONE;
  e[f++] = (b ? 1 : 0) | c << 1;
  c = a.length;
  d = ~c + 65536 & 65535;
  e[f++] = c & 255;
  e[f++] = c >>> 8 & 255;
  e[f++] = d & 255;
  e[f++] = d >>> 8 & 255;
  if(USE_TYPEDARRAY) {
    e.set(a, f), f += a.length, e = e.subarray(0, f)
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      e[f++] = a[c]
    }
    e.length = f
  }
  this.op = f;
  return this.output = e
};
Zlib.RawDeflate.prototype.makeFixedHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output.buffer), this.op), d;
  d = Zlib.RawDeflate.CompressionType.FIXED;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  this.fixedHuffman(d, c);
  return c.finish()
};
Zlib.RawDeflate.prototype.makeDynamicHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output), this.op), d, e, f, g, h = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15], i, j, l, m, k, n, q = Array(19), p;
  d = Zlib.RawDeflate.CompressionType.DYNAMIC;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  i = this.getLengths_(this.freqsLitLen, 15);
  j = this.getCodesFromLengths_(i);
  l = this.getLengths_(this.freqsDist, 7);
  m = this.getCodesFromLengths_(l);
  for(e = 286;257 < e && 0 === i[e - 1];e--) {
  }
  for(f = 30;1 < f && 0 === l[f - 1];f--) {
  }
  k = this.getTreeSymbols_(e, i, f, l);
  n = this.getLengths_(k.freqs, 7);
  for(p = 0;19 > p;p++) {
    q[p] = n[h[p]]
  }
  for(g = 19;4 < g && 0 === q[g - 1];g--) {
  }
  h = this.getCodesFromLengths_(n);
  c.writeBits(e - 257, 5, !0);
  c.writeBits(f - 1, 5, !0);
  c.writeBits(g - 4, 4, !0);
  for(p = 0;p < g;p++) {
    c.writeBits(q[p], 3, !0)
  }
  p = 0;
  for(q = k.codes.length;p < q;p++) {
    if(e = k.codes[p], c.writeBits(h[e], n[e], !0), 16 <= e) {
      p++;
      switch(e) {
        case 16:
          e = 2;
          break;
        case 17:
          e = 3;
          break;
        case 18:
          e = 7;
          break;
        default:
          throw"invalid code: " + e;
      }
      c.writeBits(k.codes[p], e, !0)
    }
  }
  this.dynamicHuffman(d, [j, i], [m, l], c);
  return c.finish()
};
Zlib.RawDeflate.prototype.dynamicHuffman = function(a, b, c, d) {
  var e, f, g, h, i;
  g = b[0];
  b = b[1];
  h = c[0];
  i = c[1];
  c = 0;
  for(e = a.length;c < e;++c) {
    if(f = a[c], d.writeBits(g[f], b[f], !0), 256 < f) {
      d.writeBits(a[++c], a[++c], !0), f = a[++c], d.writeBits(h[f], i[f], !0), d.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === f) {
        break
      }
    }
  }
  return d
};
Zlib.RawDeflate.prototype.fixedHuffman = function(a, b) {
  var c, d, e;
  c = 0;
  for(d = a.length;c < d;c++) {
    if(e = a[c], Zlib.BitStream.prototype.writeBits.apply(b, Zlib.RawDeflate.FixedHuffmanTable[e]), 256 < e) {
      b.writeBits(a[++c], a[++c], !0), b.writeBits(a[++c], 5), b.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === e) {
        break
      }
    }
  }
  return b
};
Zlib.RawDeflate.Lz77Match = function(a, b) {
  this.length = a;
  this.backwardDistance = b
};
Zlib.RawDeflate.Lz77Match.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}(function() {
  function a(a) {
    switch(!0) {
      case 3 === a:
        return[257, a - 3, 0];
      case 4 === a:
        return[258, a - 4, 0];
      case 5 === a:
        return[259, a - 5, 0];
      case 6 === a:
        return[260, a - 6, 0];
      case 7 === a:
        return[261, a - 7, 0];
      case 8 === a:
        return[262, a - 8, 0];
      case 9 === a:
        return[263, a - 9, 0];
      case 10 === a:
        return[264, a - 10, 0];
      case 12 >= a:
        return[265, a - 11, 1];
      case 14 >= a:
        return[266, a - 13, 1];
      case 16 >= a:
        return[267, a - 15, 1];
      case 18 >= a:
        return[268, a - 17, 1];
      case 22 >= a:
        return[269, a - 19, 2];
      case 26 >= a:
        return[270, a - 23, 2];
      case 30 >= a:
        return[271, a - 27, 2];
      case 34 >= a:
        return[272, a - 31, 2];
      case 42 >= a:
        return[273, a - 35, 3];
      case 50 >= a:
        return[274, a - 43, 3];
      case 58 >= a:
        return[275, a - 51, 3];
      case 66 >= a:
        return[276, a - 59, 3];
      case 82 >= a:
        return[277, a - 67, 4];
      case 98 >= a:
        return[278, a - 83, 4];
      case 114 >= a:
        return[279, a - 99, 4];
      case 130 >= a:
        return[280, a - 115, 4];
      case 162 >= a:
        return[281, a - 131, 5];
      case 194 >= a:
        return[282, a - 163, 5];
      case 226 >= a:
        return[283, a - 195, 5];
      case 257 >= a:
        return[284, a - 227, 5];
      case 258 === a:
        return[285, a - 258, 0];
      default:
        throw"invalid length: " + a;
    }
  }
  var b = [], c, d;
  for(c = 3;258 >= c;c++) {
    d = a(c), b[c] = d[2] << 24 | d[1] << 16 | d[0]
  }
  return b
}());
Zlib.RawDeflate.Lz77Match.prototype.getDistanceCode_ = function(a) {
  switch(!0) {
    case 1 === a:
      a = [0, a - 1, 0];
      break;
    case 2 === a:
      a = [1, a - 2, 0];
      break;
    case 3 === a:
      a = [2, a - 3, 0];
      break;
    case 4 === a:
      a = [3, a - 4, 0];
      break;
    case 6 >= a:
      a = [4, a - 5, 1];
      break;
    case 8 >= a:
      a = [5, a - 7, 1];
      break;
    case 12 >= a:
      a = [6, a - 9, 2];
      break;
    case 16 >= a:
      a = [7, a - 13, 2];
      break;
    case 24 >= a:
      a = [8, a - 17, 3];
      break;
    case 32 >= a:
      a = [9, a - 25, 3];
      break;
    case 48 >= a:
      a = [10, a - 33, 4];
      break;
    case 64 >= a:
      a = [11, a - 49, 4];
      break;
    case 96 >= a:
      a = [12, a - 65, 5];
      break;
    case 128 >= a:
      a = [13, a - 97, 5];
      break;
    case 192 >= a:
      a = [14, a - 129, 6];
      break;
    case 256 >= a:
      a = [15, a - 193, 6];
      break;
    case 384 >= a:
      a = [16, a - 257, 7];
      break;
    case 512 >= a:
      a = [17, a - 385, 7];
      break;
    case 768 >= a:
      a = [18, a - 513, 8];
      break;
    case 1024 >= a:
      a = [19, a - 769, 8];
      break;
    case 1536 >= a:
      a = [20, a - 1025, 9];
      break;
    case 2048 >= a:
      a = [21, a - 1537, 9];
      break;
    case 3072 >= a:
      a = [22, a - 2049, 10];
      break;
    case 4096 >= a:
      a = [23, a - 3073, 10];
      break;
    case 6144 >= a:
      a = [24, a - 4097, 11];
      break;
    case 8192 >= a:
      a = [25, a - 6145, 11];
      break;
    case 12288 >= a:
      a = [26, a - 8193, 12];
      break;
    case 16384 >= a:
      a = [27, a - 12289, 12];
      break;
    case 24576 >= a:
      a = [28, a - 16385, 13];
      break;
    case 32768 >= a:
      a = [29, a - 24577, 13];
      break;
    default:
      throw"invalid distance";
  }
  return a
};
Zlib.RawDeflate.Lz77Match.prototype.toLz77Array = function() {
  var a = this.backwardDistance, b = [], c = 0, d;
  d = Zlib.RawDeflate.Lz77Match.LengthCodeTable[this.length];
  b[c++] = d & 65535;
  b[c++] = d >> 16 & 255;
  b[c++] = d >> 24;
  d = this.getDistanceCode_(a);
  b[c++] = d[0];
  b[c++] = d[1];
  b[c++] = d[2];
  return b
};
Zlib.RawDeflate.prototype.lz77 = function(a) {
  function b(a, b) {
    var c = a.toLz77Array(), d, e;
    d = 0;
    for(e = c.length;d < e;++d) {
      l[m++] = c[d]
    }
    n[c[0]]++;
    q[c[3]]++;
    k = a.length + b - 1;
    j = null
  }
  var c, d, e, f, g, h = {}, i = Zlib.RawDeflate.WindowSize, j, l = USE_TYPEDARRAY ? new Uint16Array(2 * a.length) : [], m = 0, k = 0, n = new (USE_TYPEDARRAY ? Uint32Array : Array)(286), q = new (USE_TYPEDARRAY ? Uint32Array : Array)(30), p = this.lazy;
  if(!USE_TYPEDARRAY) {
    for(e = 0;285 >= e;) {
      n[e++] = 0
    }
    for(e = 0;29 >= e;) {
      q[e++] = 0
    }
  }
  n[256] = 1;
  c = 0;
  for(d = a.length;c < d;++c) {
    e = g = 0;
    for(f = Zlib.RawDeflate.Lz77MinLength;e < f && c + e !== d;++e) {
      g = g << 8 | a[c + e]
    }
    void 0 === h[g] && (h[g] = []);
    e = h[g];
    if(!(0 < k--)) {
      for(;0 < e.length && c - e[0] > i;) {
        e.shift()
      }
      if(c + Zlib.RawDeflate.Lz77MinLength >= d) {
        j && b(j, -1);
        e = 0;
        for(f = d - c;e < f;++e) {
          g = a[c + e], l[m++] = g, ++n[g]
        }
        break
      }
      0 < e.length ? (f = this.searchLongestMatch_(a, c, e), j ? j.length < f.length ? (g = a[c - 1], l[m++] = g, ++n[g], b(f, 0)) : b(j, -1) : f.length < p ? j = f : b(f, 0)) : j ? b(j, -1) : (g = a[c], l[m++] = g, ++n[g])
    }
    e.push(c)
  }
  l[m++] = 256;
  n[256]++;
  this.freqsLitLen = n;
  this.freqsDist = q;
  return USE_TYPEDARRAY ? l.subarray(0, m) : l
};
Zlib.RawDeflate.prototype.searchLongestMatch_ = function(a, b, c) {
  var d, e, f = 0, g, h, i, j = a.length;
  h = 0;
  i = c.length;
  a:for(;h < i;h++) {
    d = c[i - h - 1];
    g = Zlib.RawDeflate.Lz77MinLength;
    if(f > Zlib.RawDeflate.Lz77MinLength) {
      for(g = f;g > Zlib.RawDeflate.Lz77MinLength;g--) {
        if(a[d + g - 1] !== a[b + g - 1]) {
          continue a
        }
      }
      g = f
    }
    for(;g < Zlib.RawDeflate.Lz77MaxLength && b + g < j && a[d + g] === a[b + g];) {
      ++g
    }
    g > f && (e = d, f = g);
    if(g === Zlib.RawDeflate.Lz77MaxLength) {
      break
    }
  }
  return new Zlib.RawDeflate.Lz77Match(f, b - e)
};
Zlib.RawDeflate.prototype.getTreeSymbols_ = function(a, b, c, d) {
  var e = new (USE_TYPEDARRAY ? Uint32Array : Array)(a + c), f, g, h = new (USE_TYPEDARRAY ? Uint32Array : Array)(316), i = new (USE_TYPEDARRAY ? Uint8Array : Array)(19);
  for(f = g = 0;f < a;f++) {
    e[g++] = b[f]
  }
  for(f = 0;f < c;f++) {
    e[g++] = d[f]
  }
  if(!USE_TYPEDARRAY) {
    f = 0;
    for(b = i.length;f < b;++f) {
      i[f] = 0
    }
  }
  f = c = 0;
  for(b = e.length;f < b;f += g) {
    for(g = 1;f + g < b && e[f + g] === e[f];++g) {
    }
    a = g;
    if(0 === e[f]) {
      if(3 > a) {
        for(;0 < a--;) {
          h[c++] = 0, i[0]++
        }
      }else {
        for(;0 < a;) {
          d = 138 > a ? a : 138, d > a - 3 && d < a && (d = a - 3), 10 >= d ? (h[c++] = 17, h[c++] = d - 3, i[17]++) : (h[c++] = 18, h[c++] = d - 11, i[18]++), a -= d
        }
      }
    }else {
      if(h[c++] = e[f], i[e[f]]++, a--, 3 > a) {
        for(;0 < a--;) {
          h[c++] = e[f], i[e[f]]++
        }
      }else {
        for(;0 < a;) {
          d = 6 > a ? a : 6, d > a - 3 && d < a && (d = a - 3), h[c++] = 16, h[c++] = d - 3, i[16]++, a -= d
        }
      }
    }
  }
  return{codes:USE_TYPEDARRAY ? h.subarray(0, c) : h.slice(0, c), freqs:i}
};
Zlib.RawDeflate.prototype.getLengths_ = function(a, b) {
  var c = a.length, d = new Zlib.Heap(2 * Zlib.RawDeflate.HUFMAX), e = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), f, g, h;
  if(!USE_TYPEDARRAY) {
    for(g = 0;g < c;g++) {
      e[g] = 0
    }
  }
  for(g = 0;g < c;++g) {
    0 < a[g] && d.push(g, a[g])
  }
  c = Array(d.length / 2);
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(d.length / 2);
  if(1 === c.length) {
    return e[d.pop().index] = 1, e
  }
  g = 0;
  for(h = d.length / 2;g < h;++g) {
    c[g] = d.pop(), f[g] = c[g].value
  }
  d = this.reversePackageMerge_(f, f.length, b);
  g = 0;
  for(h = c.length;g < h;++g) {
    e[c[g].index] = d[g]
  }
  return e
};
Zlib.RawDeflate.prototype.reversePackageMerge_ = function(a, b, c) {
  function d(a) {
    var c = i[a][j[a]];
    c === b ? (d(a + 1), d(a + 1)) : --g[c];
    ++j[a]
  }
  var e = new (USE_TYPEDARRAY ? Uint16Array : Array)(c), f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b), h = Array(c), i = Array(c), j = Array(c), l = (1 << c) - b, m = 1 << c - 1, k, n;
  e[c - 1] = b;
  for(k = 0;k < c;++k) {
    l < m ? f[k] = 0 : (f[k] = 1, l -= m), l <<= 1, e[c - 2 - k] = (e[c - 1 - k] / 2 | 0) + b
  }
  e[0] = f[0];
  h[0] = Array(e[0]);
  i[0] = Array(e[0]);
  for(k = 1;k < c;++k) {
    e[k] > 2 * e[k - 1] + f[k] && (e[k] = 2 * e[k - 1] + f[k]), h[k] = Array(e[k]), i[k] = Array(e[k])
  }
  for(l = 0;l < b;++l) {
    g[l] = c
  }
  for(m = 0;m < e[c - 1];++m) {
    h[c - 1][m] = a[m], i[c - 1][m] = m
  }
  for(l = 0;l < c;++l) {
    j[l] = 0
  }
  1 === f[c - 1] && (--g[0], ++j[c - 1]);
  for(k = c - 2;0 <= k;--k) {
    c = l = 0;
    n = j[k + 1];
    for(m = 0;m < e[k];m++) {
      c = h[k + 1][n] + h[k + 1][n + 1], c > a[l] ? (h[k][m] = c, i[k][m] = b, n += 2) : (h[k][m] = a[l], i[k][m] = l, ++l)
    }
    j[k] = 0;
    1 === f[k] && d(k)
  }
  return g
};
Zlib.RawDeflate.prototype.getCodesFromLengths_ = function(a) {
  var b = new (USE_TYPEDARRAY ? Uint16Array : Array)(a.length), c = [], d = [], e = 0, f, g, h;
  f = 0;
  for(g = a.length;f < g;f++) {
    c[a[f]] = (c[a[f]] | 0) + 1
  }
  f = 1;
  for(g = Zlib.RawDeflate.MaxCodeLength;f <= g;f++) {
    d[f] = e, e += c[f] | 0, e <<= 1
  }
  f = 0;
  for(g = a.length;f < g;f++) {
    e = d[a[f]];
    d[a[f]] += 1;
    c = b[f] = 0;
    for(h = a[f];c < h;c++) {
      b[f] = b[f] << 1 | e & 1, e >>>= 1
    }
  }
  return b
};
Zlib.Gzip = function(a, b) {
  this.input = a;
  this.op = this.ip = 0;
  this.flags = {};
  b && (b.flags && (this.flags = b.flags), "string" === typeof b.filename && (this.filename = b.filename), "string" === typeof b.comment && (this.comment = b.comment), b.deflateOptions && (this.deflateOptions = b.deflateOptions));
  this.deflateOptions || (this.deflateOptions = {})
};
Zlib.Gzip.DefaultBufferSize = 32768;
Zlib.Gzip.prototype.compress = function() {
  var a, b, c, d, e, f = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Gzip.DefaultBufferSize);
  c = 0;
  var g = this.input, h = this.ip;
  b = this.filename;
  var i = this.comment;
  f[c++] = 31;
  f[c++] = 139;
  f[c++] = 8;
  a = 0;
  this.flags.fname && (a |= Zlib.Gzip.FlagsMask.FNAME);
  this.flags.fcomment && (a |= Zlib.Gzip.FlagsMask.FCOMMENT);
  this.flags.fhcrc && (a |= Zlib.Gzip.FlagsMask.FHCRC);
  f[c++] = a;
  a = (Date.now ? Date.now() : +new Date) / 1E3 | 0;
  f[c++] = a & 255;
  f[c++] = a >>> 8 & 255;
  f[c++] = a >>> 16 & 255;
  f[c++] = a >>> 24 & 255;
  f[c++] = 0;
  f[c++] = Zlib.Gzip.OperatingSystem.UNKNOWN;
  if(void 0 !== this.flags.fname) {
    d = 0;
    for(e = b.length;d < e;++d) {
      a = b.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  if(this.flags.comment) {
    d = 0;
    for(e = i.length;d < e;++d) {
      a = i.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  this.flags.fhcrc && (b = Zlib.CRC32.calc(f, 0, c) & 65535, f[c++] = b & 255, f[c++] = b >>> 8 & 255);
  this.deflateOptions.outputBuffer = f;
  this.deflateOptions.outputIndex = c;
  c = new Zlib.RawDeflate(g, this.deflateOptions);
  f = c.compress();
  c = c.op;
  USE_TYPEDARRAY && (c + 8 > f.buffer.byteLength ? (this.output = new Uint8Array(c + 8), this.output.set(new Uint8Array(f.buffer)), f = this.output) : f = new Uint8Array(f.buffer));
  b = Zlib.CRC32.calc(g);
  f[c++] = b & 255;
  f[c++] = b >>> 8 & 255;
  f[c++] = b >>> 16 & 255;
  f[c++] = b >>> 24 & 255;
  e = g.length;
  f[c++] = e & 255;
  f[c++] = e >>> 8 & 255;
  f[c++] = e >>> 16 & 255;
  f[c++] = e >>> 24 & 255;
  this.ip = h;
  USE_TYPEDARRAY && c < f.length && (this.output = f = f.subarray(0, c));
  return f
};
Zlib.Gzip.OperatingSystem = {FAT:0, AMIGA:1, VMS:2, UNIX:3, VM_CMS:4, ATARI_TOS:5, HPFS:6, MACINTOSH:7, Z_SYSTEM:8, CP_M:9, TOPS_20:10, NTFS:11, QDOS:12, ACORN_RISCOS:13, UNKNOWN:255};
Zlib.Gzip.FlagsMask = {FTEXT:1, FHCRC:2, FEXTRA:4, FNAME:8, FCOMMENT:16};
var ZLIB_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflate = function(a, b) {
  this.blocks = [];
  this.bufferSize = ZLIB_RAW_INFLATE_BUFFER_SIZE;
  this.bitsbuflen = this.bitsbuf = this.ip = this.totalpos = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.bfinal = !1;
  this.bufferType = Zlib.RawInflate.BufferType.ADAPTIVE;
  this.resize = !1;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.bufferSize && (this.bufferSize = b.bufferSize), b.bufferType && (this.bufferType = b.bufferType), b.resize && (this.resize = b.resize)
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      this.op = Zlib.RawInflate.MaxBackwardLength;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.MaxBackwardLength + this.bufferSize + Zlib.RawInflate.MaxCopyLength);
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      this.op = 0;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
      this.expandBuffer = this.expandBufferAdaptive;
      this.concatBuffer = this.concatBufferDynamic;
      this.decodeHuffman = this.decodeHuffmanAdaptive;
      break;
    default:
      throw Error("invalid inflate mode");
  }
};
Zlib.RawInflate.BufferType = {BLOCK:0, ADAPTIVE:1};
Zlib.RawInflate.prototype.decompress = function() {
  for(;!this.bfinal;) {
    this.parseBlock()
  }
  return this.concatBuffer()
};
Zlib.RawInflate.MaxBackwardLength = 32768;
Zlib.RawInflate.MaxCopyLength = 258;
Zlib.RawInflate.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflate.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflate.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflate.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflate.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflate.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.prototype.parseBlock = function() {
  var a = this.readBits(3);
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.parseUncompressedBlock();
      break;
    case 1:
      this.parseFixedHuffmanBlock();
      break;
    case 2:
      this.parseDynamicHuffmanBlock();
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
};
Zlib.RawInflate.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      throw Error("input buffer is broken");
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflate.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      throw Error("input buffer is broken");
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflate.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e, f, g, h = c.length;
  this.bitsbuflen = this.bitsbuf = 0;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (first byte)");
  }
  f = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (second byte)");
  }
  f |= e << 8;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (first byte)");
  }
  g = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (second byte)");
  }
  if(f === ~(g | e << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  if(b + f > a.length) {
    throw Error("input buffer is broken");
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      for(;d + f > c.length;) {
        e = h - d;
        f -= e;
        if(USE_TYPEDARRAY) {
          c.set(a.subarray(b, b + e), d), d += e, b += e
        }else {
          for(;e--;) {
            c[d++] = a[b++]
          }
        }
        this.op = d;
        c = this.expandBuffer();
        d = this.op
      }
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      for(;d + f > c.length;) {
        c = this.expandBuffer({fixRatio:2})
      }
      break;
    default:
      throw Error("invalid inflate mode");
  }
  if(USE_TYPEDARRAY) {
    c.set(a.subarray(b, b + f), d), d += f, b += f
  }else {
    for(;f--;) {
      c[d++] = a[b++]
    }
  }
  this.ip = b;
  this.op = d;
  this.output = c
};
Zlib.RawInflate.prototype.parseFixedHuffmanBlock = function() {
  this.decodeHuffman(Zlib.RawInflate.FixedLiteralLengthTable, Zlib.RawInflate.FixedDistanceTable)
};
Zlib.RawInflate.prototype.parseDynamicHuffmanBlock = function() {
  function a(a, b, c) {
    var d, e, f;
    for(f = 0;f < a;) {
      switch(d = this.readCodeByTable(b), d) {
        case 16:
          for(d = 3 + this.readBits(2);d--;) {
            c[f++] = e
          }
          break;
        case 17:
          for(d = 3 + this.readBits(3);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        case 18:
          for(d = 11 + this.readBits(7);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        default:
          e = c[f++] = d
      }
    }
    return c
  }
  var b = this.readBits(5) + 257, c = this.readBits(5) + 1, d = this.readBits(4) + 4, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.Order.length), f;
  for(f = 0;f < d;++f) {
    e[Zlib.RawInflate.Order[f]] = this.readBits(3)
  }
  d = (0,Zlib.Huffman.buildHuffmanTable)(e);
  e = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
  f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c);
  this.decodeHuffman((0,Zlib.Huffman.buildHuffmanTable)(a.call(this, b, d, e)), (0,Zlib.Huffman.buildHuffmanTable)(a.call(this, c, d, f)))
};
Zlib.RawInflate.prototype.decodeHuffman = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length - Zlib.RawInflate.MaxCopyLength, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.decodeHuffmanAdaptive = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (c = this.expandBuffer(), e = c.length), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d + h > e && (c = this.expandBuffer(), e = c.length);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.expandBuffer = function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.op - Zlib.RawInflate.MaxBackwardLength), b = this.op - Zlib.RawInflate.MaxBackwardLength, c, d, e = this.output;
  if(USE_TYPEDARRAY) {
    a.set(e.subarray(Zlib.RawInflate.MaxBackwardLength, a.length))
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      a[c] = e[c + Zlib.RawInflate.MaxBackwardLength]
    }
  }
  this.blocks.push(a);
  this.totalpos += a.length;
  if(USE_TYPEDARRAY) {
    e.set(e.subarray(b, b + Zlib.RawInflate.MaxBackwardLength))
  }else {
    for(c = 0;c < Zlib.RawInflate.MaxBackwardLength;++c) {
      e[c] = e[b + c]
    }
  }
  this.op = Zlib.RawInflate.MaxBackwardLength;
  return e
};
Zlib.RawInflate.prototype.expandBufferAdaptive = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.currentLitlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflate.prototype.concatBuffer = function() {
  var a = 0, b = this.output, c = this.blocks, d, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.totalpos + (this.op - Zlib.RawInflate.MaxBackwardLength)), f, g, h, i;
  if(0 === c.length) {
    return USE_TYPEDARRAY ? this.output.subarray(Zlib.RawInflate.MaxBackwardLength, this.op) : this.output.slice(Zlib.RawInflate.MaxBackwardLength, this.op)
  }
  f = 0;
  for(g = c.length;f < g;++f) {
    d = c[f];
    h = 0;
    for(i = d.length;h < i;++h) {
      e[a++] = d[h]
    }
  }
  f = Zlib.RawInflate.MaxBackwardLength;
  for(g = this.op;f < g;++f) {
    e[a++] = b[f]
  }
  this.blocks = [];
  return this.buffer = e
};
Zlib.RawInflate.prototype.concatBufferDynamic = function() {
  var a, b = this.op;
  USE_TYPEDARRAY ? this.resize ? (a = new Uint8Array(b), a.set(this.output.subarray(0, b))) : a = this.output.subarray(0, b) : (this.output.length > b && (this.output.length = b), a = this.output);
  return this.buffer = a
};
Zlib.Gunzip = function(a) {
  this.input = a;
  this.ip = 0;
  this.member = [];
  this.decompressed = !1
};
Zlib.Gunzip.prototype.getMembers = function() {
  this.decompressed || this.decompress();
  return this.member.slice()
};
Zlib.Gunzip.prototype.decompress = function() {
  for(var a = this.input.length;this.ip < a;) {
    this.decodeMember()
  }
  this.decompressed = !0;
  return this.concatMember()
};
Zlib.Gunzip.prototype.decodeMember = function() {
  var a = new Zlib.GunzipMember, b, c, d, e, f, g = this.input;
  c = this.ip;
  a.id1 = g[c++];
  a.id2 = g[c++];
  if(31 !== a.id1 || 139 !== a.id2) {
    throw Error("invalid file signature:" + a.id1 + "," + a.id2);
  }
  a.cm = g[c++];
  switch(a.cm) {
    case 8:
      break;
    default:
      throw Error("unknown compression method: " + a.cm);
  }
  a.flg = g[c++];
  b = g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24;
  a.mtime = new Date(1E3 * b);
  a.xfl = g[c++];
  a.os = g[c++];
  0 < (a.flg & Zlib.Gzip.FlagsMask.FEXTRA) && (a.xlen = g[c++] | g[c++] << 8, c = this.decodeSubField(c, a.xlen));
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FNAME)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.name = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FCOMMENT)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.comment = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FHCRC) && (a.crc16 = Zlib.CRC32.calc(g, 0, c) & 65535, a.crc16 !== (g[c++] | g[c++] << 8))) {
    throw Error("invalid header crc16");
  }
  b = g[g.length - 4] | g[g.length - 3] << 8 | g[g.length - 2] << 16 | g[g.length - 1] << 24;
  g.length - c - 4 - 4 < 512 * b && (d = b);
  c = new Zlib.RawInflate(g, {index:c, bufferSize:d});
  a.data = d = c.decompress();
  c = c.ip;
  a.crc32 = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if(Zlib.CRC32.calc(d) !== b) {
    throw Error("invalid CRC-32 checksum: 0x" + Zlib.CRC32.calc(d).toString(16) + " / 0x" + b.toString(16));
  }
  a.isize = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if((d.length & 4294967295) !== b) {
    throw Error("invalid input size: " + (d.length & 4294967295) + " / " + b);
  }
  this.member.push(a);
  this.ip = c
};
Zlib.Gunzip.prototype.decodeSubField = function(a, b) {
  return a + b
};
Zlib.Gunzip.prototype.concatMember = function() {
  var a = this.member, b, c, d = 0, e = 0;
  b = 0;
  for(c = a.length;b < c;++b) {
    e += a[b].data.length
  }
  if(USE_TYPEDARRAY) {
    e = new Uint8Array(e);
    for(b = 0;b < c;++b) {
      e.set(a[b].data, d), d += a[b].data.length
    }
  }else {
    e = [];
    for(b = 0;b < c;++b) {
      e[b] = a[b].data
    }
    e = Array.prototype.concat.apply([], e)
  }
  return e
};
var ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflateStream = function(a, b, c) {
  this.blocks = [];
  this.bufferSize = c ? c : ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE;
  this.totalpos = 0;
  this.ip = void 0 === b ? 0 : b;
  this.bitsbuflen = this.bitsbuf = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
  this.op = 0;
  this.resize = this.bfinal = !1;
  this.sp = 0;
  this.status = Zlib.RawInflateStream.Status.INITIALIZED
};
Zlib.RawInflateStream.BlockType = {UNCOMPRESSED:0, FIXED:1, DYNAMIC:2};
Zlib.RawInflateStream.Status = {INITIALIZED:0, BLOCK_HEADER_START:1, BLOCK_HEADER_END:2, BLOCK_BODY_START:3, BLOCK_BODY_END:4, DECODE_BLOCK_START:5, DECODE_BLOCK_END:6};
Zlib.RawInflateStream.prototype.decompress = function(a, b) {
  var c = !1;
  void 0 !== a && (this.input = a);
  void 0 !== b && (this.ip = b);
  for(;!c;) {
    switch(this.status) {
      case Zlib.RawInflateStream.Status.INITIALIZED:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_START:
        0 > this.readBlockHeader() && (c = !0);
        break;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_END:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.readUncompressedBlockHeader() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
            0 > this.parseFixedHuffmanBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.parseDynamicHuffmanBlock() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_END:
      ;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.parseUncompressedBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
          ;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.decodeHuffman() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_END:
        this.bfinal ? c = !0 : this.status = Zlib.RawInflateStream.Status.INITIALIZED
    }
  }
  return this.concatBuffer()
};
Zlib.RawInflateStream.MaxBackwardLength = 32768;
Zlib.RawInflateStream.MaxCopyLength = 258;
Zlib.RawInflateStream.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflateStream.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflateStream.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflateStream.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflateStream.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflateStream.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.prototype.readBlockHeader = function() {
  var a;
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_START;
  this.save_();
  if(0 > (a = this.readBits(3))) {
    return this.restore_(), -1
  }
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.UNCOMPRESSED;
      break;
    case 1:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.FIXED;
      break;
    case 2:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.DYNAMIC;
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_END
};
Zlib.RawInflateStream.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      return-1
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflateStream.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      return-1
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflateStream.prototype.readUncompressedBlockHeader = function() {
  var a, b, c, d = this.input, e = this.ip;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b |= a << 8;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  c = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  if(b === ~(c | a << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  this.bitsbuflen = this.bitsbuf = 0;
  this.ip = e;
  this.blockLength = b;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END
};
Zlib.RawInflateStream.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e = this.blockLength;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;e--;) {
    d === c.length && (c = this.expandBuffer());
    if(void 0 === a[b]) {
      return this.ip = b, this.op = d, this.blockLength = e + 1, -1
    }
    c[d++] = a[b++]
  }
  0 > e && (this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END);
  this.ip = b;
  this.op = d;
  return 0
};
Zlib.RawInflateStream.prototype.parseFixedHuffmanBlock = function() {
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.litlenTable = Zlib.RawInflateStream.FixedLiteralLengthTable;
  this.distTable = Zlib.RawInflateStream.FixedDistanceTable;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.save_ = function() {
  this.ip_ = this.ip;
  this.bitsbuflen_ = this.bitsbuflen;
  this.bitsbuf_ = this.bitsbuf
};
Zlib.RawInflateStream.prototype.restore_ = function() {
  this.ip = this.ip_;
  this.bitsbuflen = this.bitsbuflen_;
  this.bitsbuf = this.bitsbuf_
};
Zlib.RawInflateStream.prototype.parseDynamicHuffmanBlock = function() {
  var a, b, c, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflateStream.Order.length), e, f, g, h = 0;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.save_();
  a = this.readBits(5) + 257;
  b = this.readBits(5) + 1;
  c = this.readBits(4) + 4;
  if(0 > a || 0 > b || 0 > c) {
    return this.restore_(), -1
  }
  try {
    for(var i = function(a, b, c) {
      for(var d, e, f = 0, f = 0;f < a;) {
        d = this.readCodeByTable(b);
        if(0 > d) {
          throw Error("not enough input");
        }
        switch(d) {
          case 16:
            if(0 > (d = this.readBits(2))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = e
            }
            break;
          case 17:
            if(0 > (d = this.readBits(3))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          case 18:
            if(0 > (d = this.readBits(7))) {
              throw Error("not enough input");
            }
            for(d = 11 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          default:
            e = c[f++] = d
        }
      }
      return c
    }, j, h = 0;h < c;++h) {
      if(0 > (j = this.readBits(3))) {
        throw Error("not enough input");
      }
      d[Zlib.RawInflateStream.Order[h]] = j
    }
    e = (0,Zlib.Huffman.buildHuffmanTable)(d);
    f = new (USE_TYPEDARRAY ? Uint8Array : Array)(a);
    g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
    this.litlenTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, a, e, f));
    this.distTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, b, e, g))
  }catch(l) {
    return this.restore_(), -1
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.decodeHuffman = function() {
  var a = this.output, b = this.op, c, d, e, f = this.litlenTable, g = this.distTable, h = a.length;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;;) {
    this.save_();
    c = this.readCodeByTable(f);
    if(0 > c) {
      return this.op = b, this.restore_(), -1
    }
    if(256 === c) {
      break
    }
    if(256 > c) {
      b === h && (a = this.expandBuffer(), h = a.length), a[b++] = c
    }else {
      d = c - 257;
      e = Zlib.RawInflateStream.LengthCodeTable[d];
      if(0 < Zlib.RawInflateStream.LengthExtraTable[d]) {
        c = this.readBits(Zlib.RawInflateStream.LengthExtraTable[d]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        e += c
      }
      c = this.readCodeByTable(g);
      if(0 > c) {
        return this.op = b, this.restore_(), -1
      }
      d = Zlib.RawInflateStream.DistCodeTable[c];
      if(0 < Zlib.RawInflateStream.DistExtraTable[c]) {
        c = this.readBits(Zlib.RawInflateStream.DistExtraTable[c]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        d += c
      }
      b + e >= h && (a = this.expandBuffer(), h = a.length);
      for(;e--;) {
        a[b] = a[b++ - d]
      }
      if(this.ip === this.input.length) {
        return this.op = b, -1
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = b;
  this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END
};
Zlib.RawInflateStream.prototype.expandBuffer = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.litlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflateStream.prototype.concatBuffer = function() {
  var a, b = this.op;
  this.resize ? USE_TYPEDARRAY ? (a = new Uint8Array(b), a.set(this.output.subarray(this.sp, b))) : a = this.output.slice(this.sp, b) : a = USE_TYPEDARRAY ? this.output.subarray(this.sp, b) : this.output.slice(this.sp, b);
  this.buffer = a;
  this.sp = b;
  return this.buffer
};
Zlib.RawInflateStream.prototype.getBytes = function() {
  return USE_TYPEDARRAY ? this.output.subarray(0, this.op) : this.output.slice(0, this.op)
};
Zlib.InflateStream = function(a) {
  this.input = void 0 === a ? new (USE_TYPEDARRAY ? Uint8Array : Array) : a;
  this.ip = 0;
  this.rawinflate = new Zlib.RawInflateStream(this.input, this.ip);
  this.output = this.rawinflate.output
};
Zlib.InflateStream.prototype.decompress = function(a) {
  if(void 0 !== a) {
    if(USE_TYPEDARRAY) {
      var b = new Uint8Array(this.input.length + a.length);
      b.set(this.input, 0);
      b.set(a, this.input.length);
      this.input = b
    }else {
      this.input = this.input.concat(a)
    }
  }
  if(void 0 === this.method && 0 > this.readHeader()) {
    return new (USE_TYPEDARRAY ? Uint8Array : Array)
  }
  a = this.rawinflate.decompress(this.input, this.ip);
  this.ip = this.rawinflate.ip;
  return a
};
Zlib.InflateStream.prototype.getBytes = function() {
  return this.rawinflate.getBytes()
};
Zlib.InflateStream.prototype.readHeader = function() {
  var a = this.ip, b = this.input, c = b[a++], b = b[a++];
  if(void 0 === c || void 0 === b) {
    return-1
  }
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + b) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + b) % 31);
  }
  if(b & 32) {
    throw Error("fdict flag is not supported");
  }
  this.ip = a
};
Zlib.Util = {};
Zlib.Util.stringToByteArray = function(a) {
  var a = a.split(""), b, c;
  b = 0;
  for(c = a.length;b < c;b++) {
    a[b] = (a[b].charCodeAt(0) & 255) >>> 0
  }
  return a
};
Zlib.Adler32 = function(a) {
  "string" === typeof a && (a = Zlib.Util.stringToByteArray(a));
  return Zlib.Adler32.update(1, a)
};
Zlib.Adler32.update = function(a, b) {
  for(var c = a & 65535, d = a >>> 16 & 65535, e = b.length, f, g = 0;0 < e;) {
    f = e > Zlib.Adler32.OptimizationParameter ? Zlib.Adler32.OptimizationParameter : e;
    e -= f;
    do {
      c += b[g++], d += c
    }while(--f);
    c %= 65521;
    d %= 65521
  }
  return(d << 16 | c) >>> 0
};
Zlib.Adler32.OptimizationParameter = 1024;
Zlib.Deflate = function(a, b) {
  this.input = a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Deflate.DefaultBufferSize);
  this.compressionType = Zlib.Deflate.CompressionType.DYNAMIC;
  var c = {}, d;
  if((b || !(b = {})) && "number" === typeof b.compressionType) {
    this.compressionType = b.compressionType
  }
  for(d in b) {
    c[d] = b[d]
  }
  c.outputBuffer = this.output;
  this.rawDeflate = new Zlib.RawDeflate(this.input, c)
};
Zlib.Deflate.DefaultBufferSize = 32768;
Zlib.Deflate.CompressionType = Zlib.RawDeflate.CompressionType;
Zlib.Deflate.compress = function(a, b) {
  return(new Zlib.Deflate(a, b)).compress()
};
Zlib.Deflate.prototype.compress = function() {
  var a, b, c, d = 0;
  c = this.output;
  a = Zlib.CompressionMethod.DEFLATE;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      b = Math.LOG2E * Math.log(Zlib.RawDeflate.WindowSize) - 8;
      break;
    default:
      throw Error("invalid compression method");
  }
  b = b << 4 | a;
  c[d++] = b;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      switch(this.compressionType) {
        case Zlib.Deflate.CompressionType.NONE:
          a = 0;
          break;
        case Zlib.Deflate.CompressionType.FIXED:
          a = 1;
          break;
        case Zlib.Deflate.CompressionType.DYNAMIC:
          a = 2;
          break;
        default:
          throw Error("unsupported compression type");
      }
      break;
    default:
      throw Error("invalid compression method");
  }
  a = a << 6 | 0;
  c[d++] = a | 31 - (256 * b + a) % 31;
  b = Zlib.Adler32(this.input);
  this.rawDeflate.op = d;
  c = this.rawDeflate.compress();
  d = c.length;
  USE_TYPEDARRAY && (c = new Uint8Array(c.buffer), c.length <= d + 4 && (this.output = new Uint8Array(c.length + 4), this.output.set(c), c = this.output), c = c.subarray(0, d + 4));
  c[d++] = b >> 24 & 255;
  c[d++] = b >> 16 & 255;
  c[d++] = b >> 8 & 255;
  c[d++] = b & 255;
  return c
};
Zlib.Inflate = function(a, b) {
  var c, d;
  this.input = a;
  this.ip = 0;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.verify && (this.verify = b.verify)
  }
  c = a[this.ip++];
  d = a[this.ip++];
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + d) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + d) % 31);
  }
  if(d & 32) {
    throw Error("fdict flag is not supported");
  }
  this.rawinflate = new Zlib.RawInflate(a, {index:this.ip, bufferSize:b.bufferSize, bufferType:b.bufferType, resize:b.resize})
};
Zlib.Inflate.BufferType = Zlib.RawInflate.BufferType;
Zlib.Inflate.prototype.decompress = function() {
  var a = this.input, b;
  b = this.rawinflate.decompress();
  this.ip = this.rawinflate.ip;
  if(this.verify && (a = (a[this.ip++] << 24 | a[this.ip++] << 16 | a[this.ip++] << 8 | a[this.ip++]) >>> 0, a !== Zlib.Adler32(b))) {
    throw Error("invalid adler-32 checksum");
  }
  return b
};
goog.exportSymbol("Zlib.Inflate", Zlib.Inflate);
goog.exportSymbol("Zlib.Inflate.prototype.decompress", Zlib.Inflate.prototype.decompress);
Zlib.exportObject("Zlib.Inflate.BufferType", {ADAPTIVE:Zlib.Inflate.BufferType.ADAPTIVE, BLOCK:Zlib.Inflate.BufferType.BLOCK});
Zlib.Zip = function(a) {
  a = a || {};
  this.files = [];
  this.comment = a.comment
};
Zlib.Zip.prototype.addFile = function(a, b) {
  var b = b || {}, c, d = a.length, e = 0;
  USE_TYPEDARRAY && a instanceof Array && (a = new Uint8Array(a));
  "number" !== typeof b.compressionMethod && (b.compressionMethod = Zlib.Zip.CompressionMethod.DEFLATE);
  if(b.compress) {
    switch(b.compressionMethod) {
      case Zlib.Zip.CompressionMethod.STORE:
        break;
      case Zlib.Zip.CompressionMethod.DEFLATE:
        e = Zlib.CRC32.calc(a);
        a = this.deflateWithOption(a, b);
        c = !0;
        break;
      default:
        throw Error("unknown compression method:" + b.compressionMethod);
    }
  }
  this.files.push({buffer:a, option:b, compressed:c, size:d, crc32:e})
};
Zlib.Zip.CompressionMethod = {STORE:0, DEFLATE:8};
Zlib.Zip.OperatingSystem = {MSDOS:0, UNIX:3, MACINTOSH:7};
Zlib.Zip.prototype.compress = function() {
  var a = this.files, b, c, d, e, f, g = 0, h = 0, i, j, l, m, k, n;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    if(!b.compressed) {
      switch(b.crc32 = Zlib.CRC32.calc(b.buffer), b.option.compressionMethod) {
        case Zlib.Zip.CompressionMethod.STORE:
          break;
        case Zlib.Zip.CompressionMethod.DEFLATE:
          b.buffer = this.deflateWithOption(b.buffer, b.option);
          b.compressed = !0;
          break;
        default:
          throw Error("unknown compression method:" + b.option.compressionMethod);
      }
    }
    g += 30 + l + b.buffer.length;
    h += 46 + l + m
  }
  c = new (USE_TYPEDARRAY ? Uint8Array : Array)(g + h + (46 + (this.comment ? this.comment.length : 0)));
  d = 0;
  e = g;
  f = e + h;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    i = d;
    c[d++] = c[e++] = 80;
    c[d++] = c[e++] = 75;
    c[d++] = 3;
    c[d++] = 4;
    c[e++] = 1;
    c[e++] = 2;
    c[e++] = 20;
    c[e++] = b.option.os || Zlib.Zip.OperatingSystem.MSDOS;
    c[d++] = c[e++] = 20;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    j = b.option.compressionMethod;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    j = b.option.date || new Date;
    c[d++] = c[e++] = (j.getMinutes() & 7) << 5 | j.getSeconds() / 2 | 0;
    c[d++] = c[e++] = j.getHours() << 3 | j.getMinutes() >> 3;
    c[d++] = c[e++] = (j.getMonth() + 1 & 7) << 5 | j.getDate();
    c[d++] = c[e++] = (j.getFullYear() - 1980 & 127) << 1 | j.getMonth() + 1 >> 3;
    j = b.crc32;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.buffer.length;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.size;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    c[d++] = c[e++] = l & 255;
    c[d++] = c[e++] = l >> 8 & 255;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[e++] = m & 255;
    c[e++] = m >> 8 & 255;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = i & 255;
    c[e++] = i >> 8 & 255;
    c[e++] = i >> 16 & 255;
    c[e++] = i >> 24 & 255;
    if(j = b.option.filename) {
      if(USE_TYPEDARRAY) {
        c.set(j, d), c.set(j, e), d += l, e += l
      }else {
        for(i = 0;i < l;++i) {
          c[d++] = c[e++] = j[i]
        }
      }
    }
    if(l = b.option.extraField) {
      if(USE_TYPEDARRAY) {
        c.set(l, d), c.set(l, e), d += 0, e += 0
      }else {
        for(i = 0;i < m;++i) {
          c[d++] = c[e++] = l[i]
        }
      }
    }
    if(l = b.option.comment) {
      if(USE_TYPEDARRAY) {
        c.set(l, e), e += m
      }else {
        for(i = 0;i < m;++i) {
          c[e++] = l[i]
        }
      }
    }
    if(USE_TYPEDARRAY) {
      c.set(b.buffer, d), d += b.buffer.length
    }else {
      i = 0;
      for(m = b.buffer.length;i < m;++i) {
        c[d++] = b.buffer[i]
      }
    }
  }
  c[f++] = 80;
  c[f++] = 75;
  c[f++] = 5;
  c[f++] = 6;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = h & 255;
  c[f++] = h >> 8 & 255;
  c[f++] = h >> 16 & 255;
  c[f++] = h >> 24 & 255;
  c[f++] = g & 255;
  c[f++] = g >> 8 & 255;
  c[f++] = g >> 16 & 255;
  c[f++] = g >> 24 & 255;
  m = this.comment ? this.comment.length : 0;
  c[f++] = m & 255;
  c[f++] = m >> 8 & 255;
  if(this.comment) {
    if(USE_TYPEDARRAY) {
      c.set(this.comment, f)
    }else {
      for(i = 0;i < m;++i) {
        c[f++] = this.comment[i]
      }
    }
  }
  return c
};
Zlib.Zip.prototype.deflateWithOption = function(a, b) {
  return(new Zlib.RawDeflate(a, b.deflateOption)).compress()
};
Zlib.Unzip = function(a, b) {
  b = b || {};
  this.input = USE_TYPEDARRAY && a instanceof Array ? new Uint8Array(a) : a;
  this.ip = 0;
  this.verify = b.verify || !1
};
Zlib.Unzip.CompressionMethod = Zlib.Zip.CompressionMethod;
Zlib.Unzip.FileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.FileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 1 !== a[b++] || 2 !== a[b++]) {
    throw Error("invalid file header signature");
  }
  this.version = a[b++];
  this.os = a[b++];
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.fileCommentLength = a[b++] | a[b++] << 8;
  this.diskNumberStart = a[b++] | a[b++] << 8;
  this.internalFileAttributes = a[b++] | a[b++] << 8;
  this.externalFileAttributes = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.relativeOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.fileCommentLength) : a.slice(b, b + this.fileCommentLength);
  this.length = b - this.offset
};
Zlib.Unzip.LocalFileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.LocalFileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 3 !== a[b++] || 4 !== a[b++]) {
    throw Error("invalid local file header signature");
  }
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.length = b - this.offset
};
Zlib.Unzip.prototype.searchEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  for(b = a.length - 12;0 < b;--b) {
    if(80 === a[b] && 75 === a[b + 1] && 5 === a[b + 2] && 6 === a[b + 3]) {
      this.eocdrOffset = b;
      return
    }
  }
  throw Error("End of Central Directory Record not found");
};
Zlib.Unzip.prototype.parseEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  this.eocdrOffset || this.searchEndOfCentralDirectoryRecord();
  b = this.eocdrOffset;
  if(80 !== a[b++] || 75 !== a[b++] || 5 !== a[b++] || 6 !== a[b++]) {
    throw Error("invalid signature");
  }
  this.numberOfThisDisk = a[b++] | a[b++] << 8;
  this.startDisk = a[b++] | a[b++] << 8;
  this.totalEntriesThisDisk = a[b++] | a[b++] << 8;
  this.totalEntries = a[b++] | a[b++] << 8;
  this.centralDirectorySize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.centralDirectoryOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.commentLength = a[b++] | a[b++] << 8;
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.commentLength) : a.slice(b, b + this.commentLength)
};
Zlib.Unzip.prototype.parseFileHeader = function() {
  var a = [], b = {}, c, d, e, f;
  if(!this.fileHeaderList) {
    void 0 === this.centralDirectoryOffset && this.parseEndOfCentralDirectoryRecord();
    c = this.centralDirectoryOffset;
    e = 0;
    for(f = this.totalEntries;e < f;++e) {
      d = new Zlib.Unzip.FileHeader(this.input, c), d.parse(), c += d.length, a[e] = d, b[d.filename] = e
    }
    if(this.centralDirectorySize < c - this.centralDirectoryOffset) {
      throw Error("invalid file header size");
    }
    this.fileHeaderList = a;
    this.filenameToIndex = b
  }
};
Zlib.Unzip.prototype.getFileData = function(a) {
  var b = this.fileHeaderList, c;
  b || this.parseFileHeader();
  if(void 0 === b[a]) {
    throw Error("wrong index");
  }
  b = b[a].relativeOffset;
  a = new Zlib.Unzip.LocalFileHeader(this.input, b);
  a.parse();
  b += a.length;
  c = a.compressedSize;
  switch(a.compression) {
    case Zlib.Unzip.CompressionMethod.STORE:
      b = USE_TYPEDARRAY ? this.input.subarray(b, b + c) : this.input.slice(b, b + c);
      break;
    case Zlib.Unzip.CompressionMethod.DEFLATE:
      b = (new Zlib.RawInflate(this.input, {index:b, bufferSize:a.plainSize})).decompress();
      break;
    default:
      throw Error("unknown compression type");
  }
  if(this.verify && (c = Zlib.CRC32.calc(b), a.crc32 !== c)) {
    throw Error("wrong crc: file=0x" + a.crc32.toString(16) + ", data=0x" + c.toString(16));
  }
  return b
};
Zlib.Unzip.prototype.getFilenames = function() {
  var a = [], b, c, d;
  this.fileHeaderList || this.parseFileHeader();
  d = this.fileHeaderList;
  b = 0;
  for(c = d.length;b < c;++b) {
    a[b] = d[b].filename
  }
  return a
};
Zlib.Unzip.prototype.decompress = function(a) {
  var b;
  this.filenameToIndex || this.parseFileHeader();
  b = this.filenameToIndex[a];
  if(void 0 === b) {
    throw Error(a + " not found");
  }
  return this.getFileData(b)
};
Zlib.CompressionMethod = {DEFLATE:8, RESERVED:15};
}).call(this);

define("thirdparty/inflate.min", function(){});

/** @license zlib.js 2012 - imaya [ https://github.com/imaya/zlib.js ] The MIT License */
(function() {var COMPILED = !0, goog = goog || {};
goog.global = this;
goog.DEBUG = !1;
goog.LOCALE = "en";
goog.provide = function(a) {
  if(!COMPILED) {
    if(goog.isProvided_(a)) {
      throw Error('Namespace "' + a + '" already declared.');
    }
    delete goog.implicitNamespaces_[a];
    for(var b = a;(b = b.substring(0, b.lastIndexOf("."))) && !goog.getObjectByName(b);) {
      goog.implicitNamespaces_[b] = !0
    }
  }
  goog.exportPath_(a)
};
goog.setTestOnly = function(a) {
  if(COMPILED && !goog.DEBUG) {
    throw a = a || "", Error("Importing test-only code into non-debug environment" + a ? ": " + a : ".");
  }
};
COMPILED || (goog.isProvided_ = function(a) {
  return!goog.implicitNamespaces_[a] && !!goog.getObjectByName(a)
}, goog.implicitNamespaces_ = {});
goog.exportPath_ = function(a, b, c) {
  a = a.split(".");
  c = c || goog.global;
  !(a[0] in c) && c.execScript && c.execScript("var " + a[0]);
  for(var d;a.length && (d = a.shift());) {
    !a.length && goog.isDef(b) ? c[d] = b : c = c[d] ? c[d] : c[d] = {}
  }
};
goog.getObjectByName = function(a, b) {
  for(var c = a.split("."), d = b || goog.global, e;e = c.shift();) {
    if(goog.isDefAndNotNull(d[e])) {
      d = d[e]
    }else {
      return null
    }
  }
  return d
};
goog.globalize = function(a, b) {
  var c = b || goog.global, d;
  for(d in a) {
    c[d] = a[d]
  }
};
goog.addDependency = function(a, b, c) {
  if(!COMPILED) {
    for(var d, a = a.replace(/\\/g, "/"), e = goog.dependencies_, f = 0;d = b[f];f++) {
      e.nameToPath[d] = a, a in e.pathToNames || (e.pathToNames[a] = {}), e.pathToNames[a][d] = !0
    }
    for(d = 0;b = c[d];d++) {
      a in e.requires || (e.requires[a] = {}), e.requires[a][b] = !0
    }
  }
};
goog.ENABLE_DEBUG_LOADER = !0;
goog.require = function(a) {
  if(!COMPILED && !goog.isProvided_(a)) {
    if(goog.ENABLE_DEBUG_LOADER) {
      var b = goog.getPathFromDeps_(a);
      if(b) {
        goog.included_[b] = !0;
        goog.writeScripts_();
        return
      }
    }
    a = "goog.require could not find: " + a;
    goog.global.console && goog.global.console.error(a);
    throw Error(a);
  }
};
goog.basePath = "";
goog.nullFunction = function() {
};
goog.identityFunction = function(a) {
  return a
};
goog.abstractMethod = function() {
  throw Error("unimplemented abstract method");
};
goog.addSingletonGetter = function(a) {
  a.getInstance = function() {
    if(a.instance_) {
      return a.instance_
    }
    goog.DEBUG && (goog.instantiatedSingletons_[goog.instantiatedSingletons_.length] = a);
    return a.instance_ = new a
  }
};
goog.instantiatedSingletons_ = [];
!COMPILED && goog.ENABLE_DEBUG_LOADER && (goog.included_ = {}, goog.dependencies_ = {pathToNames:{}, nameToPath:{}, requires:{}, visited:{}, written:{}}, goog.inHtmlDocument_ = function() {
  var a = goog.global.document;
  return"undefined" != typeof a && "write" in a
}, goog.findBasePath_ = function() {
  if(goog.global.CLOSURE_BASE_PATH) {
    goog.basePath = goog.global.CLOSURE_BASE_PATH
  }else {
    if(goog.inHtmlDocument_()) {
      for(var a = goog.global.document.getElementsByTagName("script"), b = a.length - 1;0 <= b;--b) {
        var c = a[b].src, d = c.lastIndexOf("?"), d = -1 == d ? c.length : d;
        if("base.js" == c.substr(d - 7, 7)) {
          goog.basePath = c.substr(0, d - 7);
          break
        }
      }
    }
  }
}, goog.importScript_ = function(a) {
  var b = goog.global.CLOSURE_IMPORT_SCRIPT || goog.writeScriptTag_;
  !goog.dependencies_.written[a] && b(a) && (goog.dependencies_.written[a] = !0)
}, goog.writeScriptTag_ = function(a) {
  return goog.inHtmlDocument_() ? (goog.global.document.write('<script type="text/javascript" src="' + a + '"><\/script>'), !0) : !1
}, goog.writeScripts_ = function() {
  function a(e) {
    if(!(e in d.written)) {
      if(!(e in d.visited) && (d.visited[e] = !0, e in d.requires)) {
        for(var g in d.requires[e]) {
          if(!goog.isProvided_(g)) {
            if(g in d.nameToPath) {
              a(d.nameToPath[g])
            }else {
              throw Error("Undefined nameToPath for " + g);
            }
          }
        }
      }
      e in c || (c[e] = !0, b.push(e))
    }
  }
  var b = [], c = {}, d = goog.dependencies_, e;
  for(e in goog.included_) {
    d.written[e] || a(e)
  }
  for(e = 0;e < b.length;e++) {
    if(b[e]) {
      goog.importScript_(goog.basePath + b[e])
    }else {
      throw Error("Undefined script input");
    }
  }
}, goog.getPathFromDeps_ = function(a) {
  return a in goog.dependencies_.nameToPath ? goog.dependencies_.nameToPath[a] : null
}, goog.findBasePath_(), goog.global.CLOSURE_NO_DEPS || goog.importScript_(goog.basePath + "deps.js"));
goog.typeOf = function(a) {
  var b = typeof a;
  if("object" == b) {
    if(a) {
      if(a instanceof Array) {
        return"array"
      }
      if(a instanceof Object) {
        return b
      }
      var c = Object.prototype.toString.call(a);
      if("[object Window]" == c) {
        return"object"
      }
      if("[object Array]" == c || "number" == typeof a.length && "undefined" != typeof a.splice && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("splice")) {
        return"array"
      }
      if("[object Function]" == c || "undefined" != typeof a.call && "undefined" != typeof a.propertyIsEnumerable && !a.propertyIsEnumerable("call")) {
        return"function"
      }
    }else {
      return"null"
    }
  }else {
    if("function" == b && "undefined" == typeof a.call) {
      return"object"
    }
  }
  return b
};
goog.isDef = function(a) {
  return void 0 !== a
};
goog.isNull = function(a) {
  return null === a
};
goog.isDefAndNotNull = function(a) {
  return null != a
};
goog.isArray = function(a) {
  return"array" == goog.typeOf(a)
};
goog.isArrayLike = function(a) {
  var b = goog.typeOf(a);
  return"array" == b || "object" == b && "number" == typeof a.length
};
goog.isDateLike = function(a) {
  return goog.isObject(a) && "function" == typeof a.getFullYear
};
goog.isString = function(a) {
  return"string" == typeof a
};
goog.isBoolean = function(a) {
  return"boolean" == typeof a
};
goog.isNumber = function(a) {
  return"number" == typeof a
};
goog.isFunction = function(a) {
  return"function" == goog.typeOf(a)
};
goog.isObject = function(a) {
  var b = typeof a;
  return"object" == b && null != a || "function" == b
};
goog.getUid = function(a) {
  return a[goog.UID_PROPERTY_] || (a[goog.UID_PROPERTY_] = ++goog.uidCounter_)
};
goog.removeUid = function(a) {
  "removeAttribute" in a && a.removeAttribute(goog.UID_PROPERTY_);
  try {
    delete a[goog.UID_PROPERTY_]
  }catch(b) {
  }
};
goog.UID_PROPERTY_ = "closure_uid_" + Math.floor(2147483648 * Math.random()).toString(36);
goog.uidCounter_ = 0;
goog.getHashCode = goog.getUid;
goog.removeHashCode = goog.removeUid;
goog.cloneObject = function(a) {
  var b = goog.typeOf(a);
  if("object" == b || "array" == b) {
    if(a.clone) {
      return a.clone()
    }
    var b = "array" == b ? [] : {}, c;
    for(c in a) {
      b[c] = goog.cloneObject(a[c])
    }
    return b
  }
  return a
};
goog.bindNative_ = function(a, b, c) {
  return a.call.apply(a.bind, arguments)
};
goog.bindJs_ = function(a, b, c) {
  if(!a) {
    throw Error();
  }
  if(2 < arguments.length) {
    var d = Array.prototype.slice.call(arguments, 2);
    return function() {
      var c = Array.prototype.slice.call(arguments);
      Array.prototype.unshift.apply(c, d);
      return a.apply(b, c)
    }
  }
  return function() {
    return a.apply(b, arguments)
  }
};
goog.bind = function(a, b, c) {
  goog.bind = Function.prototype.bind && -1 != Function.prototype.bind.toString().indexOf("native code") ? goog.bindNative_ : goog.bindJs_;
  return goog.bind.apply(null, arguments)
};
goog.partial = function(a, b) {
  var c = Array.prototype.slice.call(arguments, 1);
  return function() {
    var b = Array.prototype.slice.call(arguments);
    b.unshift.apply(b, c);
    return a.apply(this, b)
  }
};
goog.mixin = function(a, b) {
  for(var c in b) {
    a[c] = b[c]
  }
};
goog.now = Date.now || function() {
  return+new Date
};
goog.globalEval = function(a) {
  if(goog.global.execScript) {
    goog.global.execScript(a, "JavaScript")
  }else {
    if(goog.global.eval) {
      if(null == goog.evalWorksForGlobals_ && (goog.global.eval("var _et_ = 1;"), "undefined" != typeof goog.global._et_ ? (delete goog.global._et_, goog.evalWorksForGlobals_ = !0) : goog.evalWorksForGlobals_ = !1), goog.evalWorksForGlobals_) {
        goog.global.eval(a)
      }else {
        var b = goog.global.document, c = b.createElement("script");
        c.type = "text/javascript";
        c.defer = !1;
        c.appendChild(b.createTextNode(a));
        b.body.appendChild(c);
        b.body.removeChild(c)
      }
    }else {
      throw Error("goog.globalEval not available");
    }
  }
};
goog.evalWorksForGlobals_ = null;
goog.getCssName = function(a, b) {
  var c = function(a) {
    return goog.cssNameMapping_[a] || a
  }, d = function(a) {
    for(var a = a.split("-"), b = [], d = 0;d < a.length;d++) {
      b.push(c(a[d]))
    }
    return b.join("-")
  }, d = goog.cssNameMapping_ ? "BY_WHOLE" == goog.cssNameMappingStyle_ ? c : d : function(a) {
    return a
  };
  return b ? a + "-" + d(b) : d(a)
};
goog.setCssNameMapping = function(a, b) {
  goog.cssNameMapping_ = a;
  goog.cssNameMappingStyle_ = b
};
!COMPILED && goog.global.CLOSURE_CSS_NAME_MAPPING && (goog.cssNameMapping_ = goog.global.CLOSURE_CSS_NAME_MAPPING);
goog.getMsg = function(a, b) {
  var c = b || {}, d;
  for(d in c) {
    var e = ("" + c[d]).replace(/\$/g, "$$$$"), a = a.replace(RegExp("\\{\\$" + d + "\\}", "gi"), e)
  }
  return a
};
goog.exportSymbol = function(a, b, c) {
  goog.exportPath_(a, b, c)
};
goog.exportProperty = function(a, b, c) {
  a[b] = c
};
goog.inherits = function(a, b) {
  function c() {
  }
  c.prototype = b.prototype;
  a.superClass_ = b.prototype;
  a.prototype = new c;
  a.prototype.constructor = a
};
goog.base = function(a, b, c) {
  var d = arguments.callee.caller;
  if(d.superClass_) {
    return d.superClass_.constructor.apply(a, Array.prototype.slice.call(arguments, 1))
  }
  for(var e = Array.prototype.slice.call(arguments, 2), f = !1, g = a.constructor;g;g = g.superClass_ && g.superClass_.constructor) {
    if(g.prototype[b] === d) {
      f = !0
    }else {
      if(f) {
        return g.prototype[b].apply(a, e)
      }
    }
  }
  if(a[b] === d) {
    return a.constructor.prototype[b].apply(a, e)
  }
  throw Error("goog.base called from a method of one name to a method of a different name");
};
goog.scope = function(a) {
  a.call(goog.global)
};
var USE_TYPEDARRAY = "undefined" !== typeof Uint8Array && "undefined" !== typeof Uint16Array && "undefined" !== typeof Uint32Array;
var Zlib = {BitStream:function(a, b) {
  this.index = "number" === typeof b ? b : 0;
  this.bitindex = 0;
  this.buffer = a instanceof (USE_TYPEDARRAY ? Uint8Array : Array) ? a : new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.BitStream.DefaultBlockSize);
  if(2 * this.buffer.length <= this.index) {
    throw Error("invalid index");
  }
  this.buffer.length <= this.index && this.expandBuffer()
}};
Zlib.BitStream.DefaultBlockSize = 32768;
Zlib.BitStream.prototype.expandBuffer = function() {
  var a = this.buffer, b, c = a.length, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(c << 1);
  if(USE_TYPEDARRAY) {
    d.set(a)
  }else {
    for(b = 0;b < c;++b) {
      d[b] = a[b]
    }
  }
  return this.buffer = d
};
Zlib.BitStream.prototype.writeBits = function(a, b, c) {
  var d = this.buffer, e = this.index, f = this.bitindex, g = d[e];
  c && 1 < b && (a = 8 < b ? (Zlib.BitStream.ReverseTable[a & 255] << 24 | Zlib.BitStream.ReverseTable[a >>> 8 & 255] << 16 | Zlib.BitStream.ReverseTable[a >>> 16 & 255] << 8 | Zlib.BitStream.ReverseTable[a >>> 24 & 255]) >> 32 - b : Zlib.BitStream.ReverseTable[a] >> 8 - b);
  if(8 > b + f) {
    g = g << b | a, f += b
  }else {
    for(c = 0;c < b;++c) {
      g = g << 1 | a >> b - c - 1 & 1, 8 === ++f && (f = 0, d[e++] = Zlib.BitStream.ReverseTable[g], g = 0, e === d.length && (d = this.expandBuffer()))
    }
  }
  d[e] = g;
  this.buffer = d;
  this.bitindex = f;
  this.index = e
};
Zlib.BitStream.prototype.finish = function() {
  var a = this.buffer, b = this.index;
  0 < this.bitindex && (a[b] <<= 8 - this.bitindex, a[b] = Zlib.BitStream.ReverseTable[a[b]], b++);
  USE_TYPEDARRAY ? a = a.subarray(0, b) : a.length = b;
  return a
};
Zlib.BitStream.ReverseTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(256), b;
  for(b = 0;256 > b;++b) {
    for(var c = a, d = b, e = b, f = e, g = 7, e = e >>> 1;e;e >>>= 1) {
      f <<= 1, f |= e & 1, --g
    }
    c[d] = (f << g & 255) >>> 0
  }
  return a
}());
Zlib.CRC32 = {};
Zlib.CRC32.calc = function(a, b, c) {
  return Zlib.CRC32.update(a, 0, b, c)
};
Zlib.CRC32.update = function(a, b, c, d) {
  for(var e = Zlib.CRC32.Table, f = "number" === typeof c ? c : c = 0, d = "number" === typeof d ? d : a.length, b = b ^ 4294967295, f = d & 7;f--;++c) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255]
  }
  for(f = d >> 3;f--;c += 8) {
    b = b >>> 8 ^ e[(b ^ a[c]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 1]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 2]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 3]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 4]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 5]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 6]) & 255], b = b >>> 8 ^ e[(b ^ a[c + 7]) & 255]
  }
  return(b ^ 4294967295) >>> 0
};
Zlib.CRC32.Table = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}([0, 1996959894, 3993919788, 2567524794, 124634137, 1886057615, 3915621685, 2657392035, 249268274, 2044508324, 3772115230, 2547177864, 162941995, 2125561021, 3887607047, 2428444049, 498536548, 1789927666, 4089016648, 2227061214, 450548861, 1843258603, 4107580753, 2211677639, 325883990, 1684777152, 4251122042, 2321926636, 335633487, 1661365465, 4195302755, 2366115317, 997073096, 1281953886, 3579855332, 2724688242, 1006888145, 1258607687, 3524101629, 2768942443, 901097722, 1119000684, 3686517206, 
2898065728, 853044451, 1172266101, 3705015759, 2882616665, 651767980, 1373503546, 3369554304, 3218104598, 565507253, 1454621731, 3485111705, 3099436303, 671266974, 1594198024, 3322730930, 2970347812, 795835527, 1483230225, 3244367275, 3060149565, 1994146192, 31158534, 2563907772, 4023717930, 1907459465, 112637215, 2680153253, 3904427059, 2013776290, 251722036, 2517215374, 3775830040, 2137656763, 141376813, 2439277719, 3865271297, 1802195444, 476864866, 2238001368, 4066508878, 1812370925, 453092731, 
2181625025, 4111451223, 1706088902, 314042704, 2344532202, 4240017532, 1658658271, 366619977, 2362670323, 4224994405, 1303535960, 984961486, 2747007092, 3569037538, 1256170817, 1037604311, 2765210733, 3554079995, 1131014506, 879679996, 2909243462, 3663771856, 1141124467, 855842277, 2852801631, 3708648649, 1342533948, 654459306, 3188396048, 3373015174, 1466479909, 544179635, 3110523913, 3462522015, 1591671054, 702138776, 2966460450, 3352799412, 1504918807, 783551873, 3082640443, 3233442989, 3988292384, 
2596254646, 62317068, 1957810842, 3939845945, 2647816111, 81470997, 1943803523, 3814918930, 2489596804, 225274430, 2053790376, 3826175755, 2466906013, 167816743, 2097651377, 4027552580, 2265490386, 503444072, 1762050814, 4150417245, 2154129355, 426522225, 1852507879, 4275313526, 2312317920, 282753626, 1742555852, 4189708143, 2394877945, 397917763, 1622183637, 3604390888, 2714866558, 953729732, 1340076626, 3518719985, 2797360999, 1068828381, 1219638859, 3624741850, 2936675148, 906185462, 1090812512, 
3747672003, 2825379669, 829329135, 1181335161, 3412177804, 3160834842, 628085408, 1382605366, 3423369109, 3138078467, 570562233, 1426400815, 3317316542, 2998733608, 733239954, 1555261956, 3268935591, 3050360625, 752459403, 1541320221, 2607071920, 3965973030, 1969922972, 40735498, 2617837225, 3943577151, 1913087877, 83908371, 2512341634, 3803740692, 2075208622, 213261112, 2463272603, 3855990285, 2094854071, 198958881, 2262029012, 4057260610, 1759359992, 534414190, 2176718541, 4139329115, 1873836001, 
414664567, 2282248934, 4279200368, 1711684554, 285281116, 2405801727, 4167216745, 1634467795, 376229701, 2685067896, 3608007406, 1308918612, 956543938, 2808555105, 3495958263, 1231636301, 1047427035, 2932959818, 3654703836, 1088359270, 936918E3, 2847714899, 3736837829, 1202900863, 817233897, 3183342108, 3401237130, 1404277552, 615818150, 3134207493, 3453421203, 1423857449, 601450431, 3009837614, 3294710456, 1567103746, 711928724, 3020668471, 3272380065, 1510334235, 755167117]);
Zlib.exportObject = function(a, b) {
  var c, d, e, f;
  if(Object.keys) {
    c = Object.keys(b)
  }else {
    for(d in c = [], e = 0, b) {
      c[e++] = d
    }
  }
  e = 0;
  for(f = c.length;e < f;++e) {
    d = c[e], goog.exportSymbol(a + "." + d, b[d])
  }
};
Zlib.GunzipMember = function() {
};
Zlib.GunzipMember.prototype.getName = function() {
  return this.name
};
Zlib.GunzipMember.prototype.getData = function() {
  return this.data
};
Zlib.GunzipMember.prototype.getMtime = function() {
  return this.mtime
};
Zlib.Heap = function(a) {
  this.buffer = new (USE_TYPEDARRAY ? Uint16Array : Array)(2 * a);
  this.length = 0
};
Zlib.Heap.prototype.getParent = function(a) {
  return 2 * ((a - 2) / 4 | 0)
};
Zlib.Heap.prototype.getChild = function(a) {
  return 2 * a + 2
};
Zlib.Heap.prototype.push = function(a, b) {
  var c, d, e = this.buffer, f;
  c = this.length;
  e[this.length++] = b;
  for(e[this.length++] = a;0 < c;) {
    if(d = this.getParent(c), e[c] > e[d]) {
      f = e[c], e[c] = e[d], e[d] = f, f = e[c + 1], e[c + 1] = e[d + 1], e[d + 1] = f, c = d
    }else {
      break
    }
  }
  return this.length
};
Zlib.Heap.prototype.pop = function() {
  var a, b, c = this.buffer, d, e, f;
  b = c[0];
  a = c[1];
  this.length -= 2;
  c[0] = c[this.length];
  c[1] = c[this.length + 1];
  for(f = 0;;) {
    e = this.getChild(f);
    if(e >= this.length) {
      break
    }
    e + 2 < this.length && c[e + 2] > c[e] && (e += 2);
    if(c[e] > c[f]) {
      d = c[f], c[f] = c[e], c[e] = d, d = c[f + 1], c[f + 1] = c[e + 1], c[e + 1] = d
    }else {
      break
    }
    f = e
  }
  return{index:a, value:b, length:this.length}
};
Zlib.Huffman = {};
Zlib.Huffman.buildHuffmanTable = function(a) {
  var b = a.length, c = 0, d = Number.POSITIVE_INFINITY, e, f, g, h, i, j, l, m, k;
  for(m = 0;m < b;++m) {
    a[m] > c && (c = a[m]), a[m] < d && (d = a[m])
  }
  e = 1 << c;
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(e);
  g = 1;
  h = 0;
  for(i = 2;g <= c;) {
    for(m = 0;m < b;++m) {
      if(a[m] === g) {
        j = 0;
        l = h;
        for(k = 0;k < g;++k) {
          j = j << 1 | l & 1, l >>= 1
        }
        for(k = j;k < e;k += i) {
          f[k] = g << 16 | m
        }
        ++h
      }
    }
    ++g;
    h <<= 1;
    i <<= 1
  }
  return[f, c, d]
};
Zlib.RawDeflate = function(a, b) {
  this.compressionType = Zlib.RawDeflate.CompressionType.DYNAMIC;
  this.lazy = 0;
  this.input = a;
  this.op = 0;
  b && (b.lazy && (this.lazy = b.lazy), "number" === typeof b.compressionType && (this.compressionType = b.compressionType), b.outputBuffer && (this.output = USE_TYPEDARRAY && b.outputBuffer instanceof Array ? new Uint8Array(b.outputBuffer) : b.outputBuffer), "number" === typeof b.outputIndex && (this.op = b.outputIndex));
  this.output || (this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(32768))
};
Zlib.RawDeflate.CompressionType = {NONE:0, FIXED:1, DYNAMIC:2, RESERVED:3};
Zlib.RawDeflate.Lz77MinLength = 3;
Zlib.RawDeflate.Lz77MaxLength = 258;
Zlib.RawDeflate.WindowSize = 32768;
Zlib.RawDeflate.MaxCodeLength = 16;
Zlib.RawDeflate.HUFMAX = 286;
Zlib.RawDeflate.FixedHuffmanTable = function() {
  var a = [], b;
  for(b = 0;288 > b;b++) {
    switch(!0) {
      case 143 >= b:
        a.push([b + 48, 8]);
        break;
      case 255 >= b:
        a.push([b - 144 + 400, 9]);
        break;
      case 279 >= b:
        a.push([b - 256 + 0, 7]);
        break;
      case 287 >= b:
        a.push([b - 280 + 192, 8]);
        break;
      default:
        throw"invalid literal: " + b;
    }
  }
  return a
}();
Zlib.RawDeflate.prototype.compress = function() {
  var a, b, c, d = this.input;
  switch(this.compressionType) {
    case Zlib.RawDeflate.CompressionType.NONE:
      b = 0;
      for(c = d.length;b < c;) {
        a = USE_TYPEDARRAY ? d.subarray(b, b + 65535) : d.slice(b, b + 65535), b += a.length, this.makeNocompressBlock(a, b === c)
      }
      break;
    case Zlib.RawDeflate.CompressionType.FIXED:
      this.output = this.makeFixedHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    case Zlib.RawDeflate.CompressionType.DYNAMIC:
      this.output = this.makeDynamicHuffmanBlock(d, !0);
      this.op = this.output.length;
      break;
    default:
      throw"invalid compression type";
  }
  return this.output
};
Zlib.RawDeflate.prototype.makeNocompressBlock = function(a, b) {
  var c, d, e = this.output, f = this.op;
  if(USE_TYPEDARRAY) {
    for(e = new Uint8Array(this.output.buffer);e.length <= f + a.length + 5;) {
      e = new Uint8Array(e.length << 1)
    }
    e.set(this.output)
  }
  c = Zlib.RawDeflate.CompressionType.NONE;
  e[f++] = (b ? 1 : 0) | c << 1;
  c = a.length;
  d = ~c + 65536 & 65535;
  e[f++] = c & 255;
  e[f++] = c >>> 8 & 255;
  e[f++] = d & 255;
  e[f++] = d >>> 8 & 255;
  if(USE_TYPEDARRAY) {
    e.set(a, f), f += a.length, e = e.subarray(0, f)
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      e[f++] = a[c]
    }
    e.length = f
  }
  this.op = f;
  return this.output = e
};
Zlib.RawDeflate.prototype.makeFixedHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output.buffer), this.op), d;
  d = Zlib.RawDeflate.CompressionType.FIXED;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  this.fixedHuffman(d, c);
  return c.finish()
};
Zlib.RawDeflate.prototype.makeDynamicHuffmanBlock = function(a, b) {
  var c = new Zlib.BitStream(new Uint8Array(this.output), this.op), d, e, f, g, h = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15], i, j, l, m, k, n, q = Array(19), p;
  d = Zlib.RawDeflate.CompressionType.DYNAMIC;
  c.writeBits(b ? 1 : 0, 1, !0);
  c.writeBits(d, 2, !0);
  d = this.lz77(a);
  i = this.getLengths_(this.freqsLitLen, 15);
  j = this.getCodesFromLengths_(i);
  l = this.getLengths_(this.freqsDist, 7);
  m = this.getCodesFromLengths_(l);
  for(e = 286;257 < e && 0 === i[e - 1];e--) {
  }
  for(f = 30;1 < f && 0 === l[f - 1];f--) {
  }
  k = this.getTreeSymbols_(e, i, f, l);
  n = this.getLengths_(k.freqs, 7);
  for(p = 0;19 > p;p++) {
    q[p] = n[h[p]]
  }
  for(g = 19;4 < g && 0 === q[g - 1];g--) {
  }
  h = this.getCodesFromLengths_(n);
  c.writeBits(e - 257, 5, !0);
  c.writeBits(f - 1, 5, !0);
  c.writeBits(g - 4, 4, !0);
  for(p = 0;p < g;p++) {
    c.writeBits(q[p], 3, !0)
  }
  p = 0;
  for(q = k.codes.length;p < q;p++) {
    if(e = k.codes[p], c.writeBits(h[e], n[e], !0), 16 <= e) {
      p++;
      switch(e) {
        case 16:
          e = 2;
          break;
        case 17:
          e = 3;
          break;
        case 18:
          e = 7;
          break;
        default:
          throw"invalid code: " + e;
      }
      c.writeBits(k.codes[p], e, !0)
    }
  }
  this.dynamicHuffman(d, [j, i], [m, l], c);
  return c.finish()
};
Zlib.RawDeflate.prototype.dynamicHuffman = function(a, b, c, d) {
  var e, f, g, h, i;
  g = b[0];
  b = b[1];
  h = c[0];
  i = c[1];
  c = 0;
  for(e = a.length;c < e;++c) {
    if(f = a[c], d.writeBits(g[f], b[f], !0), 256 < f) {
      d.writeBits(a[++c], a[++c], !0), f = a[++c], d.writeBits(h[f], i[f], !0), d.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === f) {
        break
      }
    }
  }
  return d
};
Zlib.RawDeflate.prototype.fixedHuffman = function(a, b) {
  var c, d, e;
  c = 0;
  for(d = a.length;c < d;c++) {
    if(e = a[c], Zlib.BitStream.prototype.writeBits.apply(b, Zlib.RawDeflate.FixedHuffmanTable[e]), 256 < e) {
      b.writeBits(a[++c], a[++c], !0), b.writeBits(a[++c], 5), b.writeBits(a[++c], a[++c], !0)
    }else {
      if(256 === e) {
        break
      }
    }
  }
  return b
};
Zlib.RawDeflate.Lz77Match = function(a, b) {
  this.length = a;
  this.backwardDistance = b
};
Zlib.RawDeflate.Lz77Match.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint32Array(a) : a
}(function() {
  function a(a) {
    switch(!0) {
      case 3 === a:
        return[257, a - 3, 0];
      case 4 === a:
        return[258, a - 4, 0];
      case 5 === a:
        return[259, a - 5, 0];
      case 6 === a:
        return[260, a - 6, 0];
      case 7 === a:
        return[261, a - 7, 0];
      case 8 === a:
        return[262, a - 8, 0];
      case 9 === a:
        return[263, a - 9, 0];
      case 10 === a:
        return[264, a - 10, 0];
      case 12 >= a:
        return[265, a - 11, 1];
      case 14 >= a:
        return[266, a - 13, 1];
      case 16 >= a:
        return[267, a - 15, 1];
      case 18 >= a:
        return[268, a - 17, 1];
      case 22 >= a:
        return[269, a - 19, 2];
      case 26 >= a:
        return[270, a - 23, 2];
      case 30 >= a:
        return[271, a - 27, 2];
      case 34 >= a:
        return[272, a - 31, 2];
      case 42 >= a:
        return[273, a - 35, 3];
      case 50 >= a:
        return[274, a - 43, 3];
      case 58 >= a:
        return[275, a - 51, 3];
      case 66 >= a:
        return[276, a - 59, 3];
      case 82 >= a:
        return[277, a - 67, 4];
      case 98 >= a:
        return[278, a - 83, 4];
      case 114 >= a:
        return[279, a - 99, 4];
      case 130 >= a:
        return[280, a - 115, 4];
      case 162 >= a:
        return[281, a - 131, 5];
      case 194 >= a:
        return[282, a - 163, 5];
      case 226 >= a:
        return[283, a - 195, 5];
      case 257 >= a:
        return[284, a - 227, 5];
      case 258 === a:
        return[285, a - 258, 0];
      default:
        throw"invalid length: " + a;
    }
  }
  var b = [], c, d;
  for(c = 3;258 >= c;c++) {
    d = a(c), b[c] = d[2] << 24 | d[1] << 16 | d[0]
  }
  return b
}());
Zlib.RawDeflate.Lz77Match.prototype.getDistanceCode_ = function(a) {
  switch(!0) {
    case 1 === a:
      a = [0, a - 1, 0];
      break;
    case 2 === a:
      a = [1, a - 2, 0];
      break;
    case 3 === a:
      a = [2, a - 3, 0];
      break;
    case 4 === a:
      a = [3, a - 4, 0];
      break;
    case 6 >= a:
      a = [4, a - 5, 1];
      break;
    case 8 >= a:
      a = [5, a - 7, 1];
      break;
    case 12 >= a:
      a = [6, a - 9, 2];
      break;
    case 16 >= a:
      a = [7, a - 13, 2];
      break;
    case 24 >= a:
      a = [8, a - 17, 3];
      break;
    case 32 >= a:
      a = [9, a - 25, 3];
      break;
    case 48 >= a:
      a = [10, a - 33, 4];
      break;
    case 64 >= a:
      a = [11, a - 49, 4];
      break;
    case 96 >= a:
      a = [12, a - 65, 5];
      break;
    case 128 >= a:
      a = [13, a - 97, 5];
      break;
    case 192 >= a:
      a = [14, a - 129, 6];
      break;
    case 256 >= a:
      a = [15, a - 193, 6];
      break;
    case 384 >= a:
      a = [16, a - 257, 7];
      break;
    case 512 >= a:
      a = [17, a - 385, 7];
      break;
    case 768 >= a:
      a = [18, a - 513, 8];
      break;
    case 1024 >= a:
      a = [19, a - 769, 8];
      break;
    case 1536 >= a:
      a = [20, a - 1025, 9];
      break;
    case 2048 >= a:
      a = [21, a - 1537, 9];
      break;
    case 3072 >= a:
      a = [22, a - 2049, 10];
      break;
    case 4096 >= a:
      a = [23, a - 3073, 10];
      break;
    case 6144 >= a:
      a = [24, a - 4097, 11];
      break;
    case 8192 >= a:
      a = [25, a - 6145, 11];
      break;
    case 12288 >= a:
      a = [26, a - 8193, 12];
      break;
    case 16384 >= a:
      a = [27, a - 12289, 12];
      break;
    case 24576 >= a:
      a = [28, a - 16385, 13];
      break;
    case 32768 >= a:
      a = [29, a - 24577, 13];
      break;
    default:
      throw"invalid distance";
  }
  return a
};
Zlib.RawDeflate.Lz77Match.prototype.toLz77Array = function() {
  var a = this.backwardDistance, b = [], c = 0, d;
  d = Zlib.RawDeflate.Lz77Match.LengthCodeTable[this.length];
  b[c++] = d & 65535;
  b[c++] = d >> 16 & 255;
  b[c++] = d >> 24;
  d = this.getDistanceCode_(a);
  b[c++] = d[0];
  b[c++] = d[1];
  b[c++] = d[2];
  return b
};
Zlib.RawDeflate.prototype.lz77 = function(a) {
  function b(a, b) {
    var c = a.toLz77Array(), d, e;
    d = 0;
    for(e = c.length;d < e;++d) {
      l[m++] = c[d]
    }
    n[c[0]]++;
    q[c[3]]++;
    k = a.length + b - 1;
    j = null
  }
  var c, d, e, f, g, h = {}, i = Zlib.RawDeflate.WindowSize, j, l = USE_TYPEDARRAY ? new Uint16Array(2 * a.length) : [], m = 0, k = 0, n = new (USE_TYPEDARRAY ? Uint32Array : Array)(286), q = new (USE_TYPEDARRAY ? Uint32Array : Array)(30), p = this.lazy;
  if(!USE_TYPEDARRAY) {
    for(e = 0;285 >= e;) {
      n[e++] = 0
    }
    for(e = 0;29 >= e;) {
      q[e++] = 0
    }
  }
  n[256] = 1;
  c = 0;
  for(d = a.length;c < d;++c) {
    e = g = 0;
    for(f = Zlib.RawDeflate.Lz77MinLength;e < f && c + e !== d;++e) {
      g = g << 8 | a[c + e]
    }
    void 0 === h[g] && (h[g] = []);
    e = h[g];
    if(!(0 < k--)) {
      for(;0 < e.length && c - e[0] > i;) {
        e.shift()
      }
      if(c + Zlib.RawDeflate.Lz77MinLength >= d) {
        j && b(j, -1);
        e = 0;
        for(f = d - c;e < f;++e) {
          g = a[c + e], l[m++] = g, ++n[g]
        }
        break
      }
      0 < e.length ? (f = this.searchLongestMatch_(a, c, e), j ? j.length < f.length ? (g = a[c - 1], l[m++] = g, ++n[g], b(f, 0)) : b(j, -1) : f.length < p ? j = f : b(f, 0)) : j ? b(j, -1) : (g = a[c], l[m++] = g, ++n[g])
    }
    e.push(c)
  }
  l[m++] = 256;
  n[256]++;
  this.freqsLitLen = n;
  this.freqsDist = q;
  return USE_TYPEDARRAY ? l.subarray(0, m) : l
};
Zlib.RawDeflate.prototype.searchLongestMatch_ = function(a, b, c) {
  var d, e, f = 0, g, h, i, j = a.length;
  h = 0;
  i = c.length;
  a:for(;h < i;h++) {
    d = c[i - h - 1];
    g = Zlib.RawDeflate.Lz77MinLength;
    if(f > Zlib.RawDeflate.Lz77MinLength) {
      for(g = f;g > Zlib.RawDeflate.Lz77MinLength;g--) {
        if(a[d + g - 1] !== a[b + g - 1]) {
          continue a
        }
      }
      g = f
    }
    for(;g < Zlib.RawDeflate.Lz77MaxLength && b + g < j && a[d + g] === a[b + g];) {
      ++g
    }
    g > f && (e = d, f = g);
    if(g === Zlib.RawDeflate.Lz77MaxLength) {
      break
    }
  }
  return new Zlib.RawDeflate.Lz77Match(f, b - e)
};
Zlib.RawDeflate.prototype.getTreeSymbols_ = function(a, b, c, d) {
  var e = new (USE_TYPEDARRAY ? Uint32Array : Array)(a + c), f, g, h = new (USE_TYPEDARRAY ? Uint32Array : Array)(316), i = new (USE_TYPEDARRAY ? Uint8Array : Array)(19);
  for(f = g = 0;f < a;f++) {
    e[g++] = b[f]
  }
  for(f = 0;f < c;f++) {
    e[g++] = d[f]
  }
  if(!USE_TYPEDARRAY) {
    f = 0;
    for(b = i.length;f < b;++f) {
      i[f] = 0
    }
  }
  f = c = 0;
  for(b = e.length;f < b;f += g) {
    for(g = 1;f + g < b && e[f + g] === e[f];++g) {
    }
    a = g;
    if(0 === e[f]) {
      if(3 > a) {
        for(;0 < a--;) {
          h[c++] = 0, i[0]++
        }
      }else {
        for(;0 < a;) {
          d = 138 > a ? a : 138, d > a - 3 && d < a && (d = a - 3), 10 >= d ? (h[c++] = 17, h[c++] = d - 3, i[17]++) : (h[c++] = 18, h[c++] = d - 11, i[18]++), a -= d
        }
      }
    }else {
      if(h[c++] = e[f], i[e[f]]++, a--, 3 > a) {
        for(;0 < a--;) {
          h[c++] = e[f], i[e[f]]++
        }
      }else {
        for(;0 < a;) {
          d = 6 > a ? a : 6, d > a - 3 && d < a && (d = a - 3), h[c++] = 16, h[c++] = d - 3, i[16]++, a -= d
        }
      }
    }
  }
  return{codes:USE_TYPEDARRAY ? h.subarray(0, c) : h.slice(0, c), freqs:i}
};
Zlib.RawDeflate.prototype.getLengths_ = function(a, b) {
  var c = a.length, d = new Zlib.Heap(2 * Zlib.RawDeflate.HUFMAX), e = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), f, g, h;
  if(!USE_TYPEDARRAY) {
    for(g = 0;g < c;g++) {
      e[g] = 0
    }
  }
  for(g = 0;g < c;++g) {
    0 < a[g] && d.push(g, a[g])
  }
  c = Array(d.length / 2);
  f = new (USE_TYPEDARRAY ? Uint32Array : Array)(d.length / 2);
  if(1 === c.length) {
    return e[d.pop().index] = 1, e
  }
  g = 0;
  for(h = d.length / 2;g < h;++g) {
    c[g] = d.pop(), f[g] = c[g].value
  }
  d = this.reversePackageMerge_(f, f.length, b);
  g = 0;
  for(h = c.length;g < h;++g) {
    e[c[g].index] = d[g]
  }
  return e
};
Zlib.RawDeflate.prototype.reversePackageMerge_ = function(a, b, c) {
  function d(a) {
    var c = i[a][j[a]];
    c === b ? (d(a + 1), d(a + 1)) : --g[c];
    ++j[a]
  }
  var e = new (USE_TYPEDARRAY ? Uint16Array : Array)(c), f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c), g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b), h = Array(c), i = Array(c), j = Array(c), l = (1 << c) - b, m = 1 << c - 1, k, n;
  e[c - 1] = b;
  for(k = 0;k < c;++k) {
    l < m ? f[k] = 0 : (f[k] = 1, l -= m), l <<= 1, e[c - 2 - k] = (e[c - 1 - k] / 2 | 0) + b
  }
  e[0] = f[0];
  h[0] = Array(e[0]);
  i[0] = Array(e[0]);
  for(k = 1;k < c;++k) {
    e[k] > 2 * e[k - 1] + f[k] && (e[k] = 2 * e[k - 1] + f[k]), h[k] = Array(e[k]), i[k] = Array(e[k])
  }
  for(l = 0;l < b;++l) {
    g[l] = c
  }
  for(m = 0;m < e[c - 1];++m) {
    h[c - 1][m] = a[m], i[c - 1][m] = m
  }
  for(l = 0;l < c;++l) {
    j[l] = 0
  }
  1 === f[c - 1] && (--g[0], ++j[c - 1]);
  for(k = c - 2;0 <= k;--k) {
    c = l = 0;
    n = j[k + 1];
    for(m = 0;m < e[k];m++) {
      c = h[k + 1][n] + h[k + 1][n + 1], c > a[l] ? (h[k][m] = c, i[k][m] = b, n += 2) : (h[k][m] = a[l], i[k][m] = l, ++l)
    }
    j[k] = 0;
    1 === f[k] && d(k)
  }
  return g
};
Zlib.RawDeflate.prototype.getCodesFromLengths_ = function(a) {
  var b = new (USE_TYPEDARRAY ? Uint16Array : Array)(a.length), c = [], d = [], e = 0, f, g, h;
  f = 0;
  for(g = a.length;f < g;f++) {
    c[a[f]] = (c[a[f]] | 0) + 1
  }
  f = 1;
  for(g = Zlib.RawDeflate.MaxCodeLength;f <= g;f++) {
    d[f] = e, e += c[f] | 0, e <<= 1
  }
  f = 0;
  for(g = a.length;f < g;f++) {
    e = d[a[f]];
    d[a[f]] += 1;
    c = b[f] = 0;
    for(h = a[f];c < h;c++) {
      b[f] = b[f] << 1 | e & 1, e >>>= 1
    }
  }
  return b
};
Zlib.Gzip = function(a, b) {
  this.input = a;
  this.op = this.ip = 0;
  this.flags = {};
  b && (b.flags && (this.flags = b.flags), "string" === typeof b.filename && (this.filename = b.filename), "string" === typeof b.comment && (this.comment = b.comment), b.deflateOptions && (this.deflateOptions = b.deflateOptions));
  this.deflateOptions || (this.deflateOptions = {})
};
Zlib.Gzip.DefaultBufferSize = 32768;
Zlib.Gzip.prototype.compress = function() {
  var a, b, c, d, e, f = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Gzip.DefaultBufferSize);
  c = 0;
  var g = this.input, h = this.ip;
  b = this.filename;
  var i = this.comment;
  f[c++] = 31;
  f[c++] = 139;
  f[c++] = 8;
  a = 0;
  this.flags.fname && (a |= Zlib.Gzip.FlagsMask.FNAME);
  this.flags.fcomment && (a |= Zlib.Gzip.FlagsMask.FCOMMENT);
  this.flags.fhcrc && (a |= Zlib.Gzip.FlagsMask.FHCRC);
  f[c++] = a;
  a = (Date.now ? Date.now() : +new Date) / 1E3 | 0;
  f[c++] = a & 255;
  f[c++] = a >>> 8 & 255;
  f[c++] = a >>> 16 & 255;
  f[c++] = a >>> 24 & 255;
  f[c++] = 0;
  f[c++] = Zlib.Gzip.OperatingSystem.UNKNOWN;
  if(void 0 !== this.flags.fname) {
    d = 0;
    for(e = b.length;d < e;++d) {
      a = b.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  if(this.flags.comment) {
    d = 0;
    for(e = i.length;d < e;++d) {
      a = i.charCodeAt(d), 255 < a && (f[c++] = a >>> 8 & 255), f[c++] = a & 255
    }
    f[c++] = 0
  }
  this.flags.fhcrc && (b = Zlib.CRC32.calc(f, 0, c) & 65535, f[c++] = b & 255, f[c++] = b >>> 8 & 255);
  this.deflateOptions.outputBuffer = f;
  this.deflateOptions.outputIndex = c;
  c = new Zlib.RawDeflate(g, this.deflateOptions);
  f = c.compress();
  c = c.op;
  USE_TYPEDARRAY && (c + 8 > f.buffer.byteLength ? (this.output = new Uint8Array(c + 8), this.output.set(new Uint8Array(f.buffer)), f = this.output) : f = new Uint8Array(f.buffer));
  b = Zlib.CRC32.calc(g);
  f[c++] = b & 255;
  f[c++] = b >>> 8 & 255;
  f[c++] = b >>> 16 & 255;
  f[c++] = b >>> 24 & 255;
  e = g.length;
  f[c++] = e & 255;
  f[c++] = e >>> 8 & 255;
  f[c++] = e >>> 16 & 255;
  f[c++] = e >>> 24 & 255;
  this.ip = h;
  USE_TYPEDARRAY && c < f.length && (this.output = f = f.subarray(0, c));
  return f
};
Zlib.Gzip.OperatingSystem = {FAT:0, AMIGA:1, VMS:2, UNIX:3, VM_CMS:4, ATARI_TOS:5, HPFS:6, MACINTOSH:7, Z_SYSTEM:8, CP_M:9, TOPS_20:10, NTFS:11, QDOS:12, ACORN_RISCOS:13, UNKNOWN:255};
Zlib.Gzip.FlagsMask = {FTEXT:1, FHCRC:2, FEXTRA:4, FNAME:8, FCOMMENT:16};
var ZLIB_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflate = function(a, b) {
  this.blocks = [];
  this.bufferSize = ZLIB_RAW_INFLATE_BUFFER_SIZE;
  this.bitsbuflen = this.bitsbuf = this.ip = this.totalpos = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.bfinal = !1;
  this.bufferType = Zlib.RawInflate.BufferType.ADAPTIVE;
  this.resize = !1;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.bufferSize && (this.bufferSize = b.bufferSize), b.bufferType && (this.bufferType = b.bufferType), b.resize && (this.resize = b.resize)
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      this.op = Zlib.RawInflate.MaxBackwardLength;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.MaxBackwardLength + this.bufferSize + Zlib.RawInflate.MaxCopyLength);
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      this.op = 0;
      this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
      this.expandBuffer = this.expandBufferAdaptive;
      this.concatBuffer = this.concatBufferDynamic;
      this.decodeHuffman = this.decodeHuffmanAdaptive;
      break;
    default:
      throw Error("invalid inflate mode");
  }
};
Zlib.RawInflate.BufferType = {BLOCK:0, ADAPTIVE:1};
Zlib.RawInflate.prototype.decompress = function() {
  for(;!this.bfinal;) {
    this.parseBlock()
  }
  return this.concatBuffer()
};
Zlib.RawInflate.MaxBackwardLength = 32768;
Zlib.RawInflate.MaxCopyLength = 258;
Zlib.RawInflate.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflate.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflate.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflate.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflate.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflate.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflate.prototype.parseBlock = function() {
  var a = this.readBits(3);
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.parseUncompressedBlock();
      break;
    case 1:
      this.parseFixedHuffmanBlock();
      break;
    case 2:
      this.parseDynamicHuffmanBlock();
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
};
Zlib.RawInflate.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      throw Error("input buffer is broken");
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflate.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      throw Error("input buffer is broken");
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflate.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e, f, g, h = c.length;
  this.bitsbuflen = this.bitsbuf = 0;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (first byte)");
  }
  f = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: LEN (second byte)");
  }
  f |= e << 8;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (first byte)");
  }
  g = e;
  e = a[b++];
  if(void 0 === e) {
    throw Error("invalid uncompressed block header: NLEN (second byte)");
  }
  if(f === ~(g | e << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  if(b + f > a.length) {
    throw Error("input buffer is broken");
  }
  switch(this.bufferType) {
    case Zlib.RawInflate.BufferType.BLOCK:
      for(;d + f > c.length;) {
        e = h - d;
        f -= e;
        if(USE_TYPEDARRAY) {
          c.set(a.subarray(b, b + e), d), d += e, b += e
        }else {
          for(;e--;) {
            c[d++] = a[b++]
          }
        }
        this.op = d;
        c = this.expandBuffer();
        d = this.op
      }
      break;
    case Zlib.RawInflate.BufferType.ADAPTIVE:
      for(;d + f > c.length;) {
        c = this.expandBuffer({fixRatio:2})
      }
      break;
    default:
      throw Error("invalid inflate mode");
  }
  if(USE_TYPEDARRAY) {
    c.set(a.subarray(b, b + f), d), d += f, b += f
  }else {
    for(;f--;) {
      c[d++] = a[b++]
    }
  }
  this.ip = b;
  this.op = d;
  this.output = c
};
Zlib.RawInflate.prototype.parseFixedHuffmanBlock = function() {
  this.decodeHuffman(Zlib.RawInflate.FixedLiteralLengthTable, Zlib.RawInflate.FixedDistanceTable)
};
Zlib.RawInflate.prototype.parseDynamicHuffmanBlock = function() {
  function a(a, b, c) {
    var d, e, f;
    for(f = 0;f < a;) {
      switch(d = this.readCodeByTable(b), d) {
        case 16:
          for(d = 3 + this.readBits(2);d--;) {
            c[f++] = e
          }
          break;
        case 17:
          for(d = 3 + this.readBits(3);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        case 18:
          for(d = 11 + this.readBits(7);d--;) {
            c[f++] = 0
          }
          e = 0;
          break;
        default:
          e = c[f++] = d
      }
    }
    return c
  }
  var b = this.readBits(5) + 257, c = this.readBits(5) + 1, d = this.readBits(4) + 4, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflate.Order.length), f;
  for(f = 0;f < d;++f) {
    e[Zlib.RawInflate.Order[f]] = this.readBits(3)
  }
  d = (0,Zlib.Huffman.buildHuffmanTable)(e);
  e = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
  f = new (USE_TYPEDARRAY ? Uint8Array : Array)(c);
  this.decodeHuffman((0,Zlib.Huffman.buildHuffmanTable)(a.call(this, b, d, e)), (0,Zlib.Huffman.buildHuffmanTable)(a.call(this, c, d, f)))
};
Zlib.RawInflate.prototype.decodeHuffman = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length - Zlib.RawInflate.MaxCopyLength, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d >= e && (this.op = d, c = this.expandBuffer(), d = this.op);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.decodeHuffmanAdaptive = function(a, b) {
  var c = this.output, d = this.op;
  this.currentLitlenTable = a;
  for(var e = c.length, f, g, h;256 !== (f = this.readCodeByTable(a));) {
    if(256 > f) {
      d >= e && (c = this.expandBuffer(), e = c.length), c[d++] = f
    }else {
      f -= 257;
      h = Zlib.RawInflate.LengthCodeTable[f];
      0 < Zlib.RawInflate.LengthExtraTable[f] && (h += this.readBits(Zlib.RawInflate.LengthExtraTable[f]));
      f = this.readCodeByTable(b);
      g = Zlib.RawInflate.DistCodeTable[f];
      0 < Zlib.RawInflate.DistExtraTable[f] && (g += this.readBits(Zlib.RawInflate.DistExtraTable[f]));
      d + h > e && (c = this.expandBuffer(), e = c.length);
      for(;h--;) {
        c[d] = c[d++ - g]
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = d
};
Zlib.RawInflate.prototype.expandBuffer = function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.op - Zlib.RawInflate.MaxBackwardLength), b = this.op - Zlib.RawInflate.MaxBackwardLength, c, d, e = this.output;
  if(USE_TYPEDARRAY) {
    a.set(e.subarray(Zlib.RawInflate.MaxBackwardLength, a.length))
  }else {
    c = 0;
    for(d = a.length;c < d;++c) {
      a[c] = e[c + Zlib.RawInflate.MaxBackwardLength]
    }
  }
  this.blocks.push(a);
  this.totalpos += a.length;
  if(USE_TYPEDARRAY) {
    e.set(e.subarray(b, b + Zlib.RawInflate.MaxBackwardLength))
  }else {
    for(c = 0;c < Zlib.RawInflate.MaxBackwardLength;++c) {
      e[c] = e[b + c]
    }
  }
  this.op = Zlib.RawInflate.MaxBackwardLength;
  return e
};
Zlib.RawInflate.prototype.expandBufferAdaptive = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.currentLitlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflate.prototype.concatBuffer = function() {
  var a = 0, b = this.output, c = this.blocks, d, e = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.totalpos + (this.op - Zlib.RawInflate.MaxBackwardLength)), f, g, h, i;
  if(0 === c.length) {
    return USE_TYPEDARRAY ? this.output.subarray(Zlib.RawInflate.MaxBackwardLength, this.op) : this.output.slice(Zlib.RawInflate.MaxBackwardLength, this.op)
  }
  f = 0;
  for(g = c.length;f < g;++f) {
    d = c[f];
    h = 0;
    for(i = d.length;h < i;++h) {
      e[a++] = d[h]
    }
  }
  f = Zlib.RawInflate.MaxBackwardLength;
  for(g = this.op;f < g;++f) {
    e[a++] = b[f]
  }
  this.blocks = [];
  return this.buffer = e
};
Zlib.RawInflate.prototype.concatBufferDynamic = function() {
  var a, b = this.op;
  USE_TYPEDARRAY ? this.resize ? (a = new Uint8Array(b), a.set(this.output.subarray(0, b))) : a = this.output.subarray(0, b) : (this.output.length > b && (this.output.length = b), a = this.output);
  return this.buffer = a
};
Zlib.Gunzip = function(a) {
  this.input = a;
  this.ip = 0;
  this.member = [];
  this.decompressed = !1
};
Zlib.Gunzip.prototype.getMembers = function() {
  this.decompressed || this.decompress();
  return this.member.slice()
};
Zlib.Gunzip.prototype.decompress = function() {
  for(var a = this.input.length;this.ip < a;) {
    this.decodeMember()
  }
  this.decompressed = !0;
  return this.concatMember()
};
Zlib.Gunzip.prototype.decodeMember = function() {
  var a = new Zlib.GunzipMember, b, c, d, e, f, g = this.input;
  c = this.ip;
  a.id1 = g[c++];
  a.id2 = g[c++];
  if(31 !== a.id1 || 139 !== a.id2) {
    throw Error("invalid file signature:" + a.id1 + "," + a.id2);
  }
  a.cm = g[c++];
  switch(a.cm) {
    case 8:
      break;
    default:
      throw Error("unknown compression method: " + a.cm);
  }
  a.flg = g[c++];
  b = g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24;
  a.mtime = new Date(1E3 * b);
  a.xfl = g[c++];
  a.os = g[c++];
  0 < (a.flg & Zlib.Gzip.FlagsMask.FEXTRA) && (a.xlen = g[c++] | g[c++] << 8, c = this.decodeSubField(c, a.xlen));
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FNAME)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.name = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FCOMMENT)) {
    f = [];
    for(e = 0;0 < (b = g[c++]);) {
      f[e++] = String.fromCharCode(b)
    }
    a.comment = f.join("")
  }
  if(0 < (a.flg & Zlib.Gzip.FlagsMask.FHCRC) && (a.crc16 = Zlib.CRC32.calc(g, 0, c) & 65535, a.crc16 !== (g[c++] | g[c++] << 8))) {
    throw Error("invalid header crc16");
  }
  b = g[g.length - 4] | g[g.length - 3] << 8 | g[g.length - 2] << 16 | g[g.length - 1] << 24;
  g.length - c - 4 - 4 < 512 * b && (d = b);
  c = new Zlib.RawInflate(g, {index:c, bufferSize:d});
  a.data = d = c.decompress();
  c = c.ip;
  a.crc32 = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if(Zlib.CRC32.calc(d) !== b) {
    throw Error("invalid CRC-32 checksum: 0x" + Zlib.CRC32.calc(d).toString(16) + " / 0x" + b.toString(16));
  }
  a.isize = b = (g[c++] | g[c++] << 8 | g[c++] << 16 | g[c++] << 24) >>> 0;
  if((d.length & 4294967295) !== b) {
    throw Error("invalid input size: " + (d.length & 4294967295) + " / " + b);
  }
  this.member.push(a);
  this.ip = c
};
Zlib.Gunzip.prototype.decodeSubField = function(a, b) {
  return a + b
};
Zlib.Gunzip.prototype.concatMember = function() {
  var a = this.member, b, c, d = 0, e = 0;
  b = 0;
  for(c = a.length;b < c;++b) {
    e += a[b].data.length
  }
  if(USE_TYPEDARRAY) {
    e = new Uint8Array(e);
    for(b = 0;b < c;++b) {
      e.set(a[b].data, d), d += a[b].data.length
    }
  }else {
    e = [];
    for(b = 0;b < c;++b) {
      e[b] = a[b].data
    }
    e = Array.prototype.concat.apply([], e)
  }
  return e
};
var ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE = 32768;
Zlib.RawInflateStream = function(a, b, c) {
  this.blocks = [];
  this.bufferSize = c ? c : ZLIB_STREAM_RAW_INFLATE_BUFFER_SIZE;
  this.totalpos = 0;
  this.ip = void 0 === b ? 0 : b;
  this.bitsbuflen = this.bitsbuf = 0;
  this.input = USE_TYPEDARRAY ? new Uint8Array(a) : a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(this.bufferSize);
  this.op = 0;
  this.resize = this.bfinal = !1;
  this.sp = 0;
  this.status = Zlib.RawInflateStream.Status.INITIALIZED
};
Zlib.RawInflateStream.BlockType = {UNCOMPRESSED:0, FIXED:1, DYNAMIC:2};
Zlib.RawInflateStream.Status = {INITIALIZED:0, BLOCK_HEADER_START:1, BLOCK_HEADER_END:2, BLOCK_BODY_START:3, BLOCK_BODY_END:4, DECODE_BLOCK_START:5, DECODE_BLOCK_END:6};
Zlib.RawInflateStream.prototype.decompress = function(a, b) {
  var c = !1;
  void 0 !== a && (this.input = a);
  void 0 !== b && (this.ip = b);
  for(;!c;) {
    switch(this.status) {
      case Zlib.RawInflateStream.Status.INITIALIZED:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_START:
        0 > this.readBlockHeader() && (c = !0);
        break;
      case Zlib.RawInflateStream.Status.BLOCK_HEADER_END:
      ;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.readUncompressedBlockHeader() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
            0 > this.parseFixedHuffmanBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.parseDynamicHuffmanBlock() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.BLOCK_BODY_END:
      ;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_START:
        switch(this.currentBlockType) {
          case Zlib.RawInflateStream.BlockType.UNCOMPRESSED:
            0 > this.parseUncompressedBlock() && (c = !0);
            break;
          case Zlib.RawInflateStream.BlockType.FIXED:
          ;
          case Zlib.RawInflateStream.BlockType.DYNAMIC:
            0 > this.decodeHuffman() && (c = !0)
        }
        break;
      case Zlib.RawInflateStream.Status.DECODE_BLOCK_END:
        this.bfinal ? c = !0 : this.status = Zlib.RawInflateStream.Status.INITIALIZED
    }
  }
  return this.concatBuffer()
};
Zlib.RawInflateStream.MaxBackwardLength = 32768;
Zlib.RawInflateStream.MaxCopyLength = 258;
Zlib.RawInflateStream.Order = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]);
Zlib.RawInflateStream.LengthCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 258, 258]);
Zlib.RawInflateStream.LengthExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 0, 0]);
Zlib.RawInflateStream.DistCodeTable = function(a) {
  return USE_TYPEDARRAY ? new Uint16Array(a) : a
}([1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]);
Zlib.RawInflateStream.DistExtraTable = function(a) {
  return USE_TYPEDARRAY ? new Uint8Array(a) : a
}([0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]);
Zlib.RawInflateStream.FixedLiteralLengthTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(288), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 143 >= b ? 8 : 255 >= b ? 9 : 279 >= b ? 7 : 8
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.FixedDistanceTable = function(a) {
  return a
}(function() {
  var a = new (USE_TYPEDARRAY ? Uint8Array : Array)(30), b, c;
  b = 0;
  for(c = a.length;b < c;++b) {
    a[b] = 5
  }
  return(0,Zlib.Huffman.buildHuffmanTable)(a)
}());
Zlib.RawInflateStream.prototype.readBlockHeader = function() {
  var a;
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_START;
  this.save_();
  if(0 > (a = this.readBits(3))) {
    return this.restore_(), -1
  }
  a & 1 && (this.bfinal = !0);
  a >>>= 1;
  switch(a) {
    case 0:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.UNCOMPRESSED;
      break;
    case 1:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.FIXED;
      break;
    case 2:
      this.currentBlockType = Zlib.RawInflateStream.BlockType.DYNAMIC;
      break;
    default:
      throw Error("unknown BTYPE: " + a);
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_HEADER_END
};
Zlib.RawInflateStream.prototype.readBits = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f;c < a;) {
    f = d[e++];
    if(void 0 === f) {
      return-1
    }
    b |= f << c;
    c += 8
  }
  f = b & (1 << a) - 1;
  this.bitsbuf = b >>> a;
  this.bitsbuflen = c - a;
  this.ip = e;
  return f
};
Zlib.RawInflateStream.prototype.readCodeByTable = function(a) {
  for(var b = this.bitsbuf, c = this.bitsbuflen, d = this.input, e = this.ip, f = a[0], a = a[1], g;c < a;) {
    g = d[e++];
    if(void 0 === g) {
      return-1
    }
    b |= g << c;
    c += 8
  }
  d = f[b & (1 << a) - 1];
  f = d >>> 16;
  this.bitsbuf = b >> f;
  this.bitsbuflen = c - f;
  this.ip = e;
  return d & 65535
};
Zlib.RawInflateStream.prototype.readUncompressedBlockHeader = function() {
  var a, b, c, d = this.input, e = this.ip;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  b |= a << 8;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  c = a;
  a = d[e++];
  if(void 0 === a) {
    return-1
  }
  if(b === ~(c | a << 8)) {
    throw Error("invalid uncompressed block header: length verify");
  }
  this.bitsbuflen = this.bitsbuf = 0;
  this.ip = e;
  this.blockLength = b;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END
};
Zlib.RawInflateStream.prototype.parseUncompressedBlock = function() {
  var a = this.input, b = this.ip, c = this.output, d = this.op, e = this.blockLength;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;e--;) {
    d === c.length && (c = this.expandBuffer());
    if(void 0 === a[b]) {
      return this.ip = b, this.op = d, this.blockLength = e + 1, -1
    }
    c[d++] = a[b++]
  }
  0 > e && (this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END);
  this.ip = b;
  this.op = d;
  return 0
};
Zlib.RawInflateStream.prototype.parseFixedHuffmanBlock = function() {
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.litlenTable = Zlib.RawInflateStream.FixedLiteralLengthTable;
  this.distTable = Zlib.RawInflateStream.FixedDistanceTable;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.save_ = function() {
  this.ip_ = this.ip;
  this.bitsbuflen_ = this.bitsbuflen;
  this.bitsbuf_ = this.bitsbuf
};
Zlib.RawInflateStream.prototype.restore_ = function() {
  this.ip = this.ip_;
  this.bitsbuflen = this.bitsbuflen_;
  this.bitsbuf = this.bitsbuf_
};
Zlib.RawInflateStream.prototype.parseDynamicHuffmanBlock = function() {
  var a, b, c, d = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.RawInflateStream.Order.length), e, f, g, h = 0;
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_START;
  this.save_();
  a = this.readBits(5) + 257;
  b = this.readBits(5) + 1;
  c = this.readBits(4) + 4;
  if(0 > a || 0 > b || 0 > c) {
    return this.restore_(), -1
  }
  try {
    for(var i = function(a, b, c) {
      for(var d, e, f = 0, f = 0;f < a;) {
        d = this.readCodeByTable(b);
        if(0 > d) {
          throw Error("not enough input");
        }
        switch(d) {
          case 16:
            if(0 > (d = this.readBits(2))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = e
            }
            break;
          case 17:
            if(0 > (d = this.readBits(3))) {
              throw Error("not enough input");
            }
            for(d = 3 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          case 18:
            if(0 > (d = this.readBits(7))) {
              throw Error("not enough input");
            }
            for(d = 11 + d;d--;) {
              c[f++] = 0
            }
            e = 0;
            break;
          default:
            e = c[f++] = d
        }
      }
      return c
    }, j, h = 0;h < c;++h) {
      if(0 > (j = this.readBits(3))) {
        throw Error("not enough input");
      }
      d[Zlib.RawInflateStream.Order[h]] = j
    }
    e = (0,Zlib.Huffman.buildHuffmanTable)(d);
    f = new (USE_TYPEDARRAY ? Uint8Array : Array)(a);
    g = new (USE_TYPEDARRAY ? Uint8Array : Array)(b);
    this.litlenTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, a, e, f));
    this.distTable = (0,Zlib.Huffman.buildHuffmanTable)(i.call(this, b, e, g))
  }catch(l) {
    return this.restore_(), -1
  }
  this.status = Zlib.RawInflateStream.Status.BLOCK_BODY_END;
  return 0
};
Zlib.RawInflateStream.prototype.decodeHuffman = function() {
  var a = this.output, b = this.op, c, d, e, f = this.litlenTable, g = this.distTable, h = a.length;
  for(this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_START;;) {
    this.save_();
    c = this.readCodeByTable(f);
    if(0 > c) {
      return this.op = b, this.restore_(), -1
    }
    if(256 === c) {
      break
    }
    if(256 > c) {
      b === h && (a = this.expandBuffer(), h = a.length), a[b++] = c
    }else {
      d = c - 257;
      e = Zlib.RawInflateStream.LengthCodeTable[d];
      if(0 < Zlib.RawInflateStream.LengthExtraTable[d]) {
        c = this.readBits(Zlib.RawInflateStream.LengthExtraTable[d]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        e += c
      }
      c = this.readCodeByTable(g);
      if(0 > c) {
        return this.op = b, this.restore_(), -1
      }
      d = Zlib.RawInflateStream.DistCodeTable[c];
      if(0 < Zlib.RawInflateStream.DistExtraTable[c]) {
        c = this.readBits(Zlib.RawInflateStream.DistExtraTable[c]);
        if(0 > c) {
          return this.op = b, this.restore_(), -1
        }
        d += c
      }
      b + e >= h && (a = this.expandBuffer(), h = a.length);
      for(;e--;) {
        a[b] = a[b++ - d]
      }
      if(this.ip === this.input.length) {
        return this.op = b, -1
      }
    }
  }
  for(;8 <= this.bitsbuflen;) {
    this.bitsbuflen -= 8, this.ip--
  }
  this.op = b;
  this.status = Zlib.RawInflateStream.Status.DECODE_BLOCK_END
};
Zlib.RawInflateStream.prototype.expandBuffer = function(a) {
  var b = this.input.length / this.ip + 1 | 0, c = this.input, d = this.output;
  a && ("number" === typeof a.fixRatio && (b = a.fixRatio), "number" === typeof a.addRatio && (b += a.addRatio));
  2 > b ? (a = (c.length - this.ip) / this.litlenTable[2], a = 258 * (a / 2) | 0, a = a < d.length ? d.length + a : d.length << 1) : a = d.length * b;
  USE_TYPEDARRAY ? (a = new Uint8Array(a), a.set(d)) : a = d;
  return this.output = a
};
Zlib.RawInflateStream.prototype.concatBuffer = function() {
  var a, b = this.op;
  this.resize ? USE_TYPEDARRAY ? (a = new Uint8Array(b), a.set(this.output.subarray(this.sp, b))) : a = this.output.slice(this.sp, b) : a = USE_TYPEDARRAY ? this.output.subarray(this.sp, b) : this.output.slice(this.sp, b);
  this.buffer = a;
  this.sp = b;
  return this.buffer
};
Zlib.RawInflateStream.prototype.getBytes = function() {
  return USE_TYPEDARRAY ? this.output.subarray(0, this.op) : this.output.slice(0, this.op)
};
Zlib.InflateStream = function(a) {
  this.input = void 0 === a ? new (USE_TYPEDARRAY ? Uint8Array : Array) : a;
  this.ip = 0;
  this.rawinflate = new Zlib.RawInflateStream(this.input, this.ip);
  this.output = this.rawinflate.output
};
Zlib.InflateStream.prototype.decompress = function(a) {
  if(void 0 !== a) {
    if(USE_TYPEDARRAY) {
      var b = new Uint8Array(this.input.length + a.length);
      b.set(this.input, 0);
      b.set(a, this.input.length);
      this.input = b
    }else {
      this.input = this.input.concat(a)
    }
  }
  if(void 0 === this.method && 0 > this.readHeader()) {
    return new (USE_TYPEDARRAY ? Uint8Array : Array)
  }
  a = this.rawinflate.decompress(this.input, this.ip);
  this.ip = this.rawinflate.ip;
  return a
};
Zlib.InflateStream.prototype.getBytes = function() {
  return this.rawinflate.getBytes()
};
Zlib.InflateStream.prototype.readHeader = function() {
  var a = this.ip, b = this.input, c = b[a++], b = b[a++];
  if(void 0 === c || void 0 === b) {
    return-1
  }
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + b) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + b) % 31);
  }
  if(b & 32) {
    throw Error("fdict flag is not supported");
  }
  this.ip = a
};
Zlib.Util = {};
Zlib.Util.stringToByteArray = function(a) {
  var a = a.split(""), b, c;
  b = 0;
  for(c = a.length;b < c;b++) {
    a[b] = (a[b].charCodeAt(0) & 255) >>> 0
  }
  return a
};
Zlib.Adler32 = function(a) {
  "string" === typeof a && (a = Zlib.Util.stringToByteArray(a));
  return Zlib.Adler32.update(1, a)
};
Zlib.Adler32.update = function(a, b) {
  for(var c = a & 65535, d = a >>> 16 & 65535, e = b.length, f, g = 0;0 < e;) {
    f = e > Zlib.Adler32.OptimizationParameter ? Zlib.Adler32.OptimizationParameter : e;
    e -= f;
    do {
      c += b[g++], d += c
    }while(--f);
    c %= 65521;
    d %= 65521
  }
  return(d << 16 | c) >>> 0
};
Zlib.Adler32.OptimizationParameter = 1024;
Zlib.Deflate = function(a, b) {
  this.input = a;
  this.output = new (USE_TYPEDARRAY ? Uint8Array : Array)(Zlib.Deflate.DefaultBufferSize);
  this.compressionType = Zlib.Deflate.CompressionType.DYNAMIC;
  var c = {}, d;
  if((b || !(b = {})) && "number" === typeof b.compressionType) {
    this.compressionType = b.compressionType
  }
  for(d in b) {
    c[d] = b[d]
  }
  c.outputBuffer = this.output;
  this.rawDeflate = new Zlib.RawDeflate(this.input, c)
};
Zlib.Deflate.DefaultBufferSize = 32768;
Zlib.Deflate.CompressionType = Zlib.RawDeflate.CompressionType;
Zlib.Deflate.compress = function(a, b) {
  return(new Zlib.Deflate(a, b)).compress()
};
Zlib.Deflate.prototype.compress = function() {
  var a, b, c, d = 0;
  c = this.output;
  a = Zlib.CompressionMethod.DEFLATE;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      b = Math.LOG2E * Math.log(Zlib.RawDeflate.WindowSize) - 8;
      break;
    default:
      throw Error("invalid compression method");
  }
  b = b << 4 | a;
  c[d++] = b;
  switch(a) {
    case Zlib.CompressionMethod.DEFLATE:
      switch(this.compressionType) {
        case Zlib.Deflate.CompressionType.NONE:
          a = 0;
          break;
        case Zlib.Deflate.CompressionType.FIXED:
          a = 1;
          break;
        case Zlib.Deflate.CompressionType.DYNAMIC:
          a = 2;
          break;
        default:
          throw Error("unsupported compression type");
      }
      break;
    default:
      throw Error("invalid compression method");
  }
  a = a << 6 | 0;
  c[d++] = a | 31 - (256 * b + a) % 31;
  b = Zlib.Adler32(this.input);
  this.rawDeflate.op = d;
  c = this.rawDeflate.compress();
  d = c.length;
  USE_TYPEDARRAY && (c = new Uint8Array(c.buffer), c.length <= d + 4 && (this.output = new Uint8Array(c.length + 4), this.output.set(c), c = this.output), c = c.subarray(0, d + 4));
  c[d++] = b >> 24 & 255;
  c[d++] = b >> 16 & 255;
  c[d++] = b >> 8 & 255;
  c[d++] = b & 255;
  return c
};
goog.exportSymbol("Zlib.Deflate", Zlib.Deflate);
goog.exportSymbol("Zlib.Deflate.compress", Zlib.Deflate.compress);
goog.exportSymbol("Zlib.Deflate.prototype.compress", Zlib.Deflate.prototype.compress);
Zlib.exportObject("Zlib.Deflate.CompressionType", {NONE:Zlib.Deflate.CompressionType.NONE, FIXED:Zlib.Deflate.CompressionType.FIXED, DYNAMIC:Zlib.Deflate.CompressionType.DYNAMIC});
Zlib.Inflate = function(a, b) {
  var c, d;
  this.input = a;
  this.ip = 0;
  if(b || !(b = {})) {
    b.index && (this.ip = b.index), b.verify && (this.verify = b.verify)
  }
  c = a[this.ip++];
  d = a[this.ip++];
  switch(c & 15) {
    case Zlib.CompressionMethod.DEFLATE:
      this.method = Zlib.CompressionMethod.DEFLATE;
      break;
    default:
      throw Error("unsupported compression method");
  }
  if(0 !== ((c << 8) + d) % 31) {
    throw Error("invalid fcheck flag:" + ((c << 8) + d) % 31);
  }
  if(d & 32) {
    throw Error("fdict flag is not supported");
  }
  this.rawinflate = new Zlib.RawInflate(a, {index:this.ip, bufferSize:b.bufferSize, bufferType:b.bufferType, resize:b.resize})
};
Zlib.Inflate.BufferType = Zlib.RawInflate.BufferType;
Zlib.Inflate.prototype.decompress = function() {
  var a = this.input, b;
  b = this.rawinflate.decompress();
  this.ip = this.rawinflate.ip;
  if(this.verify && (a = (a[this.ip++] << 24 | a[this.ip++] << 16 | a[this.ip++] << 8 | a[this.ip++]) >>> 0, a !== Zlib.Adler32(b))) {
    throw Error("invalid adler-32 checksum");
  }
  return b
};
Zlib.Zip = function(a) {
  a = a || {};
  this.files = [];
  this.comment = a.comment
};
Zlib.Zip.prototype.addFile = function(a, b) {
  var b = b || {}, c, d = a.length, e = 0;
  USE_TYPEDARRAY && a instanceof Array && (a = new Uint8Array(a));
  "number" !== typeof b.compressionMethod && (b.compressionMethod = Zlib.Zip.CompressionMethod.DEFLATE);
  if(b.compress) {
    switch(b.compressionMethod) {
      case Zlib.Zip.CompressionMethod.STORE:
        break;
      case Zlib.Zip.CompressionMethod.DEFLATE:
        e = Zlib.CRC32.calc(a);
        a = this.deflateWithOption(a, b);
        c = !0;
        break;
      default:
        throw Error("unknown compression method:" + b.compressionMethod);
    }
  }
  this.files.push({buffer:a, option:b, compressed:c, size:d, crc32:e})
};
Zlib.Zip.CompressionMethod = {STORE:0, DEFLATE:8};
Zlib.Zip.OperatingSystem = {MSDOS:0, UNIX:3, MACINTOSH:7};
Zlib.Zip.prototype.compress = function() {
  var a = this.files, b, c, d, e, f, g = 0, h = 0, i, j, l, m, k, n;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    if(!b.compressed) {
      switch(b.crc32 = Zlib.CRC32.calc(b.buffer), b.option.compressionMethod) {
        case Zlib.Zip.CompressionMethod.STORE:
          break;
        case Zlib.Zip.CompressionMethod.DEFLATE:
          b.buffer = this.deflateWithOption(b.buffer, b.option);
          b.compressed = !0;
          break;
        default:
          throw Error("unknown compression method:" + b.option.compressionMethod);
      }
    }
    g += 30 + l + b.buffer.length;
    h += 46 + l + m
  }
  c = new (USE_TYPEDARRAY ? Uint8Array : Array)(g + h + (46 + (this.comment ? this.comment.length : 0)));
  d = 0;
  e = g;
  f = e + h;
  k = 0;
  for(n = a.length;k < n;++k) {
    b = a[k];
    l = b.option.filename ? b.option.filename.length : 0;
    m = b.option.comment ? b.option.comment.length : 0;
    i = d;
    c[d++] = c[e++] = 80;
    c[d++] = c[e++] = 75;
    c[d++] = 3;
    c[d++] = 4;
    c[e++] = 1;
    c[e++] = 2;
    c[e++] = 20;
    c[e++] = b.option.os || Zlib.Zip.OperatingSystem.MSDOS;
    c[d++] = c[e++] = 20;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    j = b.option.compressionMethod;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    j = b.option.date || new Date;
    c[d++] = c[e++] = (j.getMinutes() & 7) << 5 | j.getSeconds() / 2 | 0;
    c[d++] = c[e++] = j.getHours() << 3 | j.getMinutes() >> 3;
    c[d++] = c[e++] = (j.getMonth() + 1 & 7) << 5 | j.getDate();
    c[d++] = c[e++] = (j.getFullYear() - 1980 & 127) << 1 | j.getMonth() + 1 >> 3;
    j = b.crc32;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.buffer.length;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    j = b.size;
    c[d++] = c[e++] = j & 255;
    c[d++] = c[e++] = j >> 8 & 255;
    c[d++] = c[e++] = j >> 16 & 255;
    c[d++] = c[e++] = j >> 24 & 255;
    c[d++] = c[e++] = l & 255;
    c[d++] = c[e++] = l >> 8 & 255;
    c[d++] = c[e++] = 0;
    c[d++] = c[e++] = 0;
    c[e++] = m & 255;
    c[e++] = m >> 8 & 255;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = 0;
    c[e++] = i & 255;
    c[e++] = i >> 8 & 255;
    c[e++] = i >> 16 & 255;
    c[e++] = i >> 24 & 255;
    if(j = b.option.filename) {
      if(USE_TYPEDARRAY) {
        c.set(j, d), c.set(j, e), d += l, e += l
      }else {
        for(i = 0;i < l;++i) {
          c[d++] = c[e++] = j[i]
        }
      }
    }
    if(l = b.option.extraField) {
      if(USE_TYPEDARRAY) {
        c.set(l, d), c.set(l, e), d += 0, e += 0
      }else {
        for(i = 0;i < m;++i) {
          c[d++] = c[e++] = l[i]
        }
      }
    }
    if(l = b.option.comment) {
      if(USE_TYPEDARRAY) {
        c.set(l, e), e += m
      }else {
        for(i = 0;i < m;++i) {
          c[e++] = l[i]
        }
      }
    }
    if(USE_TYPEDARRAY) {
      c.set(b.buffer, d), d += b.buffer.length
    }else {
      i = 0;
      for(m = b.buffer.length;i < m;++i) {
        c[d++] = b.buffer[i]
      }
    }
  }
  c[f++] = 80;
  c[f++] = 75;
  c[f++] = 5;
  c[f++] = 6;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = 0;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = n & 255;
  c[f++] = n >> 8 & 255;
  c[f++] = h & 255;
  c[f++] = h >> 8 & 255;
  c[f++] = h >> 16 & 255;
  c[f++] = h >> 24 & 255;
  c[f++] = g & 255;
  c[f++] = g >> 8 & 255;
  c[f++] = g >> 16 & 255;
  c[f++] = g >> 24 & 255;
  m = this.comment ? this.comment.length : 0;
  c[f++] = m & 255;
  c[f++] = m >> 8 & 255;
  if(this.comment) {
    if(USE_TYPEDARRAY) {
      c.set(this.comment, f)
    }else {
      for(i = 0;i < m;++i) {
        c[f++] = this.comment[i]
      }
    }
  }
  return c
};
Zlib.Zip.prototype.deflateWithOption = function(a, b) {
  return(new Zlib.RawDeflate(a, b.deflateOption)).compress()
};
Zlib.Unzip = function(a, b) {
  b = b || {};
  this.input = USE_TYPEDARRAY && a instanceof Array ? new Uint8Array(a) : a;
  this.ip = 0;
  this.verify = b.verify || !1
};
Zlib.Unzip.CompressionMethod = Zlib.Zip.CompressionMethod;
Zlib.Unzip.FileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.FileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 1 !== a[b++] || 2 !== a[b++]) {
    throw Error("invalid file header signature");
  }
  this.version = a[b++];
  this.os = a[b++];
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.fileCommentLength = a[b++] | a[b++] << 8;
  this.diskNumberStart = a[b++] | a[b++] << 8;
  this.internalFileAttributes = a[b++] | a[b++] << 8;
  this.externalFileAttributes = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.relativeOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.fileCommentLength) : a.slice(b, b + this.fileCommentLength);
  this.length = b - this.offset
};
Zlib.Unzip.LocalFileHeader = function(a, b) {
  this.input = a;
  this.offset = b
};
Zlib.Unzip.LocalFileHeader.prototype.parse = function() {
  var a = this.input, b = this.offset;
  if(80 !== a[b++] || 75 !== a[b++] || 3 !== a[b++] || 4 !== a[b++]) {
    throw Error("invalid local file header signature");
  }
  this.needVersion = a[b++] | a[b++] << 8;
  this.flags = a[b++] | a[b++] << 8;
  this.compression = a[b++] | a[b++] << 8;
  this.time = a[b++] | a[b++] << 8;
  this.date = a[b++] | a[b++] << 8;
  this.crc32 = (a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24) >>> 0;
  this.compressedSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.plainSize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.fileNameLength = a[b++] | a[b++] << 8;
  this.extraFieldLength = a[b++] | a[b++] << 8;
  this.filename = String.fromCharCode.apply(null, USE_TYPEDARRAY ? a.subarray(b, b += this.fileNameLength) : a.slice(b, b += this.fileNameLength));
  this.extraField = USE_TYPEDARRAY ? a.subarray(b, b += this.extraFieldLength) : a.slice(b, b += this.extraFieldLength);
  this.length = b - this.offset
};
Zlib.Unzip.prototype.searchEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  for(b = a.length - 12;0 < b;--b) {
    if(80 === a[b] && 75 === a[b + 1] && 5 === a[b + 2] && 6 === a[b + 3]) {
      this.eocdrOffset = b;
      return
    }
  }
  throw Error("End of Central Directory Record not found");
};
Zlib.Unzip.prototype.parseEndOfCentralDirectoryRecord = function() {
  var a = this.input, b;
  this.eocdrOffset || this.searchEndOfCentralDirectoryRecord();
  b = this.eocdrOffset;
  if(80 !== a[b++] || 75 !== a[b++] || 5 !== a[b++] || 6 !== a[b++]) {
    throw Error("invalid signature");
  }
  this.numberOfThisDisk = a[b++] | a[b++] << 8;
  this.startDisk = a[b++] | a[b++] << 8;
  this.totalEntriesThisDisk = a[b++] | a[b++] << 8;
  this.totalEntries = a[b++] | a[b++] << 8;
  this.centralDirectorySize = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.centralDirectoryOffset = a[b++] | a[b++] << 8 | a[b++] << 16 | a[b++] << 24;
  this.commentLength = a[b++] | a[b++] << 8;
  this.comment = USE_TYPEDARRAY ? a.subarray(b, b + this.commentLength) : a.slice(b, b + this.commentLength)
};
Zlib.Unzip.prototype.parseFileHeader = function() {
  var a = [], b = {}, c, d, e, f;
  if(!this.fileHeaderList) {
    void 0 === this.centralDirectoryOffset && this.parseEndOfCentralDirectoryRecord();
    c = this.centralDirectoryOffset;
    e = 0;
    for(f = this.totalEntries;e < f;++e) {
      d = new Zlib.Unzip.FileHeader(this.input, c), d.parse(), c += d.length, a[e] = d, b[d.filename] = e
    }
    if(this.centralDirectorySize < c - this.centralDirectoryOffset) {
      throw Error("invalid file header size");
    }
    this.fileHeaderList = a;
    this.filenameToIndex = b
  }
};
Zlib.Unzip.prototype.getFileData = function(a) {
  var b = this.fileHeaderList, c;
  b || this.parseFileHeader();
  if(void 0 === b[a]) {
    throw Error("wrong index");
  }
  b = b[a].relativeOffset;
  a = new Zlib.Unzip.LocalFileHeader(this.input, b);
  a.parse();
  b += a.length;
  c = a.compressedSize;
  switch(a.compression) {
    case Zlib.Unzip.CompressionMethod.STORE:
      b = USE_TYPEDARRAY ? this.input.subarray(b, b + c) : this.input.slice(b, b + c);
      break;
    case Zlib.Unzip.CompressionMethod.DEFLATE:
      b = (new Zlib.RawInflate(this.input, {index:b, bufferSize:a.plainSize})).decompress();
      break;
    default:
      throw Error("unknown compression type");
  }
  if(this.verify && (c = Zlib.CRC32.calc(b), a.crc32 !== c)) {
    throw Error("wrong crc: file=0x" + a.crc32.toString(16) + ", data=0x" + c.toString(16));
  }
  return b
};
Zlib.Unzip.prototype.getFilenames = function() {
  var a = [], b, c, d;
  this.fileHeaderList || this.parseFileHeader();
  d = this.fileHeaderList;
  b = 0;
  for(c = d.length;b < c;++b) {
    a[b] = d[b].filename
  }
  return a
};
Zlib.Unzip.prototype.decompress = function(a) {
  var b;
  this.filenameToIndex || this.parseFileHeader();
  b = this.filenameToIndex[a];
  if(void 0 === b) {
    throw Error(a + " not found");
  }
  return this.getFileData(b)
};
Zlib.CompressionMethod = {DEFLATE:8, RESERVED:15};
}).call(this);

define("thirdparty/deflate.min", function(){});

define('utils/misc_utils',['thirdparty/inflate.min', 'thirdparty/deflate.min'], function(){
    /* Main object */
    var utils = {
      
      // Print an error either to the console if in node, or to div#jsgit-errors
      // if in the client.
      handleError: function(message) {
        if (jsGitInNode) {
          console.log(message)
        }
        else {
          $('#jsgit-errors').append(message)
        }
      },
      
      // Turn an array of bytes into a String
      bytesToString: function(bytes) {
        var result = "";
        var i;
        for (i = 0; i < bytes.length; i++) {
          result = result.concat(String.fromCharCode(bytes[i]));
        }
        return result;
      },
      
      stringToBytes: function(string) {
        var bytes = []; 
        var i; 
        for(i = 0; i < string.length; i++) {
          bytes.push(string.charCodeAt(i) & 0xff);
        }
        return bytes;
      },
        
      toBinaryString: function(binary) {
        if (Array.isArray(binary)) {
          return Git.bytesToString(binary)
        }
        else {
          return binary
        }
      },
        
      // returns the next pkt-line
      nextPktLine: function(data) {
        var length = parseInt(data.substring(0, 4), 16);
        return data.substring(4, length);
      },
      
      // zlib files contain a two byte header. (RFC 1950)
      stripZlibHeader: function(zlib) {
        return zlib.subarray(2)
      },
      
      escapeHTML: function(s) {
        return s
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;');
      },
        convertShaToBytes: function(sha){
            var bytes = new Uint8Array(sha.length/2);
            for (var i = 0; i < sha.length; i+=2)
            {
                bytes[i/2] = parseInt('0x' + sha.substr(i, 2));
            }
            return bytes;   
        },
        convertBytesToSha : function(bytes){
            var shaChars = [];
            for (var i = 0; i < bytes.length; i++){
                var next = (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
                shaChars.push(next);
            }
            return shaChars.join('');
        },
        compareShas : function(sha1, sha2){
            for (var i = 1; i < 20; i++){
                if (sha1[i] != sha2[i]){
                    return sha1[i] - sha2[i];
                }
            }
            return 0;
        },
        inflate: function(data, expectedLength){
            var options;
            if (expectedLength){
              options = {bufferSize: expectedLength};
            } 
            var inflate = new Zlib.Inflate(data, options);
            inflate.verify = true;
            var out = inflate.decompress();
            out.compressedLength = inflate.ip;
            return out;
        },
        deflate: function(data){
            var deflate = new Zlib.Deflate(data);
            var out = deflate.compress();
            return out;
        },
        trimBuffer: function(data){
            var buffer = data.buffer;
            if (data.byteOffset != 0 || data.byteLength != data.buffer.byteLength){
                buffer = data.buffer.slice(data.byteOffset, data.byteLength + data.byteOffset);
            }
            return buffer;
        }
    }

    return utils;

});

define('utils/file_utils',['utils/misc_utils'], function(utils){
	Array.prototype.asyncEach = function(func, callback){
		if (this.length == 0){
			callback();
			return;
		}
		var list = this,
		    counter = {x:0, end:list.length};
		
		var finish = function(){
			counter.x += 1;
			if (counter.x == counter.end){
				callback();
			}
		}
		
		for (var i = 0; i < list.length; i++){
			func.call(list, list[i], finish, i);
		}
	}

	var FileUtils = (function(){
		
		var toArray = function(list) {
			return Array.prototype.slice.call(list || [], 0);
		}
		
		var makeFile = function(root, filename, contents, callback, error){
			root.getFile(filename, {create:true}, function(fileEntry){
				fileEntry.createWriter(function(writer){
					writer.onwriteend = function(){
						// strange piece of the FileWriter api. Writing to an 
						// existing file just overwrites content in place. Still need to truncate
						// which triggers onwritend event...again. o_O
						if (writer.position < writer.length){
							writer.truncate(writer.position);	
						}
						else if (callback)
							callback(fileEntry);

					}
					writer.onerror = function(e){
						throw(e);
					}
					if (contents instanceof ArrayBuffer){
						contents = new Uint8Array(contents);
					}
					writer.write(new Blob([contents]));
				}, error);
			}, error);
		}
		
		var makeDir = function(root, dirname, callback, error){
			root.getDirectory(dirname, {create:true},callback, error);
		}
		
		return {
			mkdirs : function(root, dirname, callback, error){
				var pathParts;
				if (dirname instanceof Array){
					pathParts = dirname;
				}
				else{
					pathParts = dirname.split('/');
				}
				
				var makeDirCallback = function(dir){
					if (pathParts.length){
						makeDir(dir, pathParts.shift(), makeDirCallback, error);
					}
					else{
						if (callback)
							callback(dir);
					}
				}
				makeDirCallback(root);
			},
			rmDir : function (root, dirname, callback){
				root.getDirectory(dirname, {create:true}, function(dirEntry){
					dirEntry.removeRecursively(callback, utils.errorHandler);
				});
			},
			rmFile : function(root, filename, callback){
				root.getFile(filename, {create:true}, function(fileEntry){
					fileEntry.remove(callback, utils.errorHandler);
				});
			},
			mkfile : function(root, filename, contents, callback, error){
				if (filename.charAt(0) == '/'){
					filename = filename.substring(1);
				}
				var pathParts = filename.split('/');
				if (pathParts.length > 1){
					FileUtils.mkdirs(root, pathParts.slice(0, pathParts.length - 1), function(dir){
						makeFile(dir, pathParts[pathParts.length - 1], contents, callback, error);
					}, error);
				}
				else{
					makeFile(root, filename, contents, callback, error);
				}
			},
			ls: function(dir, callback, error){
				var reader = dir.createReader();
				var entries = [];
				
				var readEntries = function() {
					reader.readEntries (function(results) {
						if (!results.length) {
							callback(entries);
						} else {
							entries = entries.concat(toArray(results));
							readEntries();
						}
					}, error);
				}
				readEntries();
				
			},
			readBlob: function(blob, dataType, callback){
				var reader = new FileReader();
				reader.onloadend = function(e){
					callback(reader.result);
				}
				reader["readAs" + dataType](blob);
			},
			readFileEntry : function(fileEntry, dataType, callback){
				fileEntry.file(function(file){
					FileUtils.readBlob(file, dataType, callback);
				});
			},
			readFile : function(root, file, dataType, callback, error) {
				
				root.getFile(file, {create:false}, function(fileEntry){
					FileUtils.readFileEntry(fileEntry, dataType, callback, error);
				}, error);
			}
		
		};
	}
	)();

	return FileUtils; 
});
define('commands/object2file',['utils/file_utils'], function(fileutils){

    var expandBlob = function(dir, store, name, blobSha, callback){
        var makeFileFactory = function(name){
            return function(blob){
                fileutils.mkfile(dir, name, blob.data, callback, function(e){console.log(e)});
            }
        }
        store._retrieveObject(blobSha, "Blob", makeFileFactory(name));
    }

    var expandTree = function(dir, store, treeSha, callback){
        
        store._retrieveObject(treeSha, "Tree", function(tree){
            var entries = tree.entries;
            entries.asyncEach(function(entry, done){
                if (entry.isBlob){
                    var name = entry.name;
                    expandBlob(dir, store, name, entry.sha, done);
                }
                else{
                    var sha = entry.sha;
                    fileutils.mkdirs(dir, entry.name, function(newDir){
                        expandTree(newDir, store, sha, done);
                    });
                }
            },callback);
        });
    }

    return {
        expandTree : expandTree,
        expandBlob : expandBlob
    }

});
define('objectstore/delta',[],function() {
    var applyDelta = (function() {
        var matchLength = function(stream) {
            var data = stream.data
            var offset = stream.offset
            var result = 0
            var currentShift = 0
            var _byte = 128
            var maskedByte, shiftedByte

            while ((_byte & 128) != 0) {
                _byte = data[offset]
                offset += 1
                maskedByte = _byte & 0x7f
                shiftedByte = maskedByte << currentShift
                result += shiftedByte
                currentShift += 7
            }
            stream.offset = offset
            return result
        }

        return function(baseData, delta) {
            //var baseData = Git.stringToBytes(baseDataString)
            var stream = {
                data: delta,
                offset: 0,
                length: delta.length
            }
            var bb = [];
            var baseLength = matchLength(stream)
            if (baseLength != baseData.length) {
                throw (Error("Delta Error: base length not equal to length of given base data"))
            }

            var resultLength = matchLength(stream)
            var resultData = new Uint8Array(resultLength);
            var resultOffset = 0;

            var copyOffset
            var copyLength
            var opcode
            var copyFromResult
            while (stream.offset < stream.length) {
                opcode = stream.data[stream.offset]
                stream.offset += 1
                copyOffset = 0
                copyLength = 0
                if (opcode == 0) {
                    throw (Error("Don't know what to do with a delta opcode 0"))
                } else if ((opcode & 0x80) != 0) {
                    var value
                    var shift = 0
                    _(4).times(function() {
                        if ((opcode & 0x01) != 0) {
                            value = stream.data[stream.offset]
                            stream.offset += 1
                            copyOffset += (value << shift)
                        }
                        opcode >>= 1
                        shift += 8
                    })
                    shift = 0
                    _(2).times(function() {
                        if ((opcode & 0x01) != 0) {
                            value = stream.data[stream.offset]
                            stream.offset += 1
                            copyLength += (value << shift)
                        }
                        opcode >>= 1
                        shift += 8
                    })
                    if (copyLength == 0) {
                        copyLength = (1 << 16)
                    }

                    // TODO: check if this is a version 2 packfile and apply copyFromResult if so
                    copyFromResult = (opcode & 0x01)
                    var subarray = baseData.subarray(copyOffset, copyOffset + copyLength);
                    resultData.set(subarray, resultOffset);
                    resultOffset += subarray.length;

                } else if ((opcode & 0x80) == 0) {
                    var subarray = stream.data.subarray(stream.offset, stream.offset + opcode);
                    resultData.set(subarray, resultOffset);
                    resultOffset += subarray.length;
                    stream.offset += opcode
                }
            }
            return resultData.buffer;
            
        }
    }());

    return applyDelta;
});
if(typeof Crypto=="undefined"||!Crypto.util)(function(){var i=window.Crypto={},l=i.util={rotl:function(a,c){return a<<c|a>>>32-c},rotr:function(a,c){return a<<32-c|a>>>c},endian:function(a){if(a.constructor==Number)return l.rotl(a,8)&16711935|l.rotl(a,24)&4278255360;for(var c=0;c<a.length;c++)a[c]=l.endian(a[c]);return a},randomBytes:function(a){for(var c=[];a>0;a--)c.push(Math.floor(Math.random()*256));return c},bytesToWords:function(a){for(var c=[],b=0,d=0;b<a.length;b++,d+=8)c[d>>>5]|=a[b]<<24-
d%32;return c},wordsToBytes:function(a){for(var c=[],b=0;b<a.length*32;b+=8)c.push(a[b>>>5]>>>24-b%32&255);return c},bytesToHex:function(a){for(var c=[],b=0;b<a.length;b++){c.push((a[b]>>>4).toString(16));c.push((a[b]&15).toString(16))}return c.join("")},hexToBytes:function(a){for(var c=[],b=0;b<a.length;b+=2)c.push(parseInt(a.substr(b,2),16));return c},bytesToBase64:function(a){if(typeof btoa=="function")return btoa(m.bytesToString(a));for(var c=[],b=0;b<a.length;b+=3)for(var d=a[b]<<16|a[b+1]<<
8|a[b+2],e=0;e<4;e++)b*8+e*6<=a.length*8?c.push("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".charAt(d>>>6*(3-e)&63)):c.push("=");return c.join("")},base64ToBytes:function(a){if(typeof atob=="function")return m.stringToBytes(atob(a));a=a.replace(/[^A-Z0-9+\/]/ig,"");for(var c=[],b=0,d=0;b<a.length;d=++b%4)d!=0&&c.push(("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".indexOf(a.charAt(b-1))&Math.pow(2,-2*d+8)-1)<<d*2|"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".indexOf(a.charAt(b))>>>
6-d*2);return c}};i.mode={};i=i.charenc={};i.UTF8={stringToBytes:function(a){return m.stringToBytes(unescape(encodeURIComponent(a)))},bytesToString:function(a){return decodeURIComponent(escape(m.bytesToString(a)))}};var m=i.Binary={stringToBytes:function(a){for(var c=[],b=0;b<a.length;b++)c.push(a.charCodeAt(b)&255);return c},bytesToString:function(a){for(var c=[],b=0;b<a.length;b++)c.push(String.fromCharCode(a[b]));return c.join("")}}})();
(function(){var i=Crypto,l=i.util,m=i.charenc,a=m.UTF8,c=m.Binary,b=i.SHA1=function(d,e){var g=l.wordsToBytes(b._sha1(d));return e&&e.asBytes?g:e&&e.asString?c.bytesToString(g):l.bytesToHex(g)};b._sha1=function(d){if(d.constructor==String)d=a.stringToBytes(d);var e=l.bytesToWords(d),g=d.length*8;d=[];var n=1732584193,h=-271733879,j=-1732584194,k=271733878,o=-1009589776;e[g>>5]|=128<<24-g%32;e[(g+64>>>9<<4)+15]=g;for(g=0;g<e.length;g+=16){for(var q=n,r=h,s=j,t=k,u=o,f=0;f<80;f++){if(f<16)d[f]=e[g+
f];else{var p=d[f-3]^d[f-8]^d[f-14]^d[f-16];d[f]=p<<1|p>>>31}p=(n<<5|n>>>27)+o+(d[f]>>>0)+(f<20?(h&j|~h&k)+1518500249:f<40?(h^j^k)+1859775393:f<60?(h&j|h&k|j&k)-1894007588:(h^j^k)-899497514);o=k;k=j;j=h<<30|h>>>2;h=n;n=p}n+=q;h+=r;j+=s;k+=t;o+=u}return[n,h,j,k,o]};b._blocksize=16;b._digestsize=20})();

define("thirdparty/2.2.0-sha1", function(){});

define('formats/pack',['objectstore/delta', 'utils/misc_utils', 'utils/file_utils', 'thirdparty/2.2.0-sha1'], function(applyDelta, utils, fileutils) {

    String.prototype.rjust = function(width, padding) {
        padding = padding || " ";
        padding = padding.substr(0, 1);
        if (this.length < width)
            return padding.repeat(width - this.length) + this;
        else
            return this.toString();
    }
    String.prototype.repeat = function(num) {
        for (var i = 0, buf = ""; i < num; i++) buf += this;
        return buf;
    }

    var Pack = function(binary, store) {
        //var binaryString = Git.toBinaryString(binary)
        var data;
        if (binary.constructor == String)
            data = new Uint8Array(utils.stringToBytes(binary)); //new BinaryFile(binaryString)
        else
            data = new Uint8Array(binary); //new BinaryFile(binaryString)
        var offset = 0
        var objects = null

        //var lastObjectData = null;
        //var chainCache = {};
        this.getData = function() {
            return data;
        }

        //if (typeof require === "undefined") {
        var myDebug = function(obj) {
            console.log(obj)
        }
        //}
        //else {
        //  var myDebug = require('util').debug
        //}

        var peek = function(length) {
            return data.subarray(offset, offset + length)
        }

        var rest = function() {
            return data.subarray(offset)
        }

        var advance = function(length) {
            offset += length
        }

        var matchPrefix = function() {
            if (utils.bytesToString(peek(4)) === "PACK") {
                advance(4)
            } else {
                throw (Error("couldn't match PACK"))
            }
        }

        var matchVersion = function(expectedVersion) {
            var actualVersion = peek(4)[3]
            advance(4)
            if (actualVersion !== expectedVersion) {
                throw ("expected packfile version " + expectedVersion + ", but got " + actualVersion)
            }
        }

        var matchNumberOfObjects = function() {
            var num = 0
            _(peek(4)).each(function(b) {
                num = num << 8
                num += b
            })
            advance(4);
            return num;
        }

        var PackedTypes = {
            COMMIT: 1,
            TREE: 2,
            BLOB: 3,
            TAG: 4,
            OFS_DELTA: 6,
            REF_DELTA: 7
        }
        var typeArray = [null, "commit", "tree", "blob", "tag", null, "ofs_delta", "ref_delta"];
        var getTypeStr = function(type) {
            return typeArray[type];
        }

        var matchObjectHeader = function() {
            var objectStartOffset = offset;
            var headByte = data[offset++];
            var type = (0x70 & headByte) >>> 4;
            var needMore = (0x80 & headByte) > 0;

            var size = headByte & 0xf;
            var bitsToShift = 4;

            while (needMore) {
                headByte = data[offset++];
                needMore = (0x80 & headByte) > 0;
                size = size | ((headByte & 0x7f) << bitsToShift);
                bitsToShift += 7;
            }

            return {
                size: size,
                type: type,
                offset: objectStartOffset
            }
           
        }

        var objectHash = function(type, content) {
            var contentData = new Uint8Array(content);
            var data = utils.stringToBytes(getTypeStr(type) + " " + contentData.byteLength + "\0");
            var buf = new ArrayBuffer(data.length + contentData.byteLength);
            var fullContent = new Uint8Array(buf);
            fullContent.set(data);
            fullContent.set(contentData, data.length);
            // return new SHA1(data).hexdigest()
            return Crypto.SHA1(fullContent, {
                asBytes: true
            });
        }

        var findDeltaBaseOffset = function(header) {
            var offsetBytes = []
            var hintAndOffsetBits = peek(1)[0].toString(2).rjust(8, "0")
            var needMore = (hintAndOffsetBits[0] == "1")

            offsetBytes.push(hintAndOffsetBits.slice(1, 8))
            advance(1)

            while (needMore) {
                hintAndOffsetBits = peek(1)[0].toString(2).rjust(8, "0")
                needMore = (hintAndOffsetBits[0] == "1")
                offsetBytes.push(hintAndOffsetBits.slice(1, 8))
                advance(1)
            }

            var longOffsetString = _(offsetBytes).reduce(function(memo, byteString) {
                return memo + byteString
            }, "")

            var offsetDelta = parseInt(longOffsetString, 2)
            var n = 1
            _(offsetBytes.length - 1).times(function() {
                offsetDelta += Math.pow(2, 7 * n)
                n += 1
            })
            var desiredOffset = header.offset - offsetDelta
            return desiredOffset;
        }

        
        var expandDeltifiedObject = function(object, callback) {

            var doExpand = function(baseObject, deltaObject) {
                deltaObject.type = baseObject.type;
                deltaObject.data = applyDelta(new Uint8Array(baseObject.data), new Uint8Array(deltaObject.data));
                deltaObject.sha = objectHash(deltaObject.type, deltaObject.data);
                return deltaObject;
            }

            if (object.type == PackedTypes.OFS_DELTA) {
                var baseObject = matchObjectAtOffset(object.desiredOffset);
                switch (baseObject.type) {
                    case PackedTypes.OFS_DELTA:
                    case PackedTypes.REF_DELTA:
                        expandDeltifiedObject(baseObject, function(expandedObject) {
                            var newObject = doExpand(expandedObject, object);
                            callback(newObject);
                        });
                        break;
                    default:
                        var newObject = doExpand(baseObject, object);
                        callback(newObject);
                }

            } else {
                store._retrieveRawObject(object.baseSha, 'ArrayBuffer', function(baseObject) {
                    baseObject.sha = object.baseSha;
                    var newObject = doExpand(baseObject, object);
                    callback(newObject);
                });
            }
        }
        var uncompressObject = function(objOffset, uncompressedLength) {
            var deflated = data.subarray(objOffset);
            var out = utils.inflate(deflated, uncompressedLength);

            return {
                buf: utils.trimBuffer(out),
                compressedLength: out.compressedLength
            };
        }

        var matchObjectData = function(header) {

            var object = {
                offset: header.offset,
                //dataOffset: dataOffset,
                //crc: crc32.crc(data.subarray(header.offset, offset)),
                type: header.type,
                //sha: objectHash(header.type, buf),
                // data: objData.buf
            }
            switch (header.type) {
                case PackedTypes.OFS_DELTA:
                    object.desiredOffset = findDeltaBaseOffset(header);
                    break;
                case PackedTypes.REF_DELTA:
                    var shaBytes = peek(20)
                    advance(20)
                    object.baseSha = _(shaBytes).map(function(b) {
                        return b.toString(16).rjust(2, "0")
                    }).join("")
                    break;
                default:
                    break;

            }
            var objData = uncompressObject(offset, header.size);
            object.data = objData.buf;

            //var checksum = adler32(buf)
            advance(objData.compressedLength);
            //matchBytes(intToBytes(checksum, 4))

            return object;
        }

        var matchObjectAtOffset = function(startOffset) {
            offset = startOffset
            var header = matchObjectHeader()
            return matchObjectData(header);
        }

        // slightly different code path from the original parser used for building the index
        // I'm doing it seperately because I needed to solve a call stack overflow caused by
        // synchronouse execution of callbacks for the case of non deltified objects in the
        // pack.
        var matchAndExpandObjectAtOffset = function(startOffset, dataType, callback) {
            //var reverseMap = [null, "commit", "tree", "blob"]

            var object = matchObjectAtOffset(startOffset);

            var convertToDataType = function(object) {
                //object.type = reverseMap[object.type];
                if (dataType != 'ArrayBuffer') {
                    var reader = new FileReader();

                    reader.onloadend = function() {
                        var buf = reader.result;
                        object.data = buf;
                        callback(object);
                    }
                    reader['readAs' + dataType](new Blob([object.data]));
                }
                else{
                    callback(object);
                }
            }
            switch (object.type) {
                case PackedTypes.OFS_DELTA:
                case PackedTypes.REF_DELTA:
                    expandDeltifiedObject(object, function(expandedObject){
                        convertToDataType(expandedObject);
                    });
                    break;
                default:
                    convertToDataType(object);
                    break;
            }
        };
        this.matchAndExpandObjectAtOffset = matchAndExpandObjectAtOffset;

        var stripOffsetsFromObjects = function() {
            _(objects).each(function(object) {
                delete object.offset
            })
        }

        var objectAtOffset = function(offset) {
            return _(objects).detect(function(obj) {
                return obj.offset == offset
            })
        }

        this.matchObjectAtOffset = matchObjectAtOffset;

        this.parseAll = function(success, progress) {
            try {
                var numObjects;
                var i;
                var deferredObjects = [];
                objects = [];


                matchPrefix()
                matchVersion(2)
                numObjects = matchNumberOfObjects();

                if (progress){
                    var tracker = 0;
                    var lastPercent = 0;
                    var trackProgress = function(){
                        var pct = (++tracker/numObjects) * 100
                        if (pct - lastPercent >= 1){
                            progress({pct: pct, msg: "Unpacking " + tracker + '/' + numObjects + " objects"});
                        }
                    }
                }
                else{
                    var trackProgress = function(){};
                }
                trackProgress();
                for (i = 0; i < numObjects; i++) {
                    var object = matchObjectAtOffset(offset);

                    object.crc = crc32.crc(data.subarray(object.offset, offset));

                    // hold on to the data for delta style objects.
                    switch (object.type) {
                        case PackedTypes.OFS_DELTA:
                        case PackedTypes.REF_DELTA:
                            {
                                deferredObjects.push(object);
                                break;
                            }
                        default:
                            object.sha = objectHash(object.type, object.data);
                            delete object.data;
                            trackProgress();
                            break;
                    }
                    objects.push(object);
                }

                deferredObjects.asyncEach(function(obj, done) {
                    expandDeltifiedObject(obj, function(obj){
                        delete obj.data;
                        trackProgress();
                        done();
                    });
                },
                    success);

            } catch (e) {
                //console.log("Error caught in pack file parsing data") // + Git.stringToBytes(data.getRawData()))
                throw (e)
            }
            return this
        }

        this.getObjects = function() {
            return objects
        }

        // this.getObjectAtOffset = getObjectAtOffset
    }

    Pack.buildPack = function(commits, repo, callback) {
        var visited = {};
        var counter = {
            x: 0,
            numObjects: 0
        };
        var packed = []; //new BlobBuilder();

        var map = {
            "commit": 1,
            "tree": 2,
            "blob": 3
        };

        var packTypeSizeBits = function(type, size) {
            var typeBits = type;//map[type];
            var shifter = size;
            var bytes = [];
            var idx = 0;

            bytes[idx] = typeBits << 4 | (shifter & 0xf);
            shifter = shifter >>> 4;

            while (shifter != 0) {
                bytes[idx] = bytes[idx] | 0x80;
                bytes[++idx] = shifter & 0x7f;
                shifter = shifter >>> 7;
            }
            return new Uint8Array(bytes);
        }

        var packIt = function(object) {
            var compressed;
            var size;
            var type = object.type;

            if (object.compressedData) {
                size = object.size;
                // clone the data since it may be sub view of a larger buffer;
                compressed = new Uint8Array(compressedData).buffer;
            } else {
                var buf = object.data;
                var data;
                if (buf instanceof ArrayBuffer) {
                    data = new Uint8Array(buf);
                } else if (buf instanceof Uint8Array) {
                    data = buf;
                } else {
                    // assume it's a string
                    data = utils.stringToBytes(buf);
                }

                compressed = utils.deflate(data);
                size = data.length;
            }
            packed.push(packTypeSizeBits(type, size));
            packed.push(compressed);
            counter.numObjects++;
        }

        var finishPack = function() {
            var packedObjects = []; //new BlobBuilder();

            var buf = new ArrayBuffer(12);
            var dv = new DataView(buf);

            // 'PACK'
            dv.setUint32(0, 0x5041434b, false);
            // version
            dv.setUint32(4, 2, false);
            //number of packed objects
            dv.setUint32(8, counter.numObjects, false);

            //finalPack.append(buf);
            //finalPack.append(packedObjects);
            packedObjects.push(dv);
            //packed.reverse();
            for (var i = 0; i < packed.length; i++) {
                packedObjects.push(packed[i]);
            }
            //packed.getBlob();
            fileutils.readBlob(new Blob(packedObjects), 'ArrayBuffer', function(dataBuf) {
                packed = null;
                var dataBufArray = new Uint8Array(dataBuf);
                var sha = Crypto.SHA1(dataBufArray, {
                    asBytes: true
                });

                var finalPack = []; //new BlobBuilder();
                finalPack.push(dataBufArray);
                finalPack.push(new Uint8Array(sha));

                fileutils.readBlob(new Blob(finalPack), 'ArrayBuffer', callback);
            });

        }

        var walkTree = function(treeSha, callback) {
            if (visited[treeSha]) {
                callback();
                return;
            } else {
                visited[treeSha] = true;
            }

            var packTree = function(){
                repo._retrieveObject(treeSha, 'Tree', function(tree, rawObj) {
                    var childCount = {
                        x: 0
                    };
                    var handleCallback = function() {
                        childCount.x++;
                        if (childCount.x == tree.entries.length) {
                            packIt(rawObj);
                            callback();
                        }
                    }

                    for (var i = 0; i < tree.entries.length; i++) {
                        var nextSha = utils.convertBytesToSha(tree.entries[i].sha);
                        if (tree.entries[i].isBlob) {
                            if (visited[nextSha]) {
                                handleCallback();
                            } else {
                                visited[nextSha] = true;
                                repo._findPackedObject(tree.entries[i].sha, handleCallback, function(){
                                    repo._retrieveRawObject(nextSha, 'Raw', function(object) {
                                        packIt(object);
                                        handleCallback();
                                    });
                                });
                            }
                        } else {
                            walkTree(nextSha, function() {
                                handleCallback();
                            });
                        }
                    }
                });
            }
            var shaBytes = utils.convertShaToBytes(treeSha);
            // assumes that if it's packed, the remote knows about the object since all stored packs came from the remote.
            repo._findPackedObject(shaBytes, callback, packTree);
        }

        if (commits.length == 0){
            finishPack();
        }
        else{
            commits.forEach(function(commitObj) {
                //repo._retrieveObject(commitShas[i], 'Commit', function(commit, rawObj){
                var commit = commitObj.commit;
                packIt(commitObj.raw);
                walkTree(commit.tree, function() {
                    if (++counter.x == commits.length) {
                        finishPack();
                    }
                });
                //});
            });
        }

    }
    return Pack;
});
define('formats/upload_pack_parser',['formats/pack', 'utils/misc_utils'], function(Pack, utils) {
    var parse = function(arraybuffer, repo, success, progress) {
        var data = new Uint8Array(arraybuffer); //new BinaryFile(binaryString);
        var offset = 0;
        var remoteLines = null;
        var objects = null;

        var peek = function(length) {
            return data.subarray(offset, offset + length);
        };

        var advance = function(length) {
            offset += length;
        };

        var getPktLineStr = function(pktLine){
            return utils.bytesToString(data.subarray(pktLine.start, pktLine.end));
        }

        // A pkt-line is defined in http://git-scm.com/gitserver.txt
        var nextPktLine = function(isShallow) {
            var pktLine = null;
            var length;
            length = parseInt(utils.bytesToString(peek(4)), 16);
            advance(4);
            if (length == 0) {
                if (isShallow) {
                    return nextPktLine()
                }
            } else {
                pktLine = {start: offset, end: offset + length - 4};//peek(length - 4);
                advance(length - 4);
            }
            return pktLine;
        };

        //console.log("Parsing upload pack of  " + arraybuffer.byteLength + " bytes")
        var startTime = new Date()
        var pktLine = nextPktLine()
        var packFileParser
        var remoteLine = ""
        //var packData = ""
        var gotAckOrNak = false
        var ackRegex = /ACK ([0-9a-fA-F]{40}) common/;
        var common = [];

        var pktLineStr = getPktLineStr(pktLine);//utils.bytesToString(data.slice(pktLine.start, pktLine.end));
        var shallow;
        while (pktLineStr.slice(0, 7) === "shallow") {
            pktLine = nextPktLine(true);
            shallow = pktLineStr.substring(8);
            pktLineStr = getPktLineStr(pktLine);
        }

        while (pktLineStr === "NAK\n" ||
            pktLineStr.slice(0, 3) === "ACK") {
            var matches = ackRegex.exec(pktLineStr);
            if (matches) {
                common.push(matches[1]);
            }
            pktLine = nextPktLine();
            pktLineStr = getPktLineStr(pktLine);
            gotAckOrNak = true;
        }

        if (!gotAckOrNak) {
            throw (Error("got neither ACK nor NAK in upload pack response"))
        }
        var packDataLines = [];
        while (pktLine !== null) {
            var pktLineType = data[pktLine.start];
            // sideband format. "2" indicates progress messages, "1" pack data
            switch (pktLineType){
                case 2:
                    break;
                case 1:
                    //packData += utils.bytesToString(pktLine.slice(1))
                    packDataLines.push(data.subarray(pktLine.start + 1, pktLine.end));
                    break;
                case 3:
                    throw (Error("fatal error in packet line"))
                    break;    
            }
            pktLine = nextPktLine()
        }

        // create a blob from the packdata lines then read it as an arraybuffer
        var packDataBlob = new Blob(packDataLines);
        var reader = new FileReader();
        reader.onloadend = function(e){
            var packData = reader.result;
            packFileParser = new Pack(packData, repo);

            packFileParser.parseAll(function() {
                objects = packFileParser.getObjects()

               // console.log("took " + (new Date().getTime() - startTime.getTime()) + "ms")
                success(objects, packFileParser.getData(), common, shallow);
            }, progress);
        }
        reader.readAsArrayBuffer(packDataBlob);
    };
    return {
        parse: parse
    };
});
define('utils/errors',[],function() {

    var errors = {
        // Indicates an unexpected error in the file system.
        FILE_IO_ERROR: 0,
        FILE_IO_ERROR_MSG: 'Unexpected File I/O error',
        // Indicates an unexpected ajax error when trying to make a request
        AJAX_ERROR: 1, 
        AJAX_ERROR_MSG: 'Unexpected ajax error',
        
        // trying to clone into a non-empty directory
        CLONE_DIR_NOT_EMPTY: 2,
        CLONE_DIR_NOT_EMPTY_MSG: 'The target directory contains files',
        // No .git directory
        CLONE_DIR_NOT_INTIALIZED: 3,
        CLONE_DIR_NOT_INTIALIZED_MSG: 'The target directory hasn\'t been initialized.',
        // .git directory already contains objects
        CLONE_GIT_DIR_IN_USE: 4,
        CLONE_GIT_DIR_IN_USE_MSG: 'The target directory contains a .git directory already in use.',
        // No branch found with the name given
        REMOTE_BRANCH_NOT_FOUND: 5,
        REMOTE_BRANCH_NOT_FOUND_MSG: 'Can\'t find the branch name in the remote repository',

        // only supports fast forward merging at the moment.
        PULL_NON_FAST_FORWARD: 6,
        PULL_NON_FAST_FORWARD_MSG: 'Pulling from the remote repo requires a merge.',
        // Branch is up to date
        PULL_UP_TO_DATE: 7,
        PULL_UP_TO_DATE_MSG: 'Everything is up to date',


        UNCOMMITTED_CHANGES: 11,
        UNCOMMITTED_CHANGES_MSG: 'There are changes in the working directory that haven\'t been committed',

        // Nothing to commit
        COMMIT_NO_CHANGES: 8,
        COMMIT_NO_CHANGES_MSG: 'No changes to commit',

        // The remote repo and the local repo share the same head.
        PUSH_NO_CHANGES: 9,
        PUSH_NO_CHANGES_MSG: 'No new commits to push to the repository',

        PUSH_NO_REMOTE: 16,
        PUSH_NO_REMOTE_MSG: 'No remote to push to',

        // Need to merge remote changes first. 
        PUSH_NON_FAST_FORWARD: 10,
        PUSH_NON_FAST_FORWARD_MSG: 'The remote repo has new commits on your current branch. You need to merge them first.',

        BRANCH_ALREADY_EXISTS: 14,
        BRANCH_ALREADY_EXISTS_MSG: 'A local branch with that name already exists',

        BRANCH_NAME_NOT_VALID: 12,
        BRANCH_NAME_NOT_VALID_MSG: 'The branch name is not valid.',

        CHECKOUT_BRANCH_NO_EXISTS: 15,
        CHECKOUT_BRANCH_NO_EXISTS_MSG: 'No local branch with that name exists',

        // unexpected problem retrieving objects
        OBJECT_STORE_CORRUPTED: 200,
        OBJECT_STORE_CORRUPTED_MSG: 'Git object store may be corrupted',

        HTTP_AUTH_ERROR: 201,
        HTTP_AUTH_ERROR_MSG: 'Http authentication failed',

        UNPACK_ERROR: 202,
        UNPACK_ERROR_MSG: 'The remote git server wasn\'t able to understand the push request.',

        
        fileErrorFunc : function(onError){
            if (!onError){
                return function(){};
            }
            return function(e) {
                var msg = errors.getFileErrorMsg(e);
                onError({type : errors.FILE_IO_ERROR, msg: msg, fe: e.code});
            }
        },

        ajaxErrorFunc : function(onError){
            return function(xhr){
                var url = this.url,
                    reqType = this.type;

                var httpErr;
                if (xhr.status == 401){
                    var auth = xhr.getResponseHeader('WWW-Authenticate');
                    httpErr = {type: errors.HTTP_AUTH_ERROR, msg: errors.HTTP_AUTH_ERROR_MSG, auth: auth};
                }
                else{
                    httpErr = {type: errors.AJAX_ERROR, url: url, reqType: reqType, statusText: xhr.statusText, status: xhr.status, msg: "Http error with status code: " + xhr.status + ' and status text: "' + xhr.statusText + '"'};
                }
                onError(httpErr);  
            }
        },

        getFileErrorMsg: function(e) {
            var msg = '';

            switch (e.code) {
                case FileError.QUOTA_EXCEEDED_ERR:
                    msg = 'QUOTA_EXCEEDED_ERR';
                    break;
                case FileError.NOT_FOUND_ERR:
                    msg = 'NOT_FOUND_ERR';
                    break;
                case FileError.SECURITY_ERR:
                    msg = 'SECURITY_ERR';
                    break;
                case FileError.INVALID_MODIFICATION_ERR:
                    msg = 'INVALID_MODIFICATION_ERR';
                    break;
                case FileError.INVALID_STATE_ERR:
                    msg = 'INVALID_STATE_ERR';
                    break;
                case FileError.ABORT_ERR:
                    msg = 'ABORT_ERR';
                    break;
                case FileError.ENCODING_ERR:
                    msg = 'ENCODING_ERR';
                    break;
                case FileError.NOT_READABLE_ERR:
                    msg = 'NOT_READABLE_ERR';
                    break;
                case FileError.NO_MODIFICATION_ALLOWED_ERR:
                    msg = 'NO_MODIFICATION_ALLOWED_ERR';
                    break;
                case FileError.PATH_EXISTS_ERR:
                    msg = 'PATH_EXISTS_ERR';
                    break;
                case FileError.SYNTAX_ERR:
                    msg = 'SYNTAX_ERR';
                    break;
                case FileError.TYPE_MISMATCH_ERR:
                    msg = 'TYPE_MISMATCH_ERR';
                    break;
                default:
                    msg = 'Unknown Error ' + e.code;
                    break;
            };
        },
        errorHandler: function(e) {
            msg = utils.getFileErrorMsg(e);
            console.log('Error: ' + msg);
        }
    }
    return errors;

});
define('utils/progress_chunker',[],function(){

    var ProgressChunker = function(func){
        this.master = func;
    }

    ProgressChunker.prototype = {
        getChunk : function(start, fraction){
            var self = this;
            return function(data){
                var newPct = start + (data.pct * fraction)
                self.master({pct: newPct, msg: data.msg});
            }
        }
    }

    return ProgressChunker;

});
define('formats/smart_http_remote',['formats/upload_pack_parser', 'utils/errors', 'utils/progress_chunker'], function(UploadPackParser, errutils, ProgressChunker) {
    // var workerBlob = new Blob([packWorkerText]);
    // var workerUrl = URL.createObjectURL(workerBlob);

    var SmartHttpRemote = function(store, name, repoUrl, username, password, error) {
        this.store = store;
        this.name = name;
        this.refs = {};
        this.url = repoUrl.replace(/\?.*/, "").replace(/\/$/, "");
        username = username || "";
        password = password || "";

        var ajaxErrorHandler = errutils.ajaxErrorFunc(error);

        var parseDiscovery = function(data) {
            var lines = data.split("\n")
            var result = {
                "refs": []
            }
            for (i = 1; i < lines.length - 1; i++) {
                var thisLine = lines[i]
                if (i == 1) {
                    var bits = thisLine.split("\0")
                    result["capabilities"] = bits[1]
                    var bits2 = bits[0].split(" ")
                    result["refs"].push({
                        name: bits2[1],
                        sha: bits2[0].substring(8)
                    })
                } else {
                    var bits2 = thisLine.split(" ")
                    result["refs"].push({
                        name: bits2[1],
                        sha: bits2[0].substring(4)
                    })
                }
            }
            return result
        }

        var padWithZeros = function(num) {
            var hex = num.toString(16);
            var pad = 4 - hex.length;
            for (var x = 0; x < pad; x++) {
                hex = '0' + hex;
            }
            return hex;
        }

        var pushRequest = function(refPaths, packData) {
            

            var pktLine = function(refPath) {
                return refPath.sha + ' ' + refPath.head + ' ' + refPath.name;
            }
            var bb = []; //new BlobBuilder();
            var str = pktLine(refPaths[0]) + '\0report-status\n';
            str = padWithZeros(str.length + 4) + str;
            bb.push(str);
            for (var i = 1; i < refPaths.length; i++) {
                if (!refPaths[i].head) continue;
                var val = pktLine(refPaths[i]) + '\n';
                val = padWithZeros(val.length + 4)
                bb.push(val);
            }
            bb.push('0000');
            bb.push(new Uint8Array(packData));
            var blob = new Blob(bb);
            return blob;

        }

        var refWantRequest = function(wantRefs, haveRefs, shallow, depth, moreHaves) {
            var str = "0067want " + wantRefs[0].sha + " multi_ack_detailed side-band-64k thin-pack ofs-delta\n"
            for (var i = 1; i < wantRefs.length; i++) {
                str += "0032want " + wantRefs[i].sha + "\n"
            }
            if (haveRefs && haveRefs.length) {
                if (shallow){
                    str += "0034shallow " + shallow;
                }
                str += "0000"
                _(haveRefs).each(function(haveRef) {
                    str += "0032have " + haveRef.sha + "\n"
                });
                if (moreHaves) {
                    str += "0000"
                } else {
                    str += "0009done\n"
                }

            } else {
                if (depth){
                    var depthStr = "deepen " + depth;
                    str += (padWithZeros(depthStr.length + 4) + depthStr);
                }
                str += "0000"
                str += "0009done\n"
            }
            return str
        }

        var queryParams = function(uri) {
            var paramString = uri.split("?")[1]
            if (!paramString) {
                return {}
            }

            var paramStrings = paramString.split("&")
            var params = {}
            _(paramStrings).each(function(paramString) {
                var pair = paramString.split("=")
                params[pair[0]] = decodeURI(pair[1])
            })
            return params
        }

        this.urlOptions = queryParams(repoUrl);

        function doGet(url, success){
            var xhr = new XMLHttpRequest();
            xhr.open("GET", url, true, username, password);

            xhr.onload = function(evt){
                if (xhr.readyState == 4) {
                    if (xhr.status == 200) {
                        success(xhr.responseText);
                    } 
                    else{ 
                        var obj = {url: url, type: 'GET'};
                        ajaxErrorHandler.call(obj, xhr); 
                    }
                }
            }
            

            var xhr2ErrorShim = function(){
                var obj = {url: url, type: 'POST'};
                ajaxErrorHandler.call(obj, xhr); 
            }
            xhr.onerror = xhr2ErrorShim;
            xhr.onabort = xhr2ErrorShim;
            xhr.send();
        }
        this.fetchRefs = function(callback) {
            var remote = this,
                uri = this.makeUri('/info/refs', {service: "git-upload-pack"});
            doGet(uri, function(data) {
                var discInfo = parseDiscovery(data)
                var i, ref
                for (i = 0; i < discInfo.refs.length; i++) {
                    ref = discInfo.refs[i]
                    remote.addRef(ref.name, ref.sha)
                }
                if (callback != "undefined") {
                    callback(discInfo.refs)
                }
            });
        }

        this.fetchReceiveRefs = function(callback) {
            var remote = this,
                uri = this.makeUri('/info/refs', {service: "git-receive-pack"});
            doGet(uri, function(data) {
                var discInfo = parseDiscovery(data)
                var i, ref
                for (i = 0; i < discInfo.refs.length; i++) {
                    ref = discInfo.refs[i]
                    remote.addRef(ref.name, ref.sha)
                }
                if (callback != "undefined") {
                    callback(discInfo.refs)
                }
            });
        }

        this.fetchRef = function(wantRefs, haveRefs, shallow, depth, moreHaves, callback, noCommon, progress) {
            var url = this.makeUri('/git-upload-pack')
            var body = refWantRequest(wantRefs, haveRefs, shallow, depth);
            var thisRemote = this
            var xhr = new XMLHttpRequest();

            var packProgress, receiveProgress;
            if (progress){
                var chunker = new ProgressChunker(progress);
                receiveProgress = chunker.getChunk(0, 0.2);
                packProgress = chunker.getChunk(20, 0.8);
            }

            xhr.open("POST", url, true, username, password);
            xhr.responseType = 'arraybuffer';
            xhr.setRequestHeader("Content-Type", "application/x-git-upload-pack-request");

            xhr.onload = function() {

                var binaryData = xhr.response;
                if (haveRefs && String.fromCharCode.apply(null, new Uint8Array(binaryData, 4, 3)) == "NAK") {
                    if (moreHaves) {
                        thisRemote.store._getCommitGraph(moreHaves, 32, function(commits, next) {
                            thisRemote.fetchRef(wantRefs, commits, depth, next, callback, noCommon);
                        });
                    }
                    else if (noCommon){
                        noCommon();
                    }
                } else {
                    if (packProgress){
                        packProgress({pct: 0, msg: "Parsing pack data"});
                    }
                    UploadPackParser.parse(binaryData, store, function(objects, packData, common, shallow) {
                        if (callback) {
                            callback(objects, packData, common, shallow);
                        }
                    }, packProgress);
                    // var packWorker = new Worker(workerUrl);
                    // packWorker.onmessage = function(evt){
                    //     var msg = evt.data;
                    //     if (msg.type == GitLiteWorkerMessages.FINISHED && callback){
                    //         packWorker.terminate();
                    //         callback(msg.objects, new Uint8Array(msg.data), msg.common);
                    //     }
                    //     else if (msg.type == GitLiteWorkerMessages.RETRIEVE_OBJECT){
                    //         store._retrieveRawObject(msg.sha, "ArrayBuffer", function(baseObject){
                    //             packWorker.postMessage({type: GitLiteWorkerMessages.OBJECT_RETRIEVED, id: msg.id, object: baseObject}, [baseObject.data]);
                    //             var x = 0;
                    //         });
                    //     }
                    //     else if (progress && msg.type == GitLiteWorkerMessages.PROGRESS){
                    //         progress(msg);
                    //     }
                    // }
                    // packWorker.postMessage({type: GitLiteWorkerMessages.START, data:binaryData}, [binaryData]);
                }
            }
            if (receiveProgress){
                xhr.onprogress = function(evt){
                    // if (evt.lengthComputable){
                    //     var pct = evt.loaded / evt.total;
                    //     receiveProgress({pct: pct, msg: "Received " + evt.loaded + "/" + evt.total + " bytes"});
                    // }
                    // else{

                        receiveProgress({pct: 100, msg: "Received " + (evt.loaded/1048576).toFixed(2) + " MB"});
                    // }
                }
            }
            var xhr2ErrorShim = function(){
                var obj = {url: url, type: 'POST'};
                ajaxErrorHandler.call(obj, xhr); 
            }

            xhr.onerror = xhr2ErrorShim;
            xhr.onabort = xhr2ErrorShim;

            xhr.send(body);

            //  $.ajax({
            //    url: url,
            //    data: body,
            //    type: "POST",
            //    contentType: "application/x-git-upload-pack-request",
            //    beforeSend: function(xhr) {
            //      xhr.overrideMimeType('text/plain; charset=x-user-defined')
            //    },
            //    success: function(data, textStatus, xhr) {
            //      var binaryData = xhr.responseText
            //      if (haveRefs && binaryData.indexOf("NAK") == 4){
            //      	if (moreHaves){
            // 	thisRemote.repo._getCommitGraph(moreHaves, 32, function(commits, next){
            // 		thisRemote.fetchRef(wantRefs, commits, next, callback);
            // 	});
            // }
            //      }
            //      else{
            // var parser = new Git.UploadPackParser(binaryData, repo)
            // parser.parse(function(objects, packData, common){
            // 	if (callback != "undefined") {
            // 	  callback(objects, packData, common);
            // 	}
            // });
            // }        
            //    },
            //    error: function(xhr, data, e) {
            //      Git.displayError("ERROR Status: " + xhr.status + ", response: " + xhr.responseText)
            //    }
            //  });
        },

        this.pushRefs = function(refPaths, packData, success, progress) {
            var url = this.makeUri('/git-receive-pack');
            var body = pushRequest(refPaths, packData);
            var xhr = new XMLHttpRequest();
            xhr.open("POST", url, true, username, password);
            xhr.onload = function(evt) {
                if (xhr.readyState == 4) {
                    if (xhr.status == 200) {
                        var msg = xhr.response;
                        if (msg.indexOf('000eunpack ok') == 0){
                            success();
                        }
                        else{
                            error({type: errutils.UNPACK_ERROR, msg: errutils.UNPACK_ERROR_MSG});
                        }
                    } 
                    else{ 
                        var obj = {url: url, type: 'POST'};
                        ajaxErrorHandler.call(obj, xhr); 
                    }
                }
            }
            xhr.setRequestHeader('Content-Type', 'application/x-git-receive-pack-request');
            var bodySize = (body.size/1024).toFixed(2);
            xhr.upload.onprogress = function(evt){
                progress({pct: evt.loaded/body.size * 100, msg: 'Sending ' + (evt.loaded/1024).toFixed(2) + '/' + bodySize + " KB"});
            }
            xhr.send(body);
            /*Gito.FileUtils.readBlob(body, 'BinaryString', function(strData){
    		$.ajax({
    			url : url,
    			data : strData,
    			type : 'POST',
    			contentType : 'application/x-git-receive-pack-request',
    			processData : false,
    			//mimeType :'text/plain; charset=x-user-defined',
  		  	success : function(data, textstatus, xhr){
  		  		var x = 0;
  		  	},
  		  	error : function (xhr, data, e){
  		  		Git.displayError("ERROR Status: " + xhr.status + ", response: " + xhr.responseText)
  		  	}
    		});
    	});*/
        }

        this.makeUri = function(path, extraOptions) {
            var uri = this.url + path
            var options = _(this.urlOptions).extend(extraOptions || {})
            if (options && _(options).size() > 0) {
                var optionKeys = _(options).keys()
                var optionPairs = _(optionKeys).map(function(optionName) {
                    return optionName + "=" + encodeURI(options[optionName])
                })

                return uri + "?" + optionPairs.join("&")
            } else {
                return uri
            }
        }

        // Add a ref to this remote. fullName is of the form:
        //   refs/heads/master or refs/tags/123
        this.addRef = function(fullName, sha) {
            var type, name
            if (fullName.slice(0, 5) == "refs/") {
                type = fullName.split("/")[1]
                name = this.name + "/" + fullName.split("/")[2]
            } else {
                type = "HEAD"
                name = this.name + "/" + "HEAD"
            }
            this.refs[name] = {
                name: name,
                sha: sha,
                remote: this,
                type: type
            }
        }

        this.getRefs = function() {
            return _(this.refs).values()
        }

        this.getRef = function(name) {
            return this.refs[this.name + "/" + name]
        }
    }
    return SmartHttpRemote;
});

define('formats/pack_index',[],function(){
    // This object partially parses the data contained in a pack-*.idx file, and provides
    // access to the offsets of the objects the packfile and the crc checksums of the objects.
    PackIndex = function(buf) {
    	var data = new DataView(buf);
    	this.data = data;
    	// load the index into memory
    	var magicNum = data.getUint32(0, false);
    	var versionNum = data.getUint32(4, false);
    	
    	if (magicNum != 0xff744f63 || versionNum != 2){
    		throw(Error("Bad pack index header. Only version 2 is supported"))
    	}
    	
    	var byteOffset = 8
    	//this.fanOffset = byteOffset;
    	
    	var numObjects = data.getUint32(byteOffset + (255 * 4), false);
    	
    	// skip past fanout table
    	var fanTableLen = 256 * 4;
    	byteOffset += fanTableLen; 
    	var shaTableLen = numObjects * 20;
    	this.shaList = new Uint8Array(buf, byteOffset, shaTableLen);
    	
    	// skip past shas and the CRC vals
    	byteOffset += shaTableLen + (numObjects * 4);
    	
    	this.offsetsOffset = byteOffset;
    	this.numObjects = numObjects;
    }

    PackIndex.prototype = {
    	_compareShas : function(sha1, sha2){
    		 // assume the first byte has been matched in the fan out table
    		for (var i = 1; i < 20; i++){
    			if (sha1[i] != sha2[i]){
    				return sha1[i] - sha2[i];
    			}
    		}
    		return 0;
    	},
    	_getShaAtIndex : function(index){
    	    var byteOffset = index * 20;
    	    return this.shaList.subarray(byteOffset, byteOffset + 20); 
    	},
    	getObjectOffset : function(sha){
    		var fanIndex = sha[0];
    		
    		var sliceStart = fanIndex > 0 ? (this.data.getUint32(8 + ((fanIndex - 1) * 4), false)) : 0;
    		var sliceEnd = this.data.getUint32(8 + (fanIndex * 4), false);
    		
    		if (sliceEnd - sliceStart == 0){
    			return -1;
    		}
    		
    		var index;
    		while (sliceEnd - sliceStart  > 1){
    			var split = sliceStart + Math.floor(((sliceEnd - sliceStart)/2));
    			
    			var mid = this._getShaAtIndex(split);
    			
    			var compare = this._compareShas(sha, mid);
    			if (compare == 0){
    				index = split;
    				break;
    			}
    			else if (compare < 0){
    				sliceEnd = split;
    			}
    			else{
    				sliceStart = split + 1;
    			}
    		}
    		// if we've exited the loop without a match, sliceStart should hold the index or it's not here. 
    		if (!index){
    			if (sliceStart < this.numObjects && this._compareShas(sha, this._getShaAtIndex(sliceStart)) == 0){
    				index = sliceStart;
    			}
    			else{
    				return -1;
    			}
    		}
    		
    		var objOffset = this.data.getUint32(this.offsetsOffset + (index * 4), false); 
    		return objOffset;
    		
    	}
    }
    /*
    * = Version 2 pack-*.idx files support packs larger than 4 GiB, and
    *  have some other reorganizations.  They have the format:
    *
    *  - A 4-byte magic number '\377tOc' which is an unreasonable
    *    fanout[0] value.
    *
    *  - A 4-byte version number (= 2)
    *
    *  - A 256-entry fan-out table just like v1.
    *
    *  - A table of sorted 20-byte SHA1 object names.  These are
    *    packed together without offset values to reduce the cache
    *    footprint of the binary search for a specific object name.
    *
    *  - A table of 4-byte CRC32 values of the packed object data.
    *    This is new in v2 so compressed data can be copied directly
    *    from pack to pack during repacking without undetected
    *    data corruption.
    *
    *  - A table of 4-byte offset values (in network byte order).
    *    These are usually 31-bit pack file offsets, but large
    *    offsets are encoded as an index into the next table with
    *    the msbit set.
    *
    *  - A table of 8-byte offset entries (empty for pack files less
    *    than 2 GiB).  Pack files are organized with heavily used
    *    objects toward the front, so most object references should
    *    not need to refer to this table.
    *
    *  - The same trailer as a v1 pack file:
    *
    *    A copy of the 20-byte SHA1 checksum at the end of
    *    corresponding packfile.
    *
    *    20-byte SHA1-checksum of all of the above.
    */
    PackIndex.writePackIdx = function(objects, packSha){
    	var size = 4 + 4 + (256 * 4) + (objects.length * 20) + (objects.length * 4)  + (objects.length * 4) + (20 * 2);
    	var buf = new ArrayBuffer(size);
    	
    	objects.sort(function(obj1, obj2){
    		for (var i = 0; i < 20; i++){
    			if (obj1.sha[i] != obj2.sha[i]){
    				return obj1.sha[i] - obj2.sha[i];
    			}
    		}
    		return 0; // shouldn't happen but just in case
    	});
    	
        var data = new DataView(buf);
        
        // magic number
        data.setUint32(0, 0xff744f63, false);
        
        //version number
        data.setUint32(4, 2, false);
        
        // fan table
        var byteOffset = 8, current = 0;
     
        for (var i = 0; i < objects.length; i++){
        	var next = objects[i].sha[0];
        	if (next != current){
        		
        		for (var j = current; j < next; j++){
        			data.setUint32(byteOffset + (j * 4), i, false);
        		}
        	}
        	current = next;
        }
        for (var j = current; j < 256; j++){
    		data.setUint32(byteOffset + (j * 4), objects.length, false);
    	}
        
        // list of shas
        byteOffset += (256 * 4);
        
        for (var i = 0; i < objects.length; i++){
        	for (var j = 0; j < 20; j++){
        		data.setUint8(byteOffset++, objects[i].sha[j]);
        	}
        }
        
        // list of crcs
        for (var i = 0; i < objects.length; i++){
        	data.setUint32(byteOffset, objects[i].crc, false);
        	byteOffset += 4;
        }
        
        // list of offsets. Note that I'm not going to bother with large offsets. You shouldn't be loading a packfile >2GB inside a web browser anyway.
        for (var i = 0; i < objects.length; i++){
        	data.setUint32(byteOffset, objects[i].offset, false);
        	byteOffset += 4;
        }
        
        // the pack file sha
        for (var i = 0; i < 20; i++){
        	data.setUint8(byteOffset++, packSha[i]);
        }
        
        // sha for all of the above
        var indexSha = Crypto.SHA1(new Uint8Array(buf, 0, byteOffset), {asBytes:true});
        for (var i = 0; i < 20; i++){
        	data.setUint8(byteOffset++, indexSha[i]);
        }
        return buf;
    }
      
    return PackIndex;
});


define('commands/clone',['commands/object2file', 'formats/smart_http_remote', 'formats/pack_index', 'formats/pack', 'utils/file_utils', 'utils/errors', 'utils/progress_chunker'], function(object2file, SmartHttpRemote, PackIndex, Pack, fileutils, errutils, ProgressChunker){
    
    var _createCurrentTreeFromPack = function(dir, store, headSha, callback){
         store._retrieveObject(headSha, "Commit", function(commit){
            var treeSha = commit.tree;
            object2file.expandTree(dir, store, treeSha, callback);
         });
    }
    
    var checkDirectory = function(dir, store, success, error, ferror){
        fileutils.ls(dir, function(entries){
            
            if (entries.length == 0){
                error({type: errutils.CLONE_DIR_NOT_INTIALIZED, msg: errutils.CLONE_DIR_NOT_INTIALIZED_MSG});
            }
            else if (entries.length != 1 || entries[0].isFile || entries[0].name != '.git'){
                error({type: errutils.CLONE_DIR_NOT_EMPTY, msg: errutils.CLONE_DIR_NOT_EMPTY_MSG});
            }
            else{
                fileutils.ls(store.objectsDir, function(entries){
                    if (entries.length > 1){
                        error({type: errutils.CLONE_GIT_DIR_IN_USE, msg: errutils.CLONE_GIT_DIR_IN_USE_MSG});
                    }
                    else if (entries.length == 1){
                        if (entries[0].name == "pack"){
                            store.objectsDir.getDirectory('pack', {create: false}, function(packDir){
                                fileutils.ls(packDir, function(entries){
                                    if (entries.length > 0){
                                        error({type: errutils.CLONE_GIT_DIR_IN_USE, msg: errutils.CLONE_GIT_DIR_IN_USE_MSG});
                                    }
                                    else{
                                        success();
                                    }
                                }, ferror);
                            }, success);
                        }
                        else{
                            error({type: errutils.CLONE_GIT_DIR_IN_USE, msg: errutils.CLONE_GIT_DIR_IN_USE_MSG});
                        }
                    }
                    else{
                        success();
                    }
                }, ferror);
            }

        }, ferror);
    };

    var clone = function(options, success, error){
        
        var dir = options.dir,
            store = options.objectStore,
            url = options.url,
            callback = success,
            depth = options.depth,
            branch = options.branch || 'master',
            progress = options.progress || function(){},
            username = options.username,
            password = options.password,
            ferror = errutils.fileErrorFunc(error);
    
        var chunker = new ProgressChunker(progress);
        var packProgress = chunker.getChunk(0, .95);

        var mkdirs = fileutils.mkdirs,
            mkfile = fileutils.mkfile,
            remote = new SmartHttpRemote(store, "origin", url, username, password, error);

        var createInitialConfig = function(shallow, localHeadRef, callback){
            var config = {url: url, time: new Date()};
            if (options.depth && shallow){
                config.shallow = shallow;
            }
            config.remoteHeads = {};
            
            if (localHeadRef)
                config.remoteHeads[localHeadRef.name] = localHeadRef.sha;

            store.setConfig(config, callback);  
        }

        checkDirectory(dir, store, function(){ 
            mkdirs(dir, ".git", function(gitDir){
                remote.fetchRefs(function(refs){
                    
                    if (!refs.length){
                        createInitialConfig(null, null, success);
                        return;
                    }

                    var remoteHead, remoteHeadRef, localHeadRef;

                    _(refs).each(function(ref){
                        if (ref.name == "HEAD"){
                            remoteHead = ref.sha;
                        }
                        else if (ref.name == "refs/heads/" + branch){
                            localHeadRef = ref;
                        }
                        else if (ref.name.indexOf("refs/heads/") == 0){
                            if (ref.sha == remoteHead){
                                remoteHeadRef = ref;
                            }
                        }
                    });

                    if (!localHeadRef){
                        if (options.branch){
                            error({type: errutils.REMOTE_BRANCH_NOT_FOUND, msg: errutils.REMOTE_BRANCH_NOT_FOUND_MSG});
                            return;
                        }
                        else{
                            localHeadRef = remoteHeadRef;
                        }
                    }

                    mkfile(gitDir, "HEAD", 'ref: ' + localHeadRef.name + '\n', function(){
                        mkfile(gitDir, localHeadRef.name, localHeadRef.sha + '\n', function(){
                            remote.fetchRef([localHeadRef], null, null, depth, null, function(objects, packData, common, shallow){
                                var packSha = packData.subarray(packData.length - 20);
                                
                                var packIdxData = PackIndex.writePackIdx(objects, packSha);
                                
                                // get a view of the sorted shas
                                var sortedShas = new Uint8Array(packIdxData, 4 + 4 + (256 * 4), objects.length * 20);
                                packNameSha = Crypto.SHA1(sortedShas);
                                
                                var packName = 'pack-' + packNameSha;
                                mkdirs(gitDir, 'objects', function(objectsDir){
                                    mkfile(objectsDir, 'pack/' + packName + '.pack', packData.buffer);
                                    mkfile(objectsDir, 'pack/' + packName + '.idx', packIdxData);
                                    
                                    var packIdx = new PackIndex(packIdxData);
                                    store.loadWith(objectsDir, [{pack: new Pack(packData, self), idx: packIdx}]);
                                    progress({pct: 95, msg: "Building file tree from pack. Be patient..."});
                                    _createCurrentTreeFromPack(dir, store, localHeadRef.sha, function(){
                                        createInitialConfig(shallow, localHeadRef, callback);
                                    });
                                }, ferror); 
                            }, null, packProgress);
                        }, ferror);
                    }, ferror);
                });
            }, ferror);
        }, error, ferror);
    }
    return clone;
});
define('commands/commit',['utils/file_utils', 'utils/misc_utils', 'utils/errors'], function (fileutils, miscutils, errutils) {

    var walkFiles = function(dir, store, success){
               
        fileutils.ls(dir, function(entries){
            if (!entries.length){
                success();
                return;
            }

            var treeEntries = [];
            entries.asyncEach(function(entry, done){
                if (entry.name == '.git'){
                    done();
                    return;
                }
                if (entry.isDirectory){
                    walkFiles(entry, store, function(sha){
                        if (sha){
                            treeEntries.push({name: /*'40000 ' + */entry.name, sha: miscutils.convertShaToBytes(sha), isBlob: false});
                        }
                        done();
                    });
                    
                }
                else{
                    entry.file(function(file){
                        var reader = new FileReader();
                        reader.onloadend = function(){
                            store.writeRawObject('blob', new Uint8Array(reader.result), function(sha){
                                treeEntries.push({name: /*'100644 ' + */entry.name, sha: miscutils.convertShaToBytes(sha), isBlob: true});
                                done();
                            });
                        }
                        reader.readAsArrayBuffer(file);
                    });
                }
            },
            function(){
                treeEntries.sort(function(a,b){
                    //http://permalink.gmane.org/gmane.comp.version-control.git/195004
                    var aName = a.isBlob ? a.name : (a.name + '/');
                    var bName = b.isBlob ? b.name : (b.name + '/');
                    if (aName < bName) return -1;
                    else if (aName > bName) return 1;
                    else
                    return 0;
                });
                store._writeTree(treeEntries, success);
            })
        });       
    }

    var checkTreeChanged = function(store, parent, sha, success, error){
        if (!parent || !parent.length){
            success();
        }
        else{
            store._retrieveObject(parent, "Commit", function(parentCommit){
                var oldTree = parentCommit.tree;
                if (oldTree == sha){
                    error({type: errutils.COMMIT_NO_CHANGES, msg: errutils.COMMIT_NO_CHANGES_MSG});
                }
                else{
                    success();
                }
            }, function(){
                error({type: errutils.OBJECT_STORE_CORRUPTED, msg: errutils.OBJECT_STORE_CORRUPTED_MSG});  
            })
        }
    }

    var _createCommitFromWorkingTree =  function(options, parent, ref, success, error){ 

        var dir = options.dir,
            store = options.objectStore,
            username = options.username,
            email = options.email,
            commitMsg = options.commitMsg;

        walkFiles(dir, store, function(sha){
            checkTreeChanged(store, parent, sha, function(){
                var now = new Date();
                var dateString = Math.floor(now.getTime()/1000);
                var offset = now.getTimezoneOffset()/-60;
                var absOffset = Math.abs(offset);
                var offsetStr = '' + (offset < 0 ? '-' : '+') + (absOffset < 10 ? '0' : '') + absOffset + '00';
                dateString = dateString + ' ' + offsetStr;
                var commitContent = ['tree ',sha,'\n'];
                if (parent && parent.length){
                    commitContent.push('parent ', parent);
                    if (parent.charAt(parent.length - 1) != '\n'){
                        commitContent.push('\n');
                    }
                }
                    
                commitContent.push('author ', username, ' <',email, '> ',  dateString,'\n', 
                    'committer ', username,' <', email, '> ', dateString, '\n\n', commitMsg,'\n');
                store.writeRawObject('commit', commitContent.join(''), function(commitSha){
                    fileutils.mkfile(dir, '.git/' + ref, commitSha + '\n', function(){
                        store.updateLastChange(null, function(){
                            success(commitSha);
                        });
                    });
                });
            }, error);
        });
    }

    var commit = function(options, success, error){
        var rootDir = options.dir,
            objectStore = options.objectStore;

        var ref;
        var buildCommit = function(parent){
            _createCommitFromWorkingTree(options, parent, ref, success, error);
        }
        objectStore.getHeadRef(function(headRef){
            ref = headRef;
            objectStore._getHeadForRef(ref, buildCommit, function(){ buildCommit(); });
        });
    }

    return commit;

});
define('commands/init',[],function(){
    var init = function(options, success, error){
        var objectStore = options.objectStore;
        objectStore.init(success, error);
    }
    return init; 
});
define('commands/treemerger',['utils/misc_utils'], function(utils){

	var diffTree = function(oldTree, newTree){
		oldTree.sortEntries();
		newTree.sortEntries();
		
		var oldEntries = oldTree.entries, 
			newEntries = newTree.entries;
		var oldIdx = newIdx = 0;
		
		var remove = [],
			add = [], 
			merge = [];
		
		
		
		while (true){
			var nu = newEntries[newIdx];
			var old = oldEntries[oldIdx];
			
			if (!nu){
				if (!old){
					break;
				}
				remove.push(old);
				oldIdx++;
			}
			else if (!old){
				add.push(nu);
				newIdx++;
			}
			else if (nu.name < old.name){
				add.push(nu);
				newIdx++;
			}
			else if (nu.name > old.name){
				remove.push(old);
				oldIdx++;
			}
			else{
				if (utils.compareShas(nu.sha,old.sha) != 0){
					merge.push({nu:nu, old:old});
				}
				oldIdx++;
				newIdx++;
			}
		}
		return {add:add, remove:remove, merge: merge};
	};
	
	 var mergeTrees = function(store, ourTree, baseTree, theirTree, success, error){
		
		var finalTree = [], 
			next = null;
			indices = [0,0,0],
			conflicts = [];
		
		
		
		// base tree can be null if we're merging a sub tree from ours and theirs with the same name
		// but it didn't exist in base. 
		if (baseTree == null){
			baseTree = {entries:[], sortEntries: function(){}};
		}
		
		ourTree.sortEntries();
		theirTree.sortEntries();
		baseTree.sortEntries();
		
		var allTrees = [ourTree.entries, baseTree.entries, theirTree.entries];
		
		while (conflicts.length == 0){
			next = null;
			var nextX = 0;
			for (var x = 0; x < allTrees.length; x++){
				var treeEntries = allTrees[x];
				var top = treeEntries[indices[x]];
				
				if (!next || (top && top.name < next.name)){
					next = top;
					nextX = x;
				}
			}
			
			if (!next){
				break;
			}
			
			function shasEqual(sha1, sha2){
				for (var i = 0; i < sha1.length; i++){
					if (sha1[i] != sha2[i]){
						return false;
					}
				}
				return true;
			}

			switch (nextX){
				case 0:
					var theirEntry = allTrees[2][indices[2]];
					var baseEntry = allTrees[1][indices[1]];
					if (theirEntry.name == next.name){
						if (!shasEqual(theirEntry.sha,next.sha)){
							if (baseEntry.name != next.name){
								baseEntry = {entries:[]};
								if (next.isBlob){
									conflicts.push({conflict:true, ours: next, base: null, theirs: theirEntry});
									break;
								}
							}
							if (next.isBlob === theirEntry.isBlob && (baseEntry.isBlob === next.isBlob)){
								if (shasEqual(next.sha, baseEntry.sha)){
									finalTree.push(theirEntry);
								}
								else{
									finalTree.push({merge:true, ours: next, base: baseEntry, theirs: theirEntry});
								}
							}
							else{
								conflicts.push({conflict:true, ours: next, base: baseEntry, theirs: theirEntry});
							}
						}
						else{
							finalTree.push(next);
						}
					}
					else if (baseEntry.name == next.name){
						if (!shasEqual(baseEntry.sha, next.sha)){
							//deleted from theirs but changed in ours. Delete/modify conflict.
							conflicts.push({conflict:true, ours: next, base: baseEntry, theirs: null});
						}
					}
					else{
						finalTree.push(next);
					}
					break;
				case 1:
					var theirEntry = allTrees[indices[2]];
					if (next.name == theirEntry.name && !shasEqual(next.sha, theirEntry.sha)){
						// deleted from ours but changed in theirs. Delete/modify conflict
						conflicts.push({conflict: true, ours: null, base: next, theirs: theirEntry}); 
					}
					break;
				case 2:
					finalTree.push(next);
					break;
			}
			
			for (var x = 0; x < allTrees.length; x++){
				var treeEntries = allTrees[x];	
				if (treeEntries[indices[x]].name == next.name){
					indices[x]++;
				}
			}
			
		}
		
		if (conflicts.length){
			error(conflicts);
		}
		
		//var mergeBlobs = function(
		var self = this;
		
		finalTree.asyncEach(function(item, done, index){
			if (item.merge){
				
				var shas = [item.ours.sha, item.base.sha, item.theirs.sha];
				if (item.ours.isBlob){
					store._retrieveBlobsAsStrings(shas, function(blobs){
						var newBlob = Diff.diff3_dig(blobs[0].data, blobs[1].data, blobs[2].data); 
						if (newBlob.conflict){
							conflicts.push(newBlob);
							done();
						}
						else{
							store.writeRawObject(objectDir, 'blob', newBlob.text, function(sha){
								finalTree[index].sha = sha;
								done(); 
							});
						}
						
					});
				}
				else{
					store._retrieveObjectList(shas, 'Tree', function(trees){
						self.mergeTrees(trees[0], trees[1], trees[2], function(mergedSha){
							finalTree[index] = item.ours;
							item.ours.sha = mergedSha;
							done();
						},
						function(newConflicts){
							conflicts = conflicts.concat(newConflicts);
							done();
						});
					});
				}
				
			}
			else{
				done();
			}
		},
		function(){
			if (!conflicts.length){
				//Gito.FileUtils.mkdirs(self.dir, '.git/objects', function(objectDir){
				store._writeTree(finalTree, success);
				//});
				//success(finalTree)
			}
			else{
				error(conflicts);
			}
		});
		
	}
	return {
		mergeTrees : mergeTrees,
		diffTree : diffTree
	}
	
});

define('commands/conditions',['utils/file_utils', 'utils/errors'],function(fileutils, errutils){

    var conditions = {

        checkForUncommittedChanges : function(dir, store, callback, error){
            var lastUpdate;
            var walkDir = function(dir, callback){
                
                dir.getMetadata(function(md){
                    if (md.modificationTime > lastUpdate){
                        callback(true);
                        return;
                    }
                    fileutils.ls(dir, function(entries){
                        var changed;
                        entries.asyncEach(function(entry, done){
                            if (changed){
                                done();
                                return;
                            }

                            if (entry.isDirectory){
                                if (entry.name == '.git'){
                                    done();
                                    return;
                                }
                                entry.getMetadata(function(md){
                                    walkDir(entry, function(isChanged){
                                        changed |= isChanged;
                                        done();
                                    });
                                }, done);
                            }
                            else{
                                entry.getMetadata(function(md){
                                    if (md.modificationTime > lastUpdate){
                                        changed = true;
                                    }
                                    done();
                                }, done);
                                
                            }
                        },function(){
                            callback(changed);
                        });
                    });
                });
            };

            store.getConfig(function(config){
                // this would mean we have no commits.
                if (!config.time){
                    config.time = 1;
                }
                lastUpdate = new Date(config.time);
                walkDir(dir, function(changed){
                    if (changed){
                        error({type: errutils.UNCOMMITTED_CHANGES, msg: errutils.UNCOMMITTED_CHANGES_MSG});
                    }
                    else{
                        callback(config);
                    }
                });
            });
        }
    }
    return conditions;
});
define('commands/pull',['commands/treemerger', 'commands/object2file', 'commands/conditions', 'formats/smart_http_remote', 'formats/pack_index', 'formats/pack', 'utils/file_utils', 'utils/errors', 'utils/progress_chunker'], function(treeMerger, object2file, Conditions, SmartHttpRemote, PackIndex, Pack, fileutils, errutils, ProgressChunker){
    

    var _updateWorkingTree = function (dir, store, fromTree, toTree, success){
        
        var processOps = function(rootDir, ops, callback){
            ops.remove.asyncEach(function(entry, done){
                var rm = entry.isBlob ? fileutils.rmFile : fileutils.rmDir;
                rm(rootDir, entry.name, done);
            },
            function(){
                ops.add.asyncEach(function(entry, done){
                    if (!entry.isBlob){
                        fileutils.mkdirs(rootDir, entry.name, function(dirEntry){
                            object2file.expandTree(dirEntry, store, entry.sha, done);
                        });
                    }
                    else{
                        object2file.expandBlob(rootDir, store, entry.name, entry.sha, done); 
                    }
                },
                function(){
                    ops.merge.asyncEach(function(entry, done){
                        if (entry.nu.isBlob){
                            object2file.expandBlob(rootDir, store, entry.nu.name, entry.nu.sha, done); 
                        }
                        else{
                            store._retrieveObjectList([entry.old.sha, entry.nu.sha], 'Tree', function(trees){
                                var newOps = treeMerger.diffTree(trees[0], trees[1]);
                                fileutils.mkdirs(rootDir, entry.nu.name, function(dirEntry){
                                    processOps(dirEntry, newOps, done);
                                });
                            });
                        }
                    },
                    function(){
                        callback();
                    });
                });
            });
        }
        
        
        var ops = treeMerger.diffTree(fromTree, toTree);
        processOps(dir, ops, success);
    
    };

    

    var pull = function(options, success, error){

        var dir = options.dir,
            store = options.objectStore,
            username = options.username,
            password = options.password,
            progress = options.progress || function(){},
            callback = success,
            ferror = errutils.fileErrorFunc(error);

        var mkdirs = fileutils.mkdirs,
            mkfile = fileutils.mkfile;

        var fetchProgress;
        if (options.progress){
            var chunker = new ProgressChunker(progress);
            fetchProgress = chunker.getChunk(20, 0.5);
        }
        else{
            fetchProgress = function(){};
        }

        progress({pct: 0, msg: 'Checking for uncommitted changes...'});
        Conditions.checkForUncommittedChanges(dir, store, function(repoConfig){
            var url = repoConfig.url;

            remote = new SmartHttpRemote(store, "origin", url, username, password, error);
        
            var nonFastForward = function(){
                error({type: errutils.PULL_NON_FAST_FORWARD, msg: errutils.PULL_NON_FAST_FORWARD_MSG});
            };

            var upToDate = function(){
                error({type: errutils.PULL_UP_TO_DATE, msg: errutils.PULL_UP_TO_DATE_MSG});
            };

            // get the current branch
            fileutils.readFile(dir, '.git/HEAD', 'Text', function(headStr){
                
                progress({pct: 10, msg: 'Querying remote git server...'});
                // get rid of the initial 'ref: ' plus newline at end
                var headRefName = headStr.substring(5).trim();
                remote.fetchRefs(function(refs){
                    var headSha, branchRef, wantRef;
                    
                    refs.some(function(ref){
                        if (ref.name == headRefName){
                            branchRef = ref;
                            return true;
                        }
                    });

                    if (branchRef){
                         // see if we know about the branch's head commit if so, we're up to date, if not, request from remote
                        store._retrieveRawObject(branchRef.sha, 'ArrayBuffer', upToDate, function(){
                            wantRef = branchRef;
                            // Get the sha from the ref name 
                            store._getHeadForRef(branchRef.name, function(sha){
                                branchRef.localHead = sha;
                                
                                store._getCommitGraph([sha], 32, function(commits, nextLevel){
                                    remote.fetchRef([wantRef], commits, repoConfig.shallow, null, nextLevel, function(objects, packData, common){
                                        // fast forward merge
                                        if (common.indexOf(wantRef.localHead) != -1){
                                            var packSha = packData.subarray(packData.length - 20);
                                            
                                            var packIdxData = PackIndex.writePackIdx(objects, packSha);
                                            
                                            // get a view of the sorted shas
                                            var sortedShas = new Uint8Array(packIdxData, 4 + 4 + (256 * 4), objects.length * 20);
                                            packNameSha = Crypto.SHA1(sortedShas);
                                            
                                            var packName = 'pack-' + packNameSha;
                                            mkdirs(store.dir, '.git/objects', function(objectsDir){
                                                store.objectsDir = objectsDir;
                                                mkfile(objectsDir, 'pack/' + packName + '.pack', packData.buffer);
                                                mkfile(objectsDir, 'pack/' + packName + '.idx', packIdxData);
                                                
                                                var packIdx = new PackIndex(packIdxData);
                                                if (!store.packs){
                                                    store.packs = [];
                                                }
                                                store.packs.push({pack: new Pack(packData, store), idx: packIdx});
                                            
                                                mkfile(store.dir, '.git/' + wantRef.name, wantRef.sha, function(){
                                                    progress({pct: 70, msg: 'Applying fast-forward merge'});
                                                    store._getTreesFromCommits([wantRef.localHead, wantRef.sha], function(trees){
                                                        _updateWorkingTree(dir, store, trees[0], trees[1], function(){
                                                            progress({pct: 99, msg: 'Finishing up'})
                                                            repoConfig.remoteHeads[branchRef.name] = branchRef.sha;
                                                            store.updateLastChange(repoConfig, success);
                                                        });
                                                    });
                                                }); 
                                            });
                                        }
                                        else{
                                            // non-fast-forward merge
                                            nonFastForward();
                                            // var shas = [wantRef.localHead, common[i], wantRef.sha]
                                            // store._getTreesFromCommits(shas, function(trees){
                                            //     treeMerger.mergeTrees(store, trees[0], trees[1], trees[2], function(finalTree){
                                            //         mkfile(store.dir, '.git/' + wantRef.name, sha, done); 
                                            //     }, function(e){errors.push(e);done();});
                                            // });
                                            
                                        }
                                            
                                        
                                    }, nonFastForward, fetchProgress);
                                });
                                                             
                            }, ferror);
                        }); 
                    }
                    else{
                        error({type: errutils.REMOTE_BRANCH_NOT_FOUND, msg: errutils.REMOTE_BRANCH_NOT_FOUND_MSG});
                    }        
                });
            }, ferror);
        }, error);
        
    }
    return pull;
});
define('commands/push',['formats/smart_http_remote', 'formats/pack', 'utils/progress_chunker', 'utils/errors'], function(SmartHttpRemote, Pack, ProgressChunker, errutils){
    var push = function(options, success, error){
        
        var store = options.objectStore,
            username = options.username,
            password = options.password,
            progress = options.progress || function(){};

        var remotePushProgress;
        if (options.progress){
            var chunker = new ProgressChunker(progress);
            remotePushProgress = chunker.getChunk(40, .6);
        }
        else{
            remotePushProgress = function(){};
        }

        store.getConfig(function(config){
            var url = config.url || options.url;

            if (!url){
                error({type: errutils.PUSH_NO_REMOTE, msg: errutils.PUSH_NO_REMOTE_MSG});
                return;
            }

            var remote = new SmartHttpRemote(store, "origin", url, username, password, error);
            progress({pct:0, msg: 'Contacting server...'});
            remote.fetchReceiveRefs(function(refs){
                store._getCommitsForPush(refs, config.remoteHeads, function(commits, ref){
                    progress({pct: 20, msg: 'Building pack...'});
                    Pack.buildPack(commits, store, function(packData){
                        progress({pct: 40, msg: 'Sending pack...'});
                        remote.pushRefs([ref], packData, function(){
                            config.remoteHeads = config.remoteHeads || {};
                            config.remoteHeads[ref.name] = ref.head;
                            config.url = url;
                            store.setConfig(config, success);
                        }, remotePushProgress);
                    });
                }, error);
            });
        });
    }
    return push;
});
define('commands/branch',['utils/file_utils', 'utils/errors'], function(fileutils, errutils){
    
    var branchRegex = new RegExp("^(?!/|.*([/.]\\.|//|@\\{|\\\\))[^\\x00-\\x20 ~^:?*\\[]+$");
    


    var checkBranchName = function(branchName){
        if (branchName && branchName.length && branchName.match(branchRegex)){
            if ((branchName.length < 5 || branchName.lastIndexOf('.lock') != branchName.length - '.lock'.length) &&
                branchName.charAt(branchName.length - 1) != '.' &&
                branchName.charAt(branchName.length - 1) != '/' &&
                branchName.charAt(0) != '.'){
                return true;
            }
        };
        return false
    }

    var branch = function(options, success, error){
        var store = options.objectStore,
            ferror = errutils.fileErrorFunc(error),
            branchName = options.branch;

        if (!checkBranchName(branchName)){
            error({type: errutils.BRANCH_NAME_NOT_VALID, msg: errutils.BRANCH_NAME_NOT_VALID_MSG});
            return;
        }

        var branchAlreadyExists = function(){
            error({type: errutils.BRANCH_ALREADY_EXISTS, msg: errutils.BRANCH_ALREADY_EXISTS_MSG});
        }

        store._getHeadForRef('refs/heads/' + branchName, branchAlreadyExists, function(e){
            if (e.code == FileError.NOT_FOUND_ERR){
                store.getHeadRef(function(refName){
                    store._getHeadForRef(refName, function(sha){
                        store.createNewRef('refs/heads/' + branchName, sha, success);
                    }, ferror);
                });
            }
            else{
                ferror(e);
            }
        });
    }
    return branch;
});
define('commands/checkout',['commands/object2file', 'commands/conditions', 'utils/file_utils', 'utils/errors'], function(object2file, Conditions, fileutils, errutils){
    
    var blowAwayWorkingDir = function(dir, success, error){
        fileutils.ls(dir, function(entries){
            entries.asyncEach(function(entry, done){
                if (entry.isDirectory){
                    if (entry.name == '.git'){
                        done();
                        return;
                    }
                    else{
                        entry.removeRecursively(done, error);
                    }
                }
                else{
                    entry.remove(done, error);
                }
            }, success);
        }, error)
    }

    var checkout = function(options, success, error){
        var dir = options.dir,
            store = options.objectStore,
            branch = options.branch,
            ferror = errutils.fileErrorFunc(error);

        
        store._getHeadForRef('refs/heads/' + branch, function(branchSha){
            store.getHeadSha(function(currentSha){
                if (currentSha != branchSha){
                    Conditions.checkForUncommittedChanges(dir, store, function(config){
                        blowAwayWorkingDir(dir, function(){
                            store._retrieveObject(branchSha, "Commit", function(commit){
                                var treeSha = commit.tree;
                                object2file.expandTree(dir, store, treeSha, function(){
                                    store.setHeadRef('refs/heads/' + branch, function(){
                                        store.updateLastChange(null, success);
                                    });
                                });
                             });
                        }, ferror);
                    }, error);
                }
                else{
                    store.setHeadRef('refs/heads/' + branch, success);
                }
            });
        }, 
        function(e){
            if (e.code == FileError.NOT_FOUND_ERR){
                error({type: errutils.CHECKOUT_BRANCH_NO_EXISTS, msg: CHECKOUT_BRANCH_NO_EXISTS_MSG});
            }
            else{
                ferror(e);
            }
        });
        
    }
    return checkout;
});
// Underscore.js 1.1.3
// (c) 2010 Jeremy Ashkenas, DocumentCloud Inc.
// Underscore is freely distributable under the MIT license.
// Portions of Underscore are inspired or borrowed from Prototype,
// Oliver Steele's Functional, and John Resig's Micro-Templating.
// For all details and documentation:
// http://documentcloud.github.com/underscore
(function(){var p=this,C=p._,m={},j=Array.prototype,n=Object.prototype,i=j.slice,D=j.unshift,E=n.toString,q=n.hasOwnProperty,s=j.forEach,t=j.map,u=j.reduce,v=j.reduceRight,w=j.filter,x=j.every,y=j.some,o=j.indexOf,z=j.lastIndexOf;n=Array.isArray;var F=Object.keys,c=function(a){return new l(a)};if(typeof module!=="undefined"&&module.exports){module.exports=c;c._=c}else p._=c;c.VERSION="1.1.3";var k=c.each=c.forEach=function(a,b,d){if(s&&a.forEach===s)a.forEach(b,d);else if(c.isNumber(a.length))for(var e=
0,f=a.length;e<f;e++){if(b.call(d,a[e],e,a)===m)break}else for(e in a)if(q.call(a,e))if(b.call(d,a[e],e,a)===m)break};c.map=function(a,b,d){if(t&&a.map===t)return a.map(b,d);var e=[];k(a,function(f,g,h){e[e.length]=b.call(d,f,g,h)});return e};c.reduce=c.foldl=c.inject=function(a,b,d,e){var f=d!==void 0;if(u&&a.reduce===u){if(e)b=c.bind(b,e);return f?a.reduce(b,d):a.reduce(b)}k(a,function(g,h,G){d=!f&&h===0?g:b.call(e,d,g,h,G)});return d};c.reduceRight=c.foldr=function(a,b,d,e){if(v&&a.reduceRight===
v){if(e)b=c.bind(b,e);return d!==void 0?a.reduceRight(b,d):a.reduceRight(b)}a=(c.isArray(a)?a.slice():c.toArray(a)).reverse();return c.reduce(a,b,d,e)};c.find=c.detect=function(a,b,d){var e;A(a,function(f,g,h){if(b.call(d,f,g,h)){e=f;return true}});return e};c.filter=c.select=function(a,b,d){if(w&&a.filter===w)return a.filter(b,d);var e=[];k(a,function(f,g,h){if(b.call(d,f,g,h))e[e.length]=f});return e};c.reject=function(a,b,d){var e=[];k(a,function(f,g,h){b.call(d,f,g,h)||(e[e.length]=f)});return e};
c.every=c.all=function(a,b,d){b=b||c.identity;if(x&&a.every===x)return a.every(b,d);var e=true;k(a,function(f,g,h){if(!(e=e&&b.call(d,f,g,h)))return m});return e};var A=c.some=c.any=function(a,b,d){b=b||c.identity;if(y&&a.some===y)return a.some(b,d);var e=false;k(a,function(f,g,h){if(e=b.call(d,f,g,h))return m});return e};c.include=c.contains=function(a,b){if(o&&a.indexOf===o)return a.indexOf(b)!=-1;var d=false;A(a,function(e){if(d=e===b)return true});return d};c.invoke=function(a,b){var d=i.call(arguments,
2);return c.map(a,function(e){return(b?e[b]:e).apply(e,d)})};c.pluck=function(a,b){return c.map(a,function(d){return d[b]})};c.max=function(a,b,d){if(!b&&c.isArray(a))return Math.max.apply(Math,a);var e={computed:-Infinity};k(a,function(f,g,h){g=b?b.call(d,f,g,h):f;g>=e.computed&&(e={value:f,computed:g})});return e.value};c.min=function(a,b,d){if(!b&&c.isArray(a))return Math.min.apply(Math,a);var e={computed:Infinity};k(a,function(f,g,h){g=b?b.call(d,f,g,h):f;g<e.computed&&(e={value:f,computed:g})});
return e.value};c.sortBy=function(a,b,d){return c.pluck(c.map(a,function(e,f,g){return{value:e,criteria:b.call(d,e,f,g)}}).sort(function(e,f){var g=e.criteria,h=f.criteria;return g<h?-1:g>h?1:0}),"value")};c.sortedIndex=function(a,b,d){d=d||c.identity;for(var e=0,f=a.length;e<f;){var g=e+f>>1;d(a[g])<d(b)?e=g+1:f=g}return e};c.toArray=function(a){if(!a)return[];if(a.toArray)return a.toArray();if(c.isArray(a))return a;if(c.isArguments(a))return i.call(a);return c.values(a)};c.size=function(a){return c.toArray(a).length};
c.first=c.head=function(a,b,d){return b&&!d?i.call(a,0,b):a[0]};c.rest=c.tail=function(a,b,d){return i.call(a,c.isUndefined(b)||d?1:b)};c.last=function(a){return a[a.length-1]};c.compact=function(a){return c.filter(a,function(b){return!!b})};c.flatten=function(a){return c.reduce(a,function(b,d){if(c.isArray(d))return b.concat(c.flatten(d));b[b.length]=d;return b},[])};c.without=function(a){var b=i.call(arguments,1);return c.filter(a,function(d){return!c.include(b,d)})};c.uniq=c.unique=function(a,
b){return c.reduce(a,function(d,e,f){if(0==f||(b===true?c.last(d)!=e:!c.include(d,e)))d[d.length]=e;return d},[])};c.intersect=function(a){var b=i.call(arguments,1);return c.filter(c.uniq(a),function(d){return c.every(b,function(e){return c.indexOf(e,d)>=0})})};c.zip=function(){for(var a=i.call(arguments),b=c.max(c.pluck(a,"length")),d=Array(b),e=0;e<b;e++)d[e]=c.pluck(a,""+e);return d};c.indexOf=function(a,b){if(o&&a.indexOf===o)return a.indexOf(b);for(var d=0,e=a.length;d<e;d++)if(a[d]===b)return d;
return-1};c.lastIndexOf=function(a,b){if(z&&a.lastIndexOf===z)return a.lastIndexOf(b);for(var d=a.length;d--;)if(a[d]===b)return d;return-1};c.range=function(a,b,d){var e=i.call(arguments),f=e.length<=1;a=f?0:e[0];b=f?e[0]:e[1];d=e[2]||1;e=Math.max(Math.ceil((b-a)/d),0);f=0;for(var g=Array(e);f<e;){g[f++]=a;a+=d}return g};c.bind=function(a,b){var d=i.call(arguments,2);return function(){return a.apply(b||{},d.concat(i.call(arguments)))}};c.bindAll=function(a){var b=i.call(arguments,1);if(b.length==
0)b=c.functions(a);k(b,function(d){a[d]=c.bind(a[d],a)});return a};c.memoize=function(a,b){var d={};b=b||c.identity;return function(){var e=b.apply(this,arguments);return e in d?d[e]:d[e]=a.apply(this,arguments)}};c.delay=function(a,b){var d=i.call(arguments,2);return setTimeout(function(){return a.apply(a,d)},b)};c.defer=function(a){return c.delay.apply(c,[a,1].concat(i.call(arguments,1)))};var B=function(a,b,d){var e;return function(){var f=this,g=arguments,h=function(){e=null;a.apply(f,g)};d&&
clearTimeout(e);if(d||!e)e=setTimeout(h,b)}};c.throttle=function(a,b){return B(a,b,false)};c.debounce=function(a,b){return B(a,b,true)};c.wrap=function(a,b){return function(){var d=[a].concat(i.call(arguments));return b.apply(b,d)}};c.compose=function(){var a=i.call(arguments);return function(){for(var b=i.call(arguments),d=a.length-1;d>=0;d--)b=[a[d].apply(this,b)];return b[0]}};c.keys=F||function(a){if(c.isArray(a))return c.range(0,a.length);var b=[],d;for(d in a)if(q.call(a,d))b[b.length]=d;return b};
c.values=function(a){return c.map(a,c.identity)};c.functions=c.methods=function(a){return c.filter(c.keys(a),function(b){return c.isFunction(a[b])}).sort()};c.extend=function(a){k(i.call(arguments,1),function(b){for(var d in b)a[d]=b[d]});return a};c.clone=function(a){return c.isArray(a)?a.slice():c.extend({},a)};c.tap=function(a,b){b(a);return a};c.isEqual=function(a,b){if(a===b)return true;var d=typeof a;if(d!=typeof b)return false;if(a==b)return true;if(!a&&b||a&&!b)return false;if(a.isEqual)return a.isEqual(b);
if(c.isDate(a)&&c.isDate(b))return a.getTime()===b.getTime();if(c.isNaN(a)&&c.isNaN(b))return false;if(c.isRegExp(a)&&c.isRegExp(b))return a.source===b.source&&a.global===b.global&&a.ignoreCase===b.ignoreCase&&a.multiline===b.multiline;if(d!=="object")return false;if(a.length&&a.length!==b.length)return false;d=c.keys(a);var e=c.keys(b);if(d.length!=e.length)return false;for(var f in a)if(!(f in b)||!c.isEqual(a[f],b[f]))return false;return true};c.isEmpty=function(a){if(c.isArray(a)||c.isString(a))return a.length===
0;for(var b in a)if(q.call(a,b))return false;return true};c.isElement=function(a){return!!(a&&a.nodeType==1)};c.isArray=n||function(a){return!!(a&&a.concat&&a.unshift&&!a.callee)};c.isArguments=function(a){return!!(a&&a.callee)};c.isFunction=function(a){return!!(a&&a.constructor&&a.call&&a.apply)};c.isString=function(a){return!!(a===""||a&&a.charCodeAt&&a.substr)};c.isNumber=function(a){return!!(a===0||a&&a.toExponential&&a.toFixed)};c.isNaN=function(a){return E.call(a)==="[object Number]"&&isNaN(a)};
c.isBoolean=function(a){return a===true||a===false};c.isDate=function(a){return!!(a&&a.getTimezoneOffset&&a.setUTCFullYear)};c.isRegExp=function(a){return!!(a&&a.test&&a.exec&&(a.ignoreCase||a.ignoreCase===false))};c.isNull=function(a){return a===null};c.isUndefined=function(a){return a===void 0};c.noConflict=function(){p._=C;return this};c.identity=function(a){return a};c.times=function(a,b,d){for(var e=0;e<a;e++)b.call(d,e)};c.mixin=function(a){k(c.functions(a),function(b){H(b,c[b]=a[b])})};var I=
0;c.uniqueId=function(a){var b=I++;return a?a+b:b};c.templateSettings={evaluate:/<%([\s\S]+?)%>/g,interpolate:/<%=([\s\S]+?)%>/g};c.template=function(a,b){var d=c.templateSettings;d="var __p=[],print=function(){__p.push.apply(__p,arguments);};with(obj||{}){__p.push('"+a.replace(/\\/g,"\\\\").replace(/'/g,"\\'").replace(d.interpolate,function(e,f){return"',"+f.replace(/\\'/g,"'")+",'"}).replace(d.evaluate||null,function(e,f){return"');"+f.replace(/\\'/g,"'").replace(/[\r\n\t]/g," ")+"__p.push('"}).replace(/\r/g,
"\\r").replace(/\n/g,"\\n").replace(/\t/g,"\\t")+"');}return __p.join('');";d=new Function("obj",d);return b?d(b):d};var l=function(a){this._wrapped=a};c.prototype=l.prototype;var r=function(a,b){return b?c(a).chain():a},H=function(a,b){l.prototype[a]=function(){var d=i.call(arguments);D.call(d,this._wrapped);return r(b.apply(c,d),this._chain)}};c.mixin(c);k(["pop","push","reverse","shift","sort","splice","unshift"],function(a){var b=j[a];l.prototype[a]=function(){b.apply(this._wrapped,arguments);
return r(this._wrapped,this._chain)}});k(["concat","join","slice"],function(a){var b=j[a];l.prototype[a]=function(){return r(b.apply(this._wrapped,arguments),this._chain)}});l.prototype.chain=function(){this._chain=true;return this};l.prototype.value=function(){return this._wrapped}})();

define("thirdparty/underscore-min", function(){});

define('objectstore/objects',['utils/misc_utils', 'thirdparty/underscore-min'], function(utils) {
    var map = {
        "commit": 1,
        "tree": 2,
        "blob": 3
    };
    GitObjects = {
        CONSTRUCTOR_NAMES: {
            "blob": "Blob",
            "tree": "Tree",
            "commit": "Commit",
            "comm": "Commit",
            "tag": "Tag",
            "tag ": "Tag"
        },

        make: function(sha, type, content) {
            var constructor = Git.objects[this.CONSTRUCTOR_NAMES[type]]
            if (constructor) {
                return new constructor(sha, content)
            } else {
                throw ("no constructor for " + type)
            }
        },

        Blob: function(sha, data) {
            this.type = "blob"
            this.sha = sha
            this.data = data
            this.toString = function() {
                return data
            }
        },

        Tree: function(sha, buf) {
            var data = new Uint8Array(buf);
            var treeEntries = [];

            var idx = 0;
            while (idx < data.length) {
                var entryStart = idx;
                while (data[idx] != 0) {
                    if (idx >= data.length) {
                        throw Error("object is not a tree");
                    }
                    idx++;
                }
                var isBlob = data[entryStart] == 49; // '1' character
                var nameStr = utils.bytesToString(data.subarray(entryStart + (isBlob ? 7 : 6), idx++));
                nameStr = decodeURIComponent(escape(nameStr));
                var entry = {
                    isBlob: isBlob,
                    name: nameStr,
                    sha: data.subarray(idx, idx + 20)
                };
                treeEntries.push(entry);
                idx += 20;
            }
            this.entries = treeEntries;

            var sorter = function(a, b) {
                var nameA = a.name,
                    nameB = b.name;
                if (nameA < nameB) //sort string ascending
                    return -1;
                if (nameA > nameB)
                    return 1;
                return 0;
            }
            this.sortEntries = function() {
                this.entries.sort(sorter);
            }
        },

        Commit: function(sha, data) {
            this.type = "commit"
            this.sha = sha
            this.data = data

            var lines = data.split("\n")
            this.tree = lines[0].split(" ")[1]
            var i = 1
            this.parents = []
            while (lines[i].slice(0, 6) === "parent") {
                this.parents.push(lines[i].split(" ")[1])
                i += 1
            }

            var parseAuthor = function(line) {
                var match = /^(.*) <(.*)> (\d+) (\+|\-)\d\d\d\d$/.exec(line)
                var result = {}

                result.name = match[1]
                result.email = match[2]
                result.timestamp = parseInt(match[3])
                result.date = new Date(result.timestamp * 1000)
                return result
            }

            var authorLine = lines[i].replace("author ", "")
            this.author = parseAuthor(authorLine)

            var committerLine = lines[i + 1].replace("committer ", "")
            this.committer = parseAuthor(committerLine)

            if (lines[i + 2].split(" ")[0] == "encoding") {
                this.encoding = lines[i + 2].split(" ")[1]
            }
            this.message = _(lines.slice(i + 2, lines.length)).select(function(line) {
                return line !== ""
            }).join("\n")

            this.toString = function() {
                var str = "commit " + sha + "\n"
                str += "Author: " + this.author.name + " <" + this.author.email + ">\n"
                str += "Date:   " + this.author.date + "\n"
                str += "\n"
                str += this.message
                return str
            }
        },

        Tag: function(sha, data) {
            this.type = "tag"
            this.sha = sha
            this.data = data
        },

        RawLooseObject: function(buf) {

            var header, i, data;
            var funcName;
            if (buf instanceof ArrayBuffer) {
                var data = new Uint8Array(buf);
                var headChars = [];
                i = 0;
                for (; i < data.length; i++) {
                    if (data[i] != 0)
                        headChars.push(String.fromCharCode(data[i]));
                    else
                        break;
                }
                header = headChars.join('');
                funcName = 'subarray';
            } else {
                data = buf;
                i = buf.indexOf('\0');
                header = buf.substring(0, i);
                funcName = 'substring';
            }
            var parts = header.split(' ');
            this.type = map[parts[0]];
            this.size = parseInt(parts[1]);
            // move past nul terminator but keep zlib header
            this.data = data[funcName](i + 1);
        }
    }
    return GitObjects;
});
define('objectstore/file_repo',['formats/pack', 'formats/pack_index', 'objectstore/objects', 'utils/misc_utils', 'utils/file_utils', 'utils/errors'], function(Pack, PackIndex, GitObjects, utils, fileutils, errutils){

	String.prototype.endsWith = function(suffix){
    	return this.lastIndexOf(suffix) == (this.length - suffix.length);
	}

	var FileObjectStore = function(rootDir) {
	 	this.dir = rootDir;
	 	this.packs = [];
	}

	FileObjectStore.prototype = {
		haveRefs: function(){
			return [];
		},
		load : function(callback){
			var rootDir = this.dir;
			var thiz = this;
			var fe = this.fileError;

			rootDir.getDirectory('.git/objects', {create:true}, function(objectsDir){
				thiz.objectsDir = objectsDir;
				objectsDir.getDirectory('pack', {create:true}, function(packDir){
					var packEntries = [];
					var reader = packDir.createReader();
					var readEntries = function(){
						reader.readEntries(function(entries){
						    if (entries.length){
								for (var i = 0; i < entries.length; i++){
									if (entries[i].name.endsWith('.pack'))
										packEntries.push(entries[i]);
								}
								readEntries();
							}
							else{
								if (packEntries.length){
									var counter = {x : 0};
									packEntries.forEach(function(entry, i){
										fileutils.readFile(packDir, entry.name, "ArrayBuffer", function(packData){
											var nameRoot = entry.name.substring(0, entry.name.lastIndexOf('.pack'));
											fileutils.readFile(packDir, nameRoot + '.idx', 'ArrayBuffer', function(idxData){
												thiz.packs.push({pack: new Pack(packData, thiz), idx: new PackIndex(idxData)});
												counter.x += 1;
												if (counter.x == packEntries.length){
													callback();
												}
											}, fe);
										}, fe);
									});
								}
								else{
									callback();
								}
							}
						}, fe);
					}
					readEntries();
				}, fe);
			}, fe);
		},
		loadWith : function(objectsDir, packs){
			this.objectsDir = objectsDir;
			this.packs = packs;
		},
		_getCommitGraph : function(headShas, limit, callback){
			var commits = [];
			var thiz = this;
			var seen = {};
			
			var walkLevel = function(shas, callback){
				var nextLevel = [];
				shas.asyncEach(function(sha, callback){
					if (seen[sha]){
						callback();
						return;
					}
					else{
						seen[sha] = true;
					}
					// it's possible for this to fail since we support shallow clones
					thiz._retrieveObject(sha, 'Commit', function(obj){
						nextLevel = nextLevel.concat(obj.parents);
						var i = commits.length - 1
						for (; i >= 0; i--){
							if (commits[i].author.timestamp > obj.author.timestamp){
								commits.splice(i + 1, 0, obj);
								break;
							}
						}
						if (i < 0){
							commits.unshift(obj);
						}
						callback();
					}, callback);
				}, function(){
					if (commits.length >= limit || nextLevel.length == 0){
						/*var shas = [];
						for (var i = 0; i < commits.length; i++){
							shas.push(commit.sha);
						}*/
						callback(commits, nextLevel);
					}
					else{
						walkLevel(nextLevel, callback);
					}
				});
			}
			walkLevel(headShas, callback);
		},
		_getCommitsForPush : function(baseRefs, remoteHeads, callback, error){
			
			// special case of empty remote. 
			if (baseRefs.length == 1 && baseRefs[0].sha == "0000000000000000000000000000000000000000"){
				baseRefs[0].name = 'refs/heads/master';
			}

			var self = this;
			// find the remote branch corresponding to our local one.
			var remoteRef, headRef;
			this.getHeadRef(function(refName){
				headRef = refName;
				for (var i = 0; i < baseRefs.length; i++){
					if (baseRefs[i].name == headRef){
						remoteRef = baseRefs[i];
						break;
					}
				}

				// Didn't find a remote branch for our local so base the commits we 
				// need to push on what we already know about the remote
				var newBranch = !remoteRef;
				var remoteShas = {};
				if (newBranch){
					remoteRef = {
						sha: "0000000000000000000000000000000000000000",
						name: headRef
					}
					for (var remoteHead in remoteHeads){
						var remoteSha = remoteHeads[remoteHead];
						remoteShas[remoteSha] = true;
					}
				}
				
				var nonFastForward = function(){
					error({type: errutils.PUSH_NON_FAST_FORWARD, msg: errutils.PUSH_NON_FAST_FORWARD_MSG});
				}

				var checkRemoteHead = function(success){
					// See if the remote head exists in our repo.  
					if (remoteRef.sha != "0000000000000000000000000000000000000000"){
						self._retrieveObject(remoteRef.sha, 'Commit', success, nonFastForward);
					}	
					else{
						success();
					}
				} 


				checkRemoteHead(function(){
					self._getHeadForRef(headRef, function(sha){

						if (sha == remoteRef.sha){
							error({type: errutils.PUSH_NO_CHANGES, msg: errutils.PUSH_NO_CHANGES_MSG});
							return;
						}

						remoteRef.head = sha;
						
						// case of new branch with no new commits
						if (newBranch && remoteShas[sha]){
							callback([], remoteRef);
							return;
						}

						// we don't support local merge commits so finding commits to push should be a 
						// matter of looking at a non-branching list of ancestors of the current commit.
						var commits = [];
						var getNextCommit = function(sha){
							self._retrieveObject(sha, 'Commit', function(commit, rawObj){
								commits.push({commit: commit, raw: rawObj});
								if (commit.parents.length > 1){
									// this would mean a local merge commit. It shouldn't happen, 
									// therefore we've strayed into somewhere we shouldn't be.
									nonFastForward();
								}
								else if (commit.parents.length == 0 || commit.parents[0] == remoteRef.sha || remoteShas[commit.parents[0]]){
									callback(commits, remoteRef);
								}
								else{
									getNextCommit(commit.parents[0]);
								}
							}, nonFastForward);
						}
						getNextCommit(sha);
					},
					function(e){
						// No commits yet
						if (e.code == FileError.NOT_FOUND_ERR){
							error({type: errutils.COMMIT_NO_CHANGES, msg: errutils.COMMIT_NO_CHANGES_MSG});
						}
						else{
							self.fileError(e);
						}
					});
				});

			});
			
		},
		createNewRef : function(refName, sha, success){
			fileutils.mkfile(this.dir, '.git/' + refName, sha + '\n', success, this.fileError);
		},
		setHeadRef : function(refName, callback){
			fileutils.mkfile(this.dir, '.git/HEAD', 'ref: ' + refName + '\n', callback, this.fileError);
		},
		getHeadRef : function(callback){
			fileutils.readFile(this.dir, '.git/HEAD', 'Text', function(headStr){
				// get rid of the initial 'ref: ' plus newline at end
            	var headRefName = headStr.substring(5).trim();
            	callback(headRefName);
			},this.fileError);
		},
		getHeadSha : function(callback){
			var self = this;
			this.getHeadRef(function(ref){
				self._getHeadForRef(ref, callback, self.fileError);
			});
		},
		getAllHeads : function(callback){
			var fe = this.fileError;
			this.dir.getDirectory('.git/refs/heads', {create: false}, function(de){
				fileutils.ls(de, function(entries){
					var branches = [];
					entries.forEach(function(entry){
						branches.push(entry.name);
					});
					callback(branches);
				}, fe);
			}, 
			function(e){
				if (e.code == FileError.NOT_FOUND_ERR){
					callback([]);
				}
				else{
					fe(e);
				}
			});
		},
		_getHeadForRef : function(name, callback, onerror){
			fileutils.readFile(this.dir, '.git/' + name, 'Text', function(data){callback(data.substring(0, 40));}, onerror) ;	
		},
		
		_findLooseObject : function(sha, success, error){
			this.objectsDir.getFile(sha.substring(0,2) + '/' + sha.substring(2), {create:false}, function(fileEntry){
				success(fileEntry);
			},
			function(e){
				error(e);
			});
		},
		_findPackedObject : function(sha, success, error){
			for (var i = 0; i < this.packs.length; i++){
				var offset = this.packs[i].idx.getObjectOffset(sha);
				if (offset != -1){
					success(offset, this.packs[i].pack);
					return;
				}
			}
			error();
		},
		_retrieveRawObject : function(sha, dataType, callback, error){
		     var shaBytes;
		     if (sha instanceof Uint8Array){
		     	shaBytes = sha;
		     	sha = utils.convertBytesToSha(shaBytes);
		     }
		     else{
		     	shaBytes = utils.convertShaToBytes(sha);
		     }
		     
			 
			 
			 var thiz = this;
			 this._findLooseObject(sha, function(fileEntry){
			 	fileutils.readFileEntry(fileEntry, 'ArrayBuffer', function(buf){
			 		var inflated = utils.inflate(new Uint8Array(buf));
			 		if (dataType == 'Raw' || dataType == 'ArrayBuffer'){
			 			var buffer = utils.trimBuffer(inflated);
			 			callback(new GitObjects.RawLooseObject(buffer));
			 		}
			 		else{
			 			fileutils.readBlob(new Blob([inflated]), dataType, function(data){
							callback(new GitObjects.RawLooseObject(data));
						});
			 		}
			 	});
			 }, function(e){
			 		thiz._findPackedObject(shaBytes, function(offset, pack){
			 			dataType = dataType == 'Raw' ? 'ArrayBuffer' : dataType;
			 			pack.matchAndExpandObjectAtOffset(offset, dataType, function(object){
							callback(object);
						});
			 	}, function(){
			 	    if (error) error.call(thiz);
			 	    else throw(Error("Can't find object with SHA " + sha));
			 	});
			 });
		},
		_retrieveBlobsAsStrings : function(shas, callback){
			var blobs =new Array(shas.length),
				self = this;
				
			shas.asyncEach(function(sha, done, i){
				self._retrieveRawObject(sha, 'Text', function(object){
					blobs[i] = new GitObjects.Blob(sha, object.data);
					done();
				 });
			},
			function(){
				callback(blobs);
			});
		},
		_retrieveObjectList : function(shas, objType, callback){
			var objects = new Array(shas.length),
				self = this;
				
			shas.asyncEach(function(sha, done, i){
				self._retrieveObject(sha, objType, function(obj){
					objects[i] = obj;
					done();
				});
			},
			function(){
				callback(objects);
			});
		},
		_retrieveObject : function(sha, objType, callback, error){
			 var dataType = "ArrayBuffer";
			 if (objType == "Commit"){
			 	dataType = "Text";
			 }
			 
			 this._retrieveRawObject(sha, dataType, function(object){
			 	callback(new GitObjects[objType](sha, object.data), object);
			 }, error);
		},

		init : function(success, error){
			var root = this.dir;
			var self = this;
			this.error = error;
			this.fileError = errutils.fileErrorFunc(error);
			
			root.getDirectory('.git', {create:false}, function(gitDir){
				self.load(success);
			},
			function(e){
				if (e.code == FileError.NOT_FOUND_ERR){
					self._init(success);
				}
				else{
					self.fileError(e);
				}
			});
		},

		_init : function(success){
			var root = this.dir;
			var self = this;
			fileutils.mkdirs(root, '.git/objects', function(objectsDir){
				self.objectsDir = objectsDir;
				fileutils.mkfile(root, '.git/HEAD', 'ref: refs/heads/master\n', success, self.fileError);
			}, this.fileError);

		},
		
		_getTreesFromCommits : function(shas, callback){
			var trees = [],
			    shaIndex = 0,
				self = this;
			
			var fillTrees = function(){
				self._getTreeFromCommitSha(shas[shaIndex++], function(tree){
					trees.push(tree);
					if (shaIndex >= shas.length){
						callback(trees);
					}
					else{
						fillTrees();
					}
				});
			}
			fillTrees();
		},
		_getTreeFromCommitSha : function(sha, callback){
			var self = this;
			this._retrieveObject(sha, 'Commit', function(commit){
				self._retrieveObject(commit.tree, 'Tree', callback);
			});
		},
		writeRawObject : function(type, content, callback){
			var bb = [];//new BlobBuilder();
			var size = content.byteLength || content.length || content.size || 0;
			var header = type + ' ' + String(size) ;
			
			//var store = header + content;
			
			bb.push(header);
			bb.push(new Uint8Array([0]));
			bb.push(content);
			var thiz = this;
			var fr = new FileReader();
			fr.onloadend = function(e){
				var buf = fr.result;
				var store = new Uint8Array(buf);
				var digest = Crypto.SHA1(store);
				thiz._findPackedObject(utils.convertShaToBytes(digest), function(){callback(digest);}, function(){
					thiz._storeInFile(digest, store, callback);
				});
			}
			
			fr.readAsArrayBuffer(new Blob(bb));   
		},
		
		_storeInFile : function(digest, store, callback){
			var subDirName = digest.substr(0,2); 	
			var objectFileName = digest.substr(2);
			
			this.objectsDir.getDirectory(subDirName, {create:true}, function(dirEntry){
				dirEntry.getFile(objectFileName, {create:true}, function(fileEntry){
					fileEntry.file(function(file){
						 if(!file.size){
						 	var content = utils.deflate(store);
						 	fileEntry.createWriter(function(fileWriter){
						 		fileWriter.write(new Blob([content]));;
						 		callback(digest);
						 	}, utils.errorHandler);
						 }
						 else{
						 	callback(digest);
						 }
					}, utils.errorHandler);
				
				}, utils.errorHandler);
				
			}, utils.errorHandler);
		},

		_writeTree : function(treeEntries, success){
			var bb = [];//new BlobBuilder();
			for (var i = 0; i < treeEntries.length; i++){
				bb.push((treeEntries[i].isBlob ? '100644 ' : '40000 ') + treeEntries[i].name);
				bb.push(new Uint8Array([0]));
				bb.push(treeEntries[i].sha);
			}
			this.writeRawObject('tree', new Blob(bb), function(sha){
				success(sha);
			});
		},

		getConfig : function(success){
			var fe = this.fileError;

			fileutils.readFile(this.dir, '.git/config.json', 'Text', function(configStr){
				success(JSON.parse(configStr));
			}, function(e){
				if (e.code == FileError.NOT_FOUND_ERR){
					success({});
				}
				else{
					fe(e);
				}
			});
		},
		setConfig : function(config, success){
			var configStr = JSON.stringify(config);
			fileutils.mkfile(this.dir, '.git/config.json', configStr, success, this.fileError);
		},

		updateLastChange : function(config, success){
			var dir = this.dir,
				setConfig = this.setConfig.bind(this);
				fe = this.fileError;

			var doUpdate = function(config){
				config.time = new Date();
				setConfig(config, success);
			}
			if (config){
				doUpdate(config);
			}
			else{
				this.getConfig(doUpdate);
			}
		}
		
	}

	return FileObjectStore;
});


/*

This is a Javascript implementation of the C implementation of the CRC-32
algorithm available at http://www.w3.org/TR/PNG-CRCAppendix.html

Usage License at
http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231

Copyright (C) W3C

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Permission to copy, modify, and distribute this software and its
documentation, with or without modification, for any purpose and without
fee or royalty is hereby granted, provided that you include the
following on ALL copies of the software and documentation or portions
thereof, including modifications:

1. The full text of this NOTICE in a location viewable to users of
the redistributed or derivative work.
2. Any pre-existing intellectual property disclaimers, notices, or
terms and conditions. If none exist, the W3C Software Short Notice
should be included (hypertext is preferred, text is permitted)
within the body of any redistributed or derivative code.
3. Notice of any changes or modifications to the files,
including the date changes were made. (We recommend you provide
URIs to the location from which the code is derived.)

THIS SOFTWARE AND DOCUMENTATION IS PROVIDED "AS IS," AND
COPYRIGHT HOLDERS MAKE NO REPRESENTATIONS OR WARRANTIES,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO, WARRANTIES OF
MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT
THE USE OF THE SOFTWARE OR DOCUMENTATION WILL NOT INFRINGE ANY
THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.

COPYRIGHT HOLDERS WILL NOT BE LIABLE FOR ANY DIRECT, INDIRECT,
SPECIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF ANY USE OF THE
SOFTWARE OR DOCUMENTATION.

The name and trademarks of copyright holders may NOT be used in
advertising or publicity pertaining to the software without
specific, written prior permission. Title to copyright in this
software and any associated documentation will at all times
remain with copyright holders.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

*/

var crc32 = {
    table: [
        0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
             0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
             0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
             0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
             0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
             0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
             0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
             0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
             0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
             0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
             0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
             0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
             0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
             0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
             0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
             0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
             0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
             0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
             0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
             0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
             0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
             0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
             0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
             0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
             0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
             0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
             0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
             0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
             0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
             0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
             0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
             0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
    ],

    crc: function(data)
    {
        var crc = 0xffffffff;

        for(var i = 0; i < data.length; i++) {
            var b = data[i];
            crc = (crc >>> 8) ^ this.table[(crc ^ b) & 0xff];
            //crc = this.table[(crc ^ data[i]) & 0xff] ^ (crc >> 8);
        }

        crc = crc ^ 0xffffffff;
        return crc;
    },
};
define("thirdparty/crc32", function(){});

GitLiteWorkerMessages = {
    PROGRESS : 0,
    FINISHED: 1,
    RETRIEVE_OBJECT: 2,
    START: 4,
    OBJECT_RETRIEVED: 5,

    API_CALL_CLONE: 6,
    API_CALL_COMMIT: 7,
    API_CALL_PULL: 8,
    API_CALL_PUSH: 9,
    API_CALL_CHECKOUT: 12,
    API_CALL_BRANCH: 14,
    API_CALL_UNCOMMITTED: 15,
    API_CALL_CURRENT_BRANCH: 16, 
    API_CALL_LOCAL_BRANCHES: 17,
    API_CALL_REMOTE_BRANCHES: 18,

    SUCCESS: 10,
    ERROR: 11
};
define("workers/worker_messages", function(){});


define('api',['commands/clone', 'commands/commit', 'commands/init', 'commands/pull', 'commands/push', 'commands/branch', 'commands/checkout', 'commands/conditions', 'objectstore/file_repo', 'formats/smart_http_remote', 'utils/errors', 'thirdparty/2.2.0-sha1', 'thirdparty/crc32', 'thirdparty/deflate.min', 'thirdparty/inflate.min', "workers/worker_messages"], function(clone, commit, init, pull, push, branch, checkout, Conditions, FileObjectStore, SmartHttpRemote, errutils){
    
    /** @exports GitApi */
    var api = {

        /** @desc Indicates an unexpected error in the HTML5 file system. */
        FILE_IO_ERROR: errutils.FILE_IO_ERROR,
        /** @desc Indicates an unexpected ajax error when trying to make a request */
        AJAX_ERROR: errutils.AJAX_ERROR, 
        /** @desc trying to clone into a non-empty directory */
        CLONE_DIR_NOT_EMPTY: errutils.CLONE_DIR_NOT_EMPTY,
        /** @desc Trying to clone into directory that contains a .git directory that already contains objects */
        CLONE_GIT_DIR_IN_USE: errutils.CLONE_GIT_DIR_IN_USE,
        /** @desc No branch found with the name given.  */
        REMOTE_BRANCH_NOT_FOUND: errutils.REMOTE_BRANCH_NOT_FOUND,
        /** @desc A pull was attempted that would require a non-fast-forward. The API only supports fast forward merging at the moment. */
        PULL_NON_FAST_FORWARD: errutils.PULL_NON_FAST_FORWARD,
        /** @desc A pull was attempted but the local git repo is up to date */
        PULL_UP_TO_DATE: errutils.PULL_UP_TO_DATE,
        /** @desc A commit was attempted but the local git repo has no new changes to commit */
        COMMIT_NO_CHANGES: errutils.COMMIT_NO_CHANGES,
        /** @desc A push was attempted but the remote repo is up to date. */
        PUSH_NO_CHANGES: errutils.PUSH_NO_CHANGES,
        /** @desc A push was attempted but the remote has new commits that the local repo doesn't know about. 
         * You would normally do a pull and merge remote changes first. Unfortunately, this isn't possible with this API. 
         * As a workaround, you could create and checkout a new branch and then do a push. */
        PUSH_NON_FAST_FORWARD: errutils.PUSH_NON_FAST_FORWARD,
        /** @desc Indicates an unexpected problem retrieving objects */
        OBJECT_STORE_CORRUPTED: errutils.OBJECT_STORE_CORRUPTED,
        /** @desc A pull was attempted with uncommitted changed in the working copy */
        UNCOMMITTED_CHANGES: errutils.UNCOMMITTED_CHANGES,
        /** @desc 401 when attempting to make a request. */
        HTTP_AUTH_ERROR: errutils.HTTP_AUTH_ERROR,

        /** @desc The branch doesn't follow valid git branch naming rules. */
        BRANCH_NAME_NOT_VALID: errutils.BRANCH_NAME_NOT_VALID,
        /** @desc Trying to push a repo without a valid remote. 
         * This can happen if it's a first push to blank repo and a url wasn't specified as one of the options. */
        PUSH_NO_REMOTE: errutils.PUSH_NO_REMOTE,
        
        /**
         * Clones a remote git repo into a local HTML5 DirectoryEntry. It only requests a single branch. This will either
         * be the branch specified or the HEAD at specified url. You can also specify the depth of the clone. It's recommended
         * that a depth of 1 always be given since the api does not currently give a way 
         * to access the commit history of a repo.  
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry to clone the repo into
         * @param {String} [options.branch=HEAD] the name of the remote branch to clone.
         * @param {String} options.url the url of the repo to clone from
         * @param {Number} [options.depth] the depth of the clone. Equivalent to the --depth option from git-clone
         * @param {String} [options.username] User name to authenticate with if the repo supports basic auth
         * @param {String} [options.password] password to authenticate with if the repo supports basic auth
         * @param {progressCallback} [options.progress] callback that gets notified of progress events.
         * @param {successCallback} success callback that gets notified after the clone is completed successfully
         * @param {errorCallback} [error] callback that gets notified if there is an error
         */
        clone : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                
                clone({
                        dir: options.dir, 
                        branch: options.branch, 
                        objectStore: objectStore, 
                        url: options.url, 
                        depth: options.depth, 
                        progress: options.progress,
                        username: options.username,
                        password: options.password
                    }, 
                    success, error);

            }, error);
        },
        /**
         * Does a pull from the url the local repo was cloned from. Will only succeed for fast-forward pulls.
         * If a merge is required, it calls the error callback 
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo to pull updates into
         * @param {String} [options.username] User name to authenticate with if the repo supports basic auth
         * @param {String} [options.password] password to authenticate with if the repo supports basic auth
         * @param {progressCallback} [options.progress] callback that gets notified of progress events.
         * @param {successCallback} success callback that gets notified after the pull is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error
         */
        pull : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                
                pull({
                        dir: options.dir, 
                        objectStore: objectStore,
                        username: options.username,
                        password: options.password,
                        progress: options.progress
                    }, 
                    success, error);

            }, error);
        },
        /**
         * Looks for changes in the working directory since the last commit and adds them to the local git repo history. Some caveats
         *  
         *  <ul>
         *  <li>This is does an implicit "git add" of all changes including previously untracked files.</li>
         *  <li>A Tree created by this command will only have two file modes: 40000 for folders (subtrees) and 100644 for files (blobs).</li>
         *  <li>Ignores any rules in .gitignore</li>
         *  </ul>
         *
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry to look for changes and commit them to the .git subdirectory in the same driectory
         * @param {String} options.name The name that will appear in the commit log as the name of the author and committer. 
         * @param {String} options.email The email that will appear in the commit log as the email of the author and committer.
         * @param {String} options.commitMsg The message that will appear in the commit log
         * @param {successCallback} success callback that gets notified after the commit is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error
         * 
         */
        commit : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                
                commit({
                            dir: options.dir, 
                            username: options.name, 
                            email: options.email, 
                            commitMsg: options.commitMsg, 
                            objectStore: objectStore
                        }, success, error);
            }, error);
        },
        /**
         * Pushes local commits to a remote repo. This is usually the remote repo the local repo was cloned from. It can also be 
         * the initial push to a blank repo.
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry to push changes from
         * @param {String} [options.url] the remote url to push changes to. This defaults to the url the repo was cloned from. 
         * @param {String} [options.username] User name to authenticate with if the repo supports basic auth
         * @param {String} [options.password] password to authenticate with if the repo supports basic auth
         * @param {progressCallback} [options.progress] callback that gets notified of progress events.
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error
         */
        push : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                push({
                        objectStore: objectStore, 
                        dir: options.dir, 
                        url: options.url,
                        username: options.username,
                        password: options.password,
                        progress: options.progress
                    }, 
                    success, error);
            }, error);
        },
        /**
         * Creates a local branch. You will need to call the checkout api command to check it out. 
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo
         * @param {String} options.branch Name of the branch to create
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error
         * 
         */
        branch: function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                branch({
                    objectStore: objectStore,
                    dir: options.dir,
                    branch: options.branch
                }, success, error);
            }, error);

        },
        /**
         * Checks out a local branch. 
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo
         * @param {String} options.branch Name of the branch to checkout
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error 
         */
        checkout: function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                checkout({
                    objectStore: objectStore,
                    dir: options.dir,
                    branch: options.branch
                }, success, error);
            }, error);
        },

        /**
         * Looks in the working directory for uncommitted changes. This is faster than attempting a 
         * commit and having it fail.
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error  
         */
        checkForUncommittedChanges: function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                Conditions.checkForUncommittedChanges(options.dir, objectStore, success, error);
            }, error);
        },
        /**
         * Retrieves the name of the currently checked out local branch . 
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error  
         */
        getCurrentBranch : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                objectStore.getHeadRef(function(ref){
                    success(ref.substring('refs/heads/'.length));
                });
            }, error);
        },
        /**
         * Gets a list of all local branches.
         * 
         * @param {Object} options 
         * @param {DirectoryEntry} options.dir an HTML5 DirectoryEntry that contains a local git repo
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error  
         */
        getLocalBranches : function(options, success, error){
            var objectStore = new FileObjectStore(options.dir);
            objectStore.init(function(){
                objectStore.getAllHeads(success);
            }, error);
        },
        /**
         * Gets a list of all remote branches. 
         * 
         * @param {Object} options 
         * @param {String} options.url url of a remote git repo
         * @param {String} [options.username] User name to authenticate with if the repo supports basic auth
         * @param {String} [options.password] password to authenticate with if the repo supports basic auth
         * @param {successCallback} success callback that gets notified after the push is completed successfully.
         * @param {errorCallback} [error] callback that gets notified if there is an error  
         */
        getRemoteBranches : function(options, success, error){
            var remote = SmartHttpRemote(null, null, options.url, options.username, options.password, error);
            remote.fetchRefs(function(refs){
                var remoteBranches = [];
                refs.forEach(function(ref){
                    if (ref.name.indexOf('refs/heads/') == 0){
                        remoteBranches.push(ref.name.substring('refs/heads/'.length));
                    }
                });
                success(remoteBranches);
            });
        }

        /**
         * error callback that gets notified if there is an error  
         * @callback errorCallback
         * @param {Object} err Error data object
         * @param {Number} err.type The type of error. Should be one of the error constants in the api like {@link FILE_IO_ERROR}
         * @param {String} err.msg An explanation of the error in English. 
         */

         /**
         * progress callback that gets notified of the progress of various operaions  
         * @callback progressCallback
         * @param {Object} progress Progress data object
         * @param {Number} progress.pct a number between 1-100 that indicates the percentage of the operation that is complete.
         * @param {String} progress.msg An description of the current state of the operation in English. 
         */

         /**
          * success callback that gets notified when an operation completes successfully. 
          * @callback successCallback
          */

    }
    return api;
});    //The modules for your project will be inlined above
    //this snippet. Ask almond to synchronously require the
    //module value for 'main' here and return it as the
    //value to use for the public API for the built file.
    return require('api');
}));
