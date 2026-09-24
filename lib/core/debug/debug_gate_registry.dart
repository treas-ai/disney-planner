/// DEBUG-only in-memory registry used to aggregate regression evidence across screens.
/// It never drives production planning behavior.
abstract final class DebugGateRegistry {
  static String? lastTodayReplanReport;

  /// Phase F execution-status self-check (completed / skipped).
  static String? lastPhaseFExecutionStatusReport;

  /// Last Phase D application evidence. Kept outside a screen/controller so
  /// Debug Mode can validate an application performed in Plan Review.
  static String? lastPhaseDApplicationReport;
}
