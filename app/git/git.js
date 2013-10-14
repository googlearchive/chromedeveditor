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

define('utils/file_utils',[], function(){
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

define('formats/pack',['objectstore/delta', 'utils/file_utils', 'thirdparty/2.2.0-sha1'], function(applyDelta, fileutils) {

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
define('formats/upload_pack_parser',['formats/pack'], function(Pack) {
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
define('commands/commit',['utils/file_utils', 'utils/errors'], function (fileutils, errutils) {

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
                            treeEntries.push({name: /*'40000 ' + */entry.name, sha: utils.convertShaToBytes(sha), isBlob: false});
                        }
                        done();
                    });

                }
                else{
                    entry.file(function(file){
                        var reader = new FileReader();
                        reader.onloadend = function(){
                            store.writeRawObject('blob', new Uint8Array(reader.result), function(sha){
                                treeEntries.push({name: /*'100644 ' + */entry.name, sha: utils.convertShaToBytes(sha), isBlob: true});
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
define('commands/treemerger',[], function(){

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

define('objectstore/objects',['thirdparty/underscore-min'], function() {
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
define('objectstore/file_repo',['formats/pack', 'formats/pack_index', 'objectstore/objects', 'utils/file_utils', 'utils/errors'], function(Pack, PackIndex, GitObjects, fileutils, errutils){

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


define('api',['commands/clone', 'commands/commit', 'commands/init', 'commands/pull', 'commands/push', 'commands/branch', 'commands/checkout', 'commands/conditions', 'objectstore/file_repo', 'formats/smart_http_remote', 'utils/errors', 'thirdparty/2.2.0-sha1', 'thirdparty/crc32', "workers/worker_messages"], function(clone, commit, init, pull, push, branch, checkout, Conditions, FileObjectStore, SmartHttpRemote, errutils){

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
