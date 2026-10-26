import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/models/operation_result.dart';

void main() {
  group('OperationResult Tests', () {
    test('OperationResult.success holds data and message', () {
      const res = OperationResult<String>.success('payload_data', 'Operation OK');
      expect(res.isSuccess, isTrue);
      expect(res.isFailure, isFalse);
      expect(res.data, 'payload_data');
      expect(res.message, 'Operation OK');
      expect(res.error, isNull);
      expect(res.statusText, 'Operation OK');
    });

    test('OperationResult.failure holds error and flags isFailure', () {
      const res = OperationResult<int>.failure('Access Denied');
      expect(res.isSuccess, isFalse);
      expect(res.isFailure, isTrue);
      expect(res.data, isNull);
      expect(res.error, 'Access Denied');
      expect(res.statusText, 'Access Denied');
    });
  });
}
