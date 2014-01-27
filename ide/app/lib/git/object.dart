// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objects;

import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:chrome/src/common_exp.dart' as chrome;

import 'object_utils.dart';

/**
 * Encapsulates a Gitobject
 *
 * TODO(grv): Add unittests.
 */
abstract class GitObject {

  /**
   * Constructs a GitObject of the given type. [content] can be of type [String]
   * or [Uint8List].
   */
  static GitObject make(String sha, String type, content,
                        [LooseObject rawObj]) {
    switch (type) {
      case ObjectTypes.BLOB:
        return new BlobObject(sha, content);
      case ObjectTypes.TREE:
      case "Tree":
        return new TreeObject(sha, content, rawObj);
      case ObjectTypes.COMMIT:
        return new CommitObject(sha, content, rawObj);
      case ObjectTypes.TAG:
        return new TagObject(sha, content);
      default:
        throw new ArgumentError("Unsupported git object type: ${type}");
    }
  }

  GitObject([this._sha, this.data]);

  // The type of git object.
  String _type;
  dynamic data;
  String _sha;

  String toString() => data.toString();
}

/**
 * Represents an entry in a git TreeObject.
 */
class TreeEntry {

  String name;
  Uint8List sha;
  bool isBlob;

  TreeEntry(this.name, this.sha, this.isBlob);
}



/**
 * Error thrown for a parse failure.
 */
class ParseError extends Error {
  final message;

  /** The [message] describes the parse failure. */
  ParseError([this.message]);

  String toString() {
    if (message != null) {
      return "Parse Error(s): $message";
    }
    return "Parse Error(s)";
  }
}

/**
 * A tree type git object.
 */
class TreeObject extends GitObject {

  List<TreeEntry> entries;
  LooseObject rawObj;

  TreeObject( [String sha, Uint8List data, LooseObject rawObj])
      : super(sha, data) {
    this._type = ObjectTypes.TREE;
    this.rawObj  = rawObj;
    _parse();
  }

  sortEntries() {
    //TODO implement.
  }

  // Parses the byte stream and constructs the tree object.
  void _parse() {
    Uint8List buffer = data;
    List<TreeEntry> treeEntries = [];
    int idx = 0;
    while (idx < buffer.length) {
      int entryStart = idx;
      while (buffer[idx] != 0) {
        if (idx >= buffer.length) {
          //TODO(grv) : better exception handling.
          throw new ParseError("Unable to parse git tree object");
        }
        idx++;
      }
      bool isBlob = buffer[entryStart] == 49; // '1' character
      String nameStr = UTF8.decode(buffer.sublist(
          entryStart + (isBlob ? 7: 6), idx++));
      nameStr = Uri.decodeComponent(HTML_ESCAPE.convert(nameStr));
      TreeEntry entry = new TreeEntry(nameStr, buffer.sublist(idx, idx + 20), isBlob);
      treeEntries.add(entry);
      idx += 20;
    }
    this.entries = treeEntries;
    // Sort tree entries in ascending order.
    this.entries.sort((TreeEntry a, TreeEntry b) => a.name.compareTo(b.name));
  }
}

/**
 * Represents a git blob object.
 */
class BlobObject extends GitObject {

  BlobObject(String sha, String data) : super(sha, data) {
    this._type = ObjectTypes.BLOB;
  }
}

/**
 * Represents author's / commiter's information in a git commit object.
 */
class Author {

  String name;
  String email;
  int timestamp;
  DateTime date;
}

/**
 * Represents a git commit object.
 */
class CommitObject extends GitObject {

  List<String> parents;
  Author author;
  Author committer;
  String _encoding;
  String _message;
  String treeSha;

  // raw commit object. This is needed in building pack files.
  LooseObject rawObj;

  CommitObject(String sha, var data, [rawObj]) {
    this._type = ObjectTypes.COMMIT;
    this._sha = sha;
    this.rawObj = rawObj;

    if (data is Uint8List) {
      this.data = UTF8.decode(data);
    } else if (data is String) {
      this.data = data;
    } else {
      // TODO: Clarify this exception.
      throw "Data is in incompatible format.";
    }

    _parseData();
  }

  // Parses the byte stream and constructs the commit object.
  void _parseData() {
    List<String> lines = data.split("\n");
    this.treeSha = lines[0].split(" ")[1];

    int i = 1;
    parents = [];
    while (lines[i].substring(0,6) == "parent") {
      parents.add(lines[i].split(" ")[1]);
      i++;
    }

    String authorLine = lines[i].replaceFirst("author ", "");
    author = _parseAuthor(authorLine);

    String committerLine = lines[i + 1].replaceFirst("committer ", "");
    committer = _parseAuthor(committerLine);

    if (lines[i + 2].split(" ")[0] == "encoding") {
      _encoding = lines[i + 2].split(" ")[1];
    }

    lines.removeRange(0, i +2);

    _message = lines.join("\n");
  }

  Author _parseAuthor(String input) {

    // Regex " AuthorName <Email>  timestamp timeOffset"
    final RegExp pattern = new RegExp(r'(.*) <(.*)> (\d+) (\+|\-)\d\d\d\d');
    List<Match> match = pattern.allMatches(input).toList();

    Author author = new Author();
    author.name = match[0].group(1);
    author.email = match[0].group(2);
    author.timestamp = (int.parse(match[0].group(3))) * 1000;
    author.date = new DateTime.fromMillisecondsSinceEpoch(
        author.timestamp, isUtc:true);
    return author;
  }

  String toString() {
    String str = "commit " + _sha + "\n";
    str += "Author: " + author.name + " <" + author.email + ">\n";
    str += "Date:  " + author.date.toString() + "\n\n";
    str += _message;
    return str;
  }

  /**
   * Returns the commit object as a map for easy advanced formatting instead
   * of toString().
   */
  Map<String, String> toMap() {
    return {
            "commit": _sha,
            "author_name": author.name,
            "author_email": author.email,
            "date": author.date.toString(),
            "message": _message
           };
  }
}

/**
 * Represents a git tag object.
 */
class TagObject extends GitObject {
  TagObject(String sha, String data) : super(sha, data) {
    this._type = ObjectTypes.TAG;
  }
}

/**
 * A loose git object.
 */
class LooseObject {
  int size;
  int type;

  static Map<String, int> _typeMap = {
    ObjectTypes.COMMIT : 1,
    ObjectTypes.TREE : 2,
    ObjectTypes.BLOB : 3
  };

  // Represents either an ArrayBuffer or a string representation of byte
  //stream.
  dynamic data;

  LooseObject(buf) {
    _parse(buf);
  }

  // Parses and constructs a loose git object.
  void _parse(buf) {
    String header;
    int i;
    if (buf is chrome.ArrayBuffer) {
     Uint8List data = new Uint8List.fromList(buf.getBytes());
      List<String> headChars = [];
      for (i = 0; i < data.length; ++i) {
        if (data[i] != 0)
          headChars.add(UTF8.decode([data[i]]));
        else
          break;
      }
      header = headChars.join();

      this.data = data.sublist(i + 1, data.length);
    } else {
      i = buf.indexOf(new String.fromCharCode(0));
      header = buf.substring(0, i);
      // move past null terminator but keep zlib header
      this.data = buf.substring(i + 1, buf.length);
    }
    List<String> parts = header.split(' ');
    this.type = _typeMap[parts[0]];
    this.size = int.parse(parts[1]);
  }
}
