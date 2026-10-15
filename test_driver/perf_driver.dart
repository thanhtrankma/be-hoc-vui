// Driver cho integration_test/perf_test.dart: ghi kết quả đo vào build/perf_<PERF_TAG>.json.
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(responseDataCallback: (data) async {
      if (data == null) return;
      final tag = Platform.environment['PERF_TAG'] ?? 'run';
      final f = File('build/perf_$tag.json');
      await f.create(recursive: true);
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data['perf']));
    });
