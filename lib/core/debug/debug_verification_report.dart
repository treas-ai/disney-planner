import 'package:flutter/foundation.dart';

enum DebugVerificationGateStatus { pass, check }

@immutable
class DebugVerificationGate {
  const DebugVerificationGate({
    required this.name,
    required this.status,
    this.detail,
  });

  final String name;
  final DebugVerificationGateStatus status;
  final String? detail;
}

/// Shared debug-only verification payload for manual runtime checks.
///
/// Production features must not depend on this class for behavior. UI that
/// exposes these reports must be guarded by [kDebugMode].
@immutable
class DebugVerificationReport {
  const DebugVerificationReport({
    required this.feature,
    required this.action,
    required this.lines,
    required this.gates,
  });

  final String feature;
  final String action;
  final List<String> lines;
  final List<DebugVerificationGate> gates;

  bool get passed =>
      gates.isNotEmpty &&
      gates.every((gate) => gate.status == DebugVerificationGateStatus.pass);

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('=== $feature Verification ===')
      ..writeln('Action: $action');
    for (final line in lines) {
      buffer.writeln(line);
    }
    for (final gate in gates) {
      buffer.write('${gate.name}: ');
      buffer.write(
        gate.status == DebugVerificationGateStatus.pass ? 'YES' : 'CHECK',
      );
      if (gate.detail != null && gate.detail!.isNotEmpty) {
        buffer.write(' (${gate.detail})');
      }
      buffer.writeln();
    }
    buffer.write('RESULT: ${passed ? 'PASS' : 'CHECK'}');
    return buffer.toString();
  }
}
