var object_types = {
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
        this.type = object_types[parts[0]];
        this.size = parseInt(parts[1]);
        // move past nul terminator but keep zlib header
        this.data = data[funcName](i + 1);
    }
};