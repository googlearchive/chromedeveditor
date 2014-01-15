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
define('formats/smart_http_remote',['utils/progress_chunker'], function(ProgressChunker) {
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
          //   var msg = evt.data;
          //   if (msg.type == GitLiteWorkerMessages.FINISHED && callback){
          //     packWorker.terminate();
          //     callback(msg.objects, new Uint8Array(msg.data), msg.common);
          //   }
          //   else if (msg.type == GitLiteWorkerMessages.RETRIEVE_OBJECT){
          //     store._retrieveRawObject(msg.sha, "ArrayBuffer", function(baseObject){
          //       packWorker.postMessage({type: GitLiteWorkerMessages.OBJECT_RETRIEVED, id: msg.id, object: baseObject}, [baseObject.data]);
          //       var x = 0;
          //     });
          //   }
          //   else if (progress && msg.type == GitLiteWorkerMessages.PROGRESS){
          //     progress(msg);
          //   }
          // }
          // packWorker.postMessage({type: GitLiteWorkerMessages.START, data:binaryData}, [binaryData]);
        }
      }
      if (receiveProgress){
        xhr.onprogress = function(evt){
          // if (evt.lengthComputable){
          //   var pct = evt.loaded / evt.total;
          //   receiveProgress({pct: pct, msg: "Received " + evt.loaded + "/" + evt.total + " bytes"});
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
      //  url: url,
      //  data: body,
      //  type: "POST",
      //  contentType: "application/x-git-upload-pack-request",
      //  beforeSend: function(xhr) {
      //    xhr.overrideMimeType('text/plain; charset=x-user-defined')
      //  },
      //  success: function(data, textStatus, xhr) {
      //    var binaryData = xhr.responseText
      //    if (haveRefs && binaryData.indexOf("NAK") == 4){
      //      if (moreHaves){
      //   thisRemote.repo._getCommitGraph(moreHaves, 32, function(commits, next){
      //     thisRemote.fetchRef(wantRefs, commits, next, callback);
      //   });
      // }
      //    }
      //    else{
      // var parser = new Git.UploadPackParser(binaryData, repo)
      // parser.parse(function(objects, packData, common){
      //   if (callback != "undefined") {
      //     callback(objects, packData, common);
      //   }
      // });
      // }
      //  },
      //  error: function(xhr, data, e) {
      //    Git.displayError("ERROR Status: " + xhr.status + ", response: " + xhr.responseText)
      //  }
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

define('commands/clone',['formats/smart_http_remote', 'utils/progress_chunker'], function(SmartHttpRemote, ProgressChunker){

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
                  store.loadWith(objectsDir, [{pack: new Packer(packData, self), idx: packIdx}]);
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
define('commands/commit',[], function () {

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

define('commands/conditions',[],function(){

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
define('commands/pull',['commands/treemerger', 'commands/conditions', 'formats/smart_http_remote', 'utils/progress_chunker'], function(treeMerger, Conditions, SmartHttpRemote, ProgressChunker){


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
                        store.packs.push({pack: new Packer(packData, store), idx: packIdx});

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
                      //   treeMerger.mergeTrees(store, trees[0], trees[1], trees[2], function(finalTree){
                      //     mkfile(store.dir, '.git/' + wantRef.name, sha, done);
                      //   }, function(e){errors.push(e);done();});
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
define('commands/push',['formats/smart_http_remote', 'utils/progress_chunker'], function(SmartHttpRemote, ProgressChunker){
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
          Packer.buildPack(commits, store, function(packData){
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
define('commands/branch',[], function(){

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
define('commands/checkout',['commands/conditions'], function(Conditions){

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


define('api',['commands/clone', 'commands/commit', 'commands/init', 'commands/pull', 'commands/push', 'commands/branch', 'commands/checkout', 'commands/conditions', 'formats/smart_http_remote', "workers/worker_messages"], function(clone, commit, init, pull, push, branch, checkout, Conditions, SmartHttpRemote){

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

    getFs : function(success) {
      // TODO: remove the need for the getFs function in the near term
      window.webkitRequestFileSystem(window.TEMPORARY, 5 * 1024 * 1024 * 1024, function(fs) {
        success(fs);
      });
//      chrome.syncFileSystem.requestFileSystem(function(fs) {
//        success(fs);
//      });
    },

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
});  //The modules for your project will be inlined above
  //this snippet. Ask almond to synchronously require the
  //module value for 'main' here and return it as the
  //value to use for the public API for the built file.
  return require('api');
}));
