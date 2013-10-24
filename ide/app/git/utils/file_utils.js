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

var fileutils = (function() {

	var toArray = function(list) {
		return Array.prototype.slice.call(list || [], 0);
	}

	var makeFile = function(root, filename, contents, callback, error) {
		root.getFile(filename, {create:true}, function(fileEntry) {
			fileEntry.createWriter(function(writer) {
				writer.onwriteend = function() {
					// strange piece of the FileWriter api. Writing to an
					// existing file just overwrites content in place. Still need to truncate
					// which triggers onwritend event...again. o_O
					if (writer.position < writer.length) {
						writer.truncate(writer.position);
					}
					else if (callback)
						callback(fileEntry);
					}
				writer.onerror = function(e) {
					throw(e);
				}
				if (contents instanceof ArrayBuffer) {
					contents = new Uint8Array(contents);
				}
				writer.write(new Blob([contents]));
			}, error);
		}, error);
	}

	var makeDir = function(root, dirname, callback, error) {
		root.getDirectory(dirname, {create:true},callback, error);
	}

	return {
		mkdirs : function(root, dirname, callback, error) {
			var pathParts;
			if (dirname instanceof Array) {
				pathParts = dirname;
			}
			else {
				pathParts = dirname.split('/');
			}

			var makeDirCallback = function(dir) {
				if (pathParts.length){
					makeDir(dir, pathParts.shift(), makeDirCallback, error);
				}
				else {
					if (callback)
						callback(dir);
				}
			}
			makeDirCallback(root);
		},
		rmDir : function (root, dirname, callback) {
			root.getDirectory(dirname, {create:true}, function(dirEntry) {
				dirEntry.removeRecursively(callback, utils.errorHandler);
			});
		},
		rmFile : function(root, filename, callback) {
		console.log('wuppy');
		return;
			root.getFile(filename, {create:true}, function(fileEntry) {
				fileEntry.remove(callback, utils.errorHandler);
			});
		},
		mkfile : function(root, filename, contents, callback, error) {
			if (filename.charAt(0) == '/') {
				filename = filename.substring(1);
			}
			var pathParts = filename.split('/');
			if (pathParts.length > 1) {
				fileutils.mkdirs(root, pathParts.slice(0, pathParts.length - 1), function(dir) {
					makeFile(dir, pathParts[pathParts.length - 1], contents, callback, error);
				}, error);
			}
			else {
				makeFile(root, filename, contents, callback, error);
			}
		},
		ls: function(dir, callback, error) {
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
		readBlob: function(blob, dataType, callback) {
			var reader = new FileReader();
			reader.onloadend = function(e) {
				callback(reader.result);
			}
			reader["readAs" + dataType](blob);
		},
		readFileEntry : function(fileEntry, dataType, callback) {
			fileEntry.file(function(file) {
				fileutils.readBlob(file, dataType, callback);
			});
		},
		readFile : function(root, file, dataType, callback, error) {
				root.getFile(file, {create:false}, function(fileEntry) {
				fileutils.readFileEntry(fileEntry, dataType, callback, error);
			}, error);
		}
	};
})();