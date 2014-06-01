// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.diff3;

import 'dart:js' as js;
import 'dart:math' as Math;

/**
 * Wrapper for the diff3.js library.
 */
class Diff3 {
  static js.JsObject _diff = js.context['Diff'];

  static Diff3Result diff(String our, String base, String their) {
    var result = _diff.callMethod("diff3_dig", [our, base, their]);
    return new Diff3Result(result['text'], result['conflict']);
  }
}

class Diff3Result {
  String text;
  bool conflict;
  Diff3Result(this.text, this.conflict);
}

// TODO(adam): make pub package
// Ported from diff3.js
// Small paper on diff3
// http://www.cis.upenn.edu/~bcpierce/papers/diff3-short.pdf
class Diff {
  static const newLines = '\n';

  Map longest_common_subsequence(List<String> file1, List<String> file2) {
    /* Text diff algorithm following Hunt and McIlroy 1976.
     * J. W. Hunt and M. D. McIlroy, An algorithm for differential file
     * comparison, Bell Telephone Laboratories CSTR #41 (1976)
     * http://www.cs.dartmouth.edu/~doug/
     *
     * Expects two arrays of strings.
     */
    var equivalenceClasses;
    List file2indices;
    Map newCandidate;
    List<Map> candidates;
    var line;
    int s;
    Map c;
    int j;
    int i;
    int r;
    int jX;

    equivalenceClasses = {};
    for (j = 0; j < file2.length; j++) {
      line = file2[j];
      if (equivalenceClasses.containsKey(line)) {
        equivalenceClasses[line].add(j);
      } else {
        equivalenceClasses[line] = [j];
      }
    }

    // TODO(adam): class `Candidate`
    candidates = [{"file1index": -1, "file2index": -1, "chain": null}];

    for (i = 0; i < file1.length; i++) {
      line = file1[i];
      file2indices = equivalenceClasses.containsKey(line) ?
          equivalenceClasses[line] : [];

      r = 0;
      c = candidates[0];

      for (jX = 0; jX < file2indices.length; jX++) {
        j = file2indices[jX];

        for (s = r; s < candidates.length; s++) {
          if ((candidates[s]["file2index"] < j) &&
              ((s == candidates.length - 1) ||
              (candidates[s + 1]["file2index"] > j))) {
            break;
          }
        }

        if (s < candidates.length) {
          newCandidate = {"file1index": i, "file2index": j,
                          "chain": candidates[s]};

          if (r == candidates.length) {
            candidates.add(c);
          } else {
            candidates[r] = c;
          }

          r = s + 1;
          c = newCandidate;

          if (r == candidates.length) {
            break; // no point in examining further (j)s
          }
        }
      }

      candidates[r] = c;
    }

    // At this point, we know the LCS: it's in the reverse of the
    // linked-list through .chain of
    // candidates[candidates.length - 1].

    return candidates[candidates.length - 1];
  }

  diff_comm(file1, file2) { throw new UnimplementedError(); }
  diff_patch(file1, file2) { throw new UnimplementedError(); }
  strip_patch(patch) { throw new UnimplementedError(); }
  invert_patch(patch) { throw new UnimplementedError(); }
  patch(file, patch) { throw new UnimplementedError(); }

  List diff_indices(List<String> file1, List<String> file2) {
    // We apply the LCS to give a simple representation of the
    // offsets and lengths of mismatched chunks in the input
    // files. This is used by diff3_merge_indices below.
    List result = [];
    int tail1 = file1.length;
    int tail2 = file2.length;

    Map chunkDescription(file, int offset, int length) {
      List chunk = [];
      for (int i = 0; i < length; i++) {
        chunk.add(file[offset + i]);
      }

      // TODO(adam): class `ChunkDescription`
      return {"offset": offset, "length": length, "chunk": chunk};
    }

    // TODO(adam): class `Candidate`
    var candidate = longest_common_subsequence(file1, file2);

    for (; candidate != null; candidate = candidate["chain"]) {
      int mismatchLength1 = tail1 - candidate["file1index"] - 1;
      int mismatchLength2 = tail2 - candidate["file2index"] - 1;
      tail1 = candidate["file1index"];
      tail2 = candidate["file2index"];

      if (mismatchLength1 != 0 || mismatchLength2 != 0) {
        result.add({
          "file1": chunkDescription(file1, candidate["file1index"] + 1, mismatchLength1),
          "file2": chunkDescription(file2, candidate["file2index"] + 1, mismatchLength2)
        });
      }
    }

    result = result.reversed.toList();
    return result;
  }

