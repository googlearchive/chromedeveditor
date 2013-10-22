var object2file = {

    expandBlob: function(dir, store, name, blobSha, callback) {
        var makeFileFactory = function(name){
            return function(blob){
                fileutils.mkfile(dir, name, blob.data, callback, function(e){console.log(e)});
            }
        }
        store._retrieveObject(blobSha, "Blob", makeFileFactory(name));
    },

    expandTree: function(dir, store, treeSha, callback) {

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
};