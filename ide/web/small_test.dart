//import "lib/filesystem.dart" show Glob;

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

  String toRegEx();
}

class FileWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegEx() => "[^/]*";

  FileWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class PathWildcardMatcher extends GlobMatcher {
  int get end => tokenStart + 2;
  String toRegEx() => ".*";

  PathWildcardMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class SingleCharMatcher  extends GlobMatcher {
  int get end => tokenStart + 1;
  String toRegEx() => "[^/]";

  SingleCharMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class CharRangeMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("]", tokenStart) : _end;
  String toRegEx() => "[" + (negate ? "^" : "") + "$rangeString]";
  bool get negate => input[tokenStart + 1] == "!";
  String get rangeString => input.substring(tokenStart + (negate ? 1 : 2), end - 1);

  CharRangeMatcher(String input, GlobPattern pattern, int start, int tokenStart) :
      super(input, pattern, start, tokenStart);
}

class IdentifierListMatcher extends GlobMatcher {
  int _end = null;
  int get end => (_end == null) ? _end = input.indexOf("}", tokenStart) : _end;
  String toRegEx() => "(" + identifiers.join('|') + ")";
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
    do {
      int n = string.indexOf(new RegExp(r"[\\*?\[\{]"), start);
      GlobMatcher matcher;

      // Identifies the first char as escape and ignores the second)
      switch(string[n++]) {
        case "\\":
          // Ignore next char after escape
          start = n + 1;
          continue;
        case "*":
          if (string.length > n && string[n] == "*") {
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
        default:
          return null;
      }
    } while(start < string.length);

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

  final String pattern;

  Glob(this.pattern);

  String _escape(String toEscape) {
    // TODO(ericarnold): Implement regexp escaping
    return toEscape;
  }


  // Matches a path to the glob pattern.  Returns one of three values:
  //
  // NO_MATCH - No match found ("foo" won't match "bar")
  // PREFIX_MATCH - Prefix match found ("f*/b*/" partially matches "foo/")
  // COMPLETE_MATCH - Prefix match found ("f**/b*" completely matches "foo/bar/baz")
  int matchPath(String path) {
    int lastIndex = 0;

    GlobPattern p = new GlobPattern();
    List<String> globParts = p.allMatches(pattern).map((GlobMatcher m) =>
        _escape(pattern.substring(m.start, m.tokenStart)) + m.toRegEx()).toList();

    /*%TRACE3*/ print("""(4> 11/10/14): globParts: ${globParts}"""); // TRACE%

    String globSoFar = "";
    int globIndex = 0;

    for (;globIndex < globParts.length; globIndex++) {
      String globPart = globParts[globIndex];
      globSoFar += ((globSoFar != "") ? ".*" : "") +
          globPart.replaceAll("*", "[^/]*").replaceAll("?", "[^/]");
      if (globIndex == globParts.length - 1) globSoFar = globSoFar + "\$";
      if (new RegExp(globSoFar).matchAsPrefix(path) == null) break;
    }

    if (globIndex > 0) {
      if (globIndex == globParts.length) {
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
}

expect(dynamic v1, dynamic v2) {
  print("${v1==v2} -- v1");
}

