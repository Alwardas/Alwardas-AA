import 'package:flutter/foundation.dart';

/// A utils class to enforce heavy computations on background isolates.
/// "Strictly DO: Flutter Isolates (`compute`)"
class IsolateHelper {
  /// Executes a computationally expensive task in a background isolate.
  /// 
  /// Usage:
  /// ```dart
  /// final result = await IsolateHelper.computeTask(heavyFunction, data);
  /// ```
  static Future<R> computeTask<Q, R>(ComputeCallback<Q, R> callback, Q message) async {
    return await compute(callback, message);
  }
}
