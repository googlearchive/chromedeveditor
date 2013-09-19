
library spark_test;

import 'spark.dart' as spark;
import 'test/all.dart' as all_tests;

void main() {
  SparkTest app = new SparkTest();

  app.runTests();
}

class SparkTest extends spark.Spark {
  void runTests() => all_tests.runTests();
}
