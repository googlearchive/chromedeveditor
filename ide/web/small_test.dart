abstract class GlobMatcher extends Match {
  String operator [](int group) => this.group(group);

  final int start;
  final int tokenStart;
  int get end;
  final String input;
  final GlobPattern pattern;
  final int groupCount = 1;

  GlobMatcher(this.input, this.pattern, this.start, this.tokenStart);

  String group(int group) {
    if (group != 0) throw new RangeError("GlobMatchers only have one group");
    return input.substring(start, end);
  }

  @override
  List<String> groups(List<int> groupIndices) {
    if (groupIndices.length > 1) {
      throw new RangeError("GlobMatchers only have one group");
    }
    return [this.group(groupIndices[0])];
  }

  String toRegExp();
}

class StaticMatcher extends GlobMatcher {
  int get end => tokenStart;
  String toRegExp() => "";

  StaticMatcher(String input, GlobPattern pattern, int start, int end) :
      super(input, pattern, start, end);
}


class FileWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegExp() => "[^/]*";

  FileWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class PathWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 2;
  String toRegExp() => ".*";

  PathWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class SingleCharMatcher  extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegExp() => "[^/]";

  SingleCharMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class CharRangeMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("]", tokenStart) : _end;
  String toRegExp() => "[" + (negate ? "^" : "") + "$rangeString]";
  bool get negate => input[tokenStart + 1] == "!";
  String get rangeString => input.substring(tokenStart + (negate ? 1 : 2), end - 1);

  CharRangeMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class IdentifierListMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("}", tokenStart) : _end;
  String toRegExp() => "(" + identifiers.join('|') + ")";
  String get _matcherContent => input.substring(tokenStart + 1, end - 1);
  List<String> get identifiers => _matcherContent.split(new RegExp(r",\s*"));

  IdentifierListMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class GlobPattern implements Pattern {
  Iterable<Match> allMatches(String string, [int start = 0]) {
    List<Match> matches = [];

    do {
      GlobMatcher match = matchAsPrefix(string, start);
      if (match == null) {
        break;
      }
      matches.add(match);
      start = match.end + 1;
    } while(start < string.length);

    return matches;
  }

  GlobMatcher matchAsPrefix(String string, [int start = 0]) {
    int n = start;
    do {
      n = string.indexOf(new RegExp(r"[\\*?\[\{]"), n);
      GlobMatcher matcher;

      if (n == -1) {
        return new StaticMatcher(string, this, start, string.length);
      }

      // Identifies the first char as escape and ignores the second)
      switch(string[n]) {
        case "\\":
          // Ignore next char after escape
          n = n + 2;
          continue;
        case "*":
          if (string.length > n + 1 && string[n + 1] == "*") {
            return new PathWildcardMatcher(string, this, start, n);
          } else {
            return new FileWildcardMatcher(string, this, start, n);
          }
          break;
        case "?":
          return new SingleCharMatcher(string, this, start, n);
        case "[":
          return new SingleCharMatcher(string, this, start, n);
        case "{":
          return new IdentifierListMatcher(string, this, start, n);
      }
    } while(n < string.length);

    throw "Unexpected end of line";
  }
}

/**
 * Defines a matcher for recursively matching of globs.
 */
class Glob {
  static int NO_MATCH = 0;
  static int PREFIX_MATCH = 1;
  static int COMPLETE_MATCH = 2;
  static final RegExp _escapePattern = new RegExp("[!@#\$%^&()-.,<>+=\\/~`|]");

  List<String> _globRegExpParts;

  Glob(String pattern) {
    Iterable<Match> globMatchers = new GlobPattern().allMatches(pattern);
    _globRegExpParts = globMatchers.map((GlobMatcher m) =>
        _escape(pattern.substring(m.start, m.tokenStart)) + m.toRegExp()).toList();
  }

  String _escape(String toEscape) {
    int start = 0;
    return _escapePattern.allMatches(toEscape).fold("", (String s, Match m) =>
        s + toEscape.substring(start, (start = m.end) - 1) + "\\" + m[0]) +
        toEscape.substring(start);
  }


  // Matches a path to the glob pattern.  Returns one of three values:
  //
  // NO_MATCH - No match found ("foo" won't match "bar")
  // PREFIX_MATCH - Prefix match found ("f*/b*/" partially matches "foo/")
  // COMPLETE_MATCH - Prefix match found ("f**/b*" completely matches "foo/bar/baz")
  int matchPath(String path) {
    int lastIndex = 0;

    String globSoFar = "";
    int globIndex = 0;

    for (;globIndex < _globRegExpParts.length; globIndex++) {
      String globPart = _globRegExpParts[globIndex];
      globSoFar += ((globSoFar != "") ? ".*" : "") +
          globPart.replaceAll("*", "[^/]*").replaceAll("?", "[^/]");
      if (globIndex == _globRegExpParts.length - 1) globSoFar = globSoFar + "\$";
      if (new RegExp(globSoFar).matchAsPrefix(path) == null) break;
    }

    if (globIndex > 0) {
      if (globIndex == _globRegExpParts.length) {
        return COMPLETE_MATCH;
      }
      return PREFIX_MATCH;
    }
    return NO_MATCH;
  }
}

main() {
  Glob glob = new Glob("a*/b**/d?");
  expect(glob.matchPath("alpha/bravo/charlie/delta"), Glob.PREFIX_MATCH);
  expect(glob.matchPath("alpha/bravo/charlie/d"), Glob.PREFIX_MATCH);
  expect(glob.matchPath("alpha/bravo/charlie/do"), Glob.COMPLETE_MATCH);
  expect(glob.matchPath("abc/do"), Glob.PREFIX_MATCH);
  expect(glob.matchPath("foo/bar"), Glob.NO_MATCH);
  expect(glob.matchPath(""), Glob.NO_MATCH);

  glob = new Glob("a*/b*");
  expect(glob.matchPath("abc/"), Glob.PREFIX_MATCH);

  glob = new Glob("a**/foo\\ bar");
  expect(glob.matchPath("aaa/bbb"), Glob.PREFIX_MATCH);
  expect(glob.matchPath("aaa/bbb/foo ba"), Glob.PREFIX_MATCH);
  expect(glob.matchPath("aaa/bbb/foo bar"), Glob.COMPLETE_MATCH);
  expect(glob.matchPath("aaa/bbb/foo barb"), Glob.PREFIX_MATCH);

  glob = new Glob("foo.dart");
  expect(glob.matchPath("foo.dart"), Glob.COMPLETE_MATCH);
  expect(glob.matchPath("foo!dart"), Glob.NO_MATCH);
}

expect(dynamic v1, dynamic v2) {
  print("${v1==v2} -- $v1");
}

