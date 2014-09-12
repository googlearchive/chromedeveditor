// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines various performance benchmarks for Spark.
 */
library spark.benchmarks;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import '../lib/git/fast_sha.dart';
import '../lib/git/utils.dart';
import '../lib/git/zlib.dart';

final ScoreEmitter _emitter = new LoggerEmitter();
final NumberFormat _nf = new NumberFormat.decimalPattern();

Logger _logger = new Logger('spark.benchmarks');

//Dartium:
// archive inflate :   4.051 ms
// archive deflate :  20.570 ms
// create zip      :  88.936 ms
// git sha         : 295.857 ms (214.900 ms)
// jszlib inflate  : 304.714 ms
// jszlib deflate  : 440.040 ms

//dart2js:
// archive inflate :  22.573 ms (40.600 ms)
// archive deflate :  39.275 ms (168.250 ms)
// create zip      : 110.263 ms (489.800 ms)
// git sha         :1087.500 ms (1760.000 ms)
// plain sha       :1977.500 ms
// fast sha        : 216.000 ms (943.667 ms)
// jszlib inflate  :  36.161 ms
// jszlib deflate  : 826.000 ms

defineTests() {
  group('benchmarks', () {
    //test('archive inflate', () => runBenchmark(new InflateBenchmark()));
    //test('archive deflate', () => runBenchmark(new DeflateBenchmark()));
    //test('zlib inflate', () => runBenchmark(new ZlibInflateBenchmark()));
    //test('zlib deflate', () => runBenchmark(new ZlibDeflateBenchmark()));

    //test('create zip', () => runBenchmark(new CreateZipBenchmark()));

    test('plain sha', () => runBenchmark(new PlainShaBenchmark()));
    test('git sha', () => runBenchmark(new GitShaBenchmark()));
    test('fast sha', () => runBenchmark(new FastShaBenchmark()));
  });
}

void runBenchmark(BenchmarkBase benchmark) {
  benchmark.report();
}

class LoggerEmitter extends ScoreEmitter {
  void emit(String testName, double valueMicros) {
    _logger.info('${testName}: ${_nf.format(valueMicros / 1000.0)} ms');
  }
}

class InflateBenchmark extends BenchmarkBase {
  List data;

  InflateBenchmark() : super('archive inflate', emitter: _emitter);

  void setup() {
    data = new Deflate(_createData(100000)).getBytes();
  }

  void run() {
    new Inflate(data).getBytes();
  }
}

class DeflateBenchmark extends BenchmarkBase {
  List data;

  DeflateBenchmark() : super('archive deflate', emitter: _emitter);

  void setup() {
    data = _createData(100000);
  }

  void run() {
    new Deflate(data).getBytes();
  }
}

class CreateZipBenchmark extends BenchmarkBase {
  List<int> data0;
  List<int> data1;
  List<int> data2;

  CreateZipBenchmark() : super("create zip", emitter: _emitter);

  void setup() {
    data0 = _createData(50000);
    data1 = _createData(100000);
    data2 = _createData(200000);
  }

  void run() {
    Archive archive = new Archive();
    archive.addFile(new ArchiveFile('data0', data0.length, data0));
    archive.addFile(new ArchiveFile('data1', data1.length, data1));
    archive.addFile(new ArchiveFile('data2', data2.length, data2));
    ZipEncoder encoder = new ZipEncoder();
    List<int> bytes = encoder.encode(archive);
  }
}

class JszlibInflateBenchmark extends BenchmarkBase {
  List data;

  JszlibInflateBenchmark() : super('jszlib inflate', emitter: _emitter);

  void setup() {
    data = Zlib.deflate(_createData(100000)).data;
  }

  void run() {
    ZlibResult result = Zlib.inflate(data);
  }
}

class JszlibDeflateBenchmark extends BenchmarkBase {
  List data;

  JszlibDeflateBenchmark() : super('jszlib deflate', emitter: _emitter);

  void setup() {
    data = _createData(100000);
  }

  void run() {
    ZlibResult result = Zlib.deflate(data);
  }
}

class GitShaBenchmark extends BenchmarkBase {
  List data;

  GitShaBenchmark() : super('git sha', emitter: _emitter);

  void setup() {
    data = _createData(100000);
  }

  void run() {
    getShaStringForData(data, 'blob');
  }
}

class PlainShaBenchmark extends BenchmarkBase {
  List data;

  PlainShaBenchmark() : super('plain sha', emitter: _emitter);

  void setup() {
    data = _createData(100000);
  }

  void run() {
    crypto.SHA1 sha = new crypto.SHA1();
    sha.add(data);
    sha.close();
  }
}

class FastShaBenchmark extends BenchmarkBase {
  List data = _createData(100000);

  FastShaBenchmark() : super('fast sha', emitter: _emitter);

  void run() {
    FastSha sha = new FastSha();
    sha.add(data);
    sha.close();
  }
}

List _createData(int size) {
  Uint8List data = new Uint8List(size);
  for (int i = data.length - 1; i >= 0; i--) {
    data[i] = ((i * i) ^ i) & 0xFF;
  }
  return data;
}
