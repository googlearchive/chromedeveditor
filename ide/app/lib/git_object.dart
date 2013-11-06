// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objects;

import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:chrome_gen/src/common_exp.dart' as chrome_gen;
import 'package:utf/utf.dart';

/**
 * Encapsulates a Gitobject
 *
 * TODO(grv): Add unittests.
 **/
abstract class GitObject {

  /**
   * constructs a GitObject of the given type.
   */
  static GitObject make(String sha, String type, String content) {
    switch (type) {
      case "blob":
        return new BlobObject(sha, content);
      case "tree":
        return new TreeObject(sha, content);
      case "commit":
        return new CommitObject(sha, content);
      case "tag":
        return new TagObject(sha, content);
      default:
        throw new ArgumentError("Unsupported git object type.");
    }
  }

  // The type of git object.
  String _type;

  // byte stream converted to string.
  String _data;
  String _sha;

  String toString() => _data;
}

/**
 * Represents an entry in a git TreeObject.
 */
class TreeEntry {

  bool isBlob;
  String name;
  Uint8List sha;

  TreeEntry(bool isBlob, String nameStr, Uint8List sha) {
    this.isBlob = isBlob;
    this.name = nameStr;
    this.sha = sha;
  }
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

  TreeObject(String sha, String data) {
    this._type = "tree";
    this._sha = sha;
    this._data = data;
    _parse();
  }

  // Parses the byte stream and constructs the tree object.
  void _parse() {
    Uint8List buffer = new Uint8List.fromList(encodeUtf8(_data));
    List<TreeEntry> treeEntries;
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
      TreeEntry entry = new TreeEntry(isBlob, nameStr, buffer.sublist(idx, idx + 20));
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

  BlobObject(String sha, String data) {
    this._type = "blob";
    this._sha = sha;
    this._data = data;
  }

  String toString() => this._data;
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

  List<String> _parents;
  Author _author;
  Author _committer;
  String _encoding;
  String _message;

  CommitObject(String sha, String data) {
    this._type = "commit";
    this._sha = sha;
    this._data = data;
    _parseData();
  }


  // Parses the byte stream and constructs the commit object.
  void _parseData() {
    List<String> lines = _data.split("\n");
    int i = 1;
    _parents = [];
    while (lines[i].substring(0,6) == "parent") {
      _parents.add(lines[i].split(" ")[1]);
      i++;
    }

    String authorLine = lines[i].replaceFirst("author", "");
    _author = _parseAuthor(authorLine);

    var committerLine = lines[i + 1].replaceFirst("committer ", "");
    _committer = _parseAuthor(committerLine);

    if (lines[i + 2].split(" ")[0] == "encoding") {
      _encoding = lines[i + 2].split(" ")[1];
    }

    lines.removeRange(0, i +2);

    _message = lines.join("\n");
  }

  Author _parseAuthor(String input) {
    final RegExp pattern = new RegExp('/^(.*) <(.*)> (\d+) (\+|\-)\d\d\d\d\$/');
    List<Match> match = pattern.allMatches(input);

    Author author = new Author();
    author.name = match[0].group(0);
    author.email = match[2].group(0);
    author.timestamp = int.parse(match[3].group(0));
    author.date = new DateTime.fromMillisecondsSinceEpoch(
        author.timestamp, isUtc:true);
    return author;
  }

  String toString() {
    String str = "commit " + _sha + "\n";
    str += "Author: " + _author.name + " <" + _author.email + ">\n";
    str += "Date:  " + _author.date.toString() + "\n\n";
    str += _message;
    return str;
  }
}

/**
 * Represents a git tag object.
 */
class TagObject extends GitObject {
  TagObject(String sha, String data) {
    this._type ="tag";
    this._sha = sha;
    this._data = data;
  }
}

/**
 * A loose git object.
 */
class LooseObject {
  int _size;
  String _type;

  // Represents either an ArrayBuffer or a string representation of byte
  //stream.
  dynamic _data;

  // Parses and constructs a loose git object.
  void _parse(dynamic buf) {
    Uint8List data = new Uint8List(buf);
    String header;
    int i;
    if (buf is chrome_gen.ArrayBuffer) {
      List<String> headChars = [];
      for (i = 0; i < data.length; ++i) {
        if (data[i] != 0)
          headChars.add(UTF8.decode([data[i]]));
          else
            break;
      }
      header = headChars.join(' ');

      this._data = data.sublist(i + 1, data.length);
    } else {
      String data = buf;
      i = data.indexOf('\0)');
      header = data.substring(0, i);
      // move past null terminator but keep zlib header
      this._data = data.substring(i + 1, data.length);
    }
    List<String> parts = header.split(' ');
    this._type = parts[0];
    this._size = int.parse(parts[1]);
  }
}