  List<List<int>> diff3_merge_indices(List<String> a, List<String> o,
      List<String> b) {
    // Given three files, A, O, and B, where both A and B are
    // independently derived from O, returns a fairly complicated
    // internal representation of merge decisions it's taken. The
    // interested reader may wish to consult
    //
    // Sanjeev Khanna, Keshav Kunal, and Benjamin C. Pierce. "A
    // Formal Investigation of Diff3." In Arvind and Prasad,
    // editors, Foundations of Software Technology and Theoretical
    // Computer Science (FSTTCS), December 2007.
    //
    // (http://www.cis.upenn.edu/~bcpierce/papers/diff3-short.pdf)

    var m1 = diff_indices(o, a);
    var m2 = diff_indices(o, b);

    List<List> hunks = [];
    void addHunk(h, int side) {
      hunks.add([h.file1[0], side, h.file1[1], h.file2[0], h.file2[1]]);
    }

    for (int i = 0; i < m1.length; i++) {
      addHunk(m1[i], 0);
    }

    for (int i = 0; i < m2.length; i++) {
      addHunk(m2[i], 2);
    }

    hunks.sort();

    List result = [];
    int commonOffset = 0;

    void copyCommon(int targetOffset) {
      if (targetOffset > commonOffset) {
        result.add([1, commonOffset, targetOffset - commonOffset]);
        commonOffset = targetOffset;
      }
    }

    for (int hunkIndex = 0; hunkIndex < hunks.length; hunkIndex++) {
      int firstHunkIndex = hunkIndex;
      var hunk = hunks[hunkIndex];
      var regionLhs = hunk[0];
      var regionRhs = regionLhs + hunk[2];

      while (hunkIndex < hunks.length - 1) {
        List maybeOverlapping = hunks[hunkIndex + 1];
        var maybeLhs = maybeOverlapping[0];

        if (maybeLhs > regionRhs) {
          break;
        }

        regionRhs = Math.max(regionRhs, maybeLhs + maybeOverlapping[2]);
        hunkIndex++;
      }

      copyCommon(regionLhs);

      if (firstHunkIndex == hunkIndex) {
        // The "overlap" was only one hunk long, meaning that
        // there's no conflict here. Either a and o were the
        // same, or b and o were the same.
        if (hunk[4] > 0) {
          result.add([hunk[1], hunk[3], hunk[4]]);
        }
      } else {
        // A proper conflict. Determine the extents of the
        // regions involved from a, o and b. Effectively merge
        // all the hunks on the left into one giant hunk, and
        // do the same for the right; then, correct for skew
        // in the regions of o that each side changed, and
        // report appropriate spans for the three sides.
        var regions = {0: [a.length, -1, o.length, -1],
                       2: [b.length, -1, o.length, -1]};

        for (int i = firstHunkIndex; i <= hunkIndex; i++) {
          hunk = hunks[i];
          int side = hunk[1];
          List r = regions[side];
          int oLhs = hunk[0];
          int oRhs = oLhs + hunk[2];
          int abLhs = hunk[3];
          int abRhs = abLhs + hunk[4];

          r[0] = Math.min(abLhs, r[0]);
          r[1] = Math.max(abRhs, r[1]);
          r[2] = Math.min(oLhs, r[2]);
          r[3] = Math.max(oRhs, r[3]);
        }

        var aLhs = regions[0][0] + (regionLhs - regions[0][2]);
        var aRhs = regions[0][1] + (regionRhs - regions[0][3]);
        var bLhs = regions[2][0] + (regionLhs - regions[2][2]);
        var bRhs = regions[2][1] + (regionRhs - regions[2][3]);

        result.add([-1, aLhs, aRhs - aLhs, regionLhs, regionRhs - regionLhs,
                    bLhs, bRhs - bLhs]);
      }

      commonOffset = regionRhs;
    }

    copyCommon(o.length);
    return result;
  }

  List<Map> diff3_merge(List<String> a, List<String> o, List<String> b,
              bool excludeFalseConflicts) {
    // Applies the output of Diff.diff3_merge_indices to actually
    // construct the merged file; the returned result alternates
    // between "ok" and "conflict" blocks.

    List<Map> result = [];
    List<List<String>> files = [a, o, b];
    // TODO(adam): type the indices
    List<List<int>> indices = diff3_merge_indices(a, o, b);
    List okLines = [];

    void flushOk() {
      if (okLines.length != 0) {
        result.add({"ok": okLines});
      }

      okLines = [];
    }

    void pushOk(xs) {
      for (int j = 0; j < xs.length; j++) {
        okLines.add(xs[j]);
      }
    }

    bool isTrueConflict(List<int> rec) {
      if (rec[2] != rec[6]) {
        return true;
      }

      var aoff = rec[1];
      var boff = rec[5];
      for (int j = 0; j < rec[2]; j++) {
        if (a[j + aoff] != b[j + boff]) {
          return true;
        }
      }

      return false;
    }

    for (int i = 0; i < indices.length; i++) {
      List<int> x = indices[i];
      int side = x[0];
      if (side == -1) {
        if (excludeFalseConflicts && !isTrueConflict(x)) {
          pushOk(files[0].getRange(x[1], x[1] + x[2]));
        } else {
          flushOk();
          // TODO(adam): class `Conflict`
          result.add({
            "conflict": {
              "a": a.getRange(x[1], x[1] + x[2]),
              "aIndex": x[1],
              "o": o.getRange(x[3], x[3] + x[4]),
              "oIndex": x[3],
              "b": b.getRange(x[5], x[5] + x[6]),
              "bIndex": x[5]
            }
          });
        }
      } else {
        pushOk(files[side].getRange(x[1], x[1] + x[2]));
      }
    }

    flushOk();
    return result;
  }

  Map diff3_dig(String ours, String base, String theirs) {
    List<String> a = ours.split(Diff.newLines);
    List<String> b = theirs.split(Diff.newLines);
    List<String> o = base.split(Diff.newLines);

    List<Map> merger = diff3_merge(a, o, b, false);
    List<List<String>> lines = [];
    bool conflict = false;
    for (int i = 0; i < merger.length; i++) {
      Map item = merger[i];
      if (item.containsKey("ok")) {
        lines.addAll(item["ok"]);
      } else {
        List<Map> c = diff_comm(item["conflict"]["a"], item["conflict"]["b"]);
        for (int j = 0; j < c.length; j++) {
          var inner = c[j];
          if (inner.containsKey(["common"])) {
            lines.addAll(item["common"]);
          } else {
            conflict = true;
            lines.addAll([ ["<<<<<<<<<"], inner["file1"],
                           ["========="], inner["file2"],
                           [">>>>>>>>>"]  ]);
          }
        }
      }
    }

    // TODO(adam): create class `DiffResult`
    return {"conflict": conflict, "text": lines.join("\n")};
  }
}