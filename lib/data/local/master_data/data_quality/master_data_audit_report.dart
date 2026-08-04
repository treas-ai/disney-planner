import 'master_data_audit_issue.dart';

class MasterDataAuditReport {
  const MasterDataAuditReport({
    required this.generatedAt,
    required this.facilityCount,
    required this.countByPark,
    required this.countByCategory,
    required this.issues,
  });

  final DateTime generatedAt;
  final int facilityCount;
  final Map<String, int> countByPark;
  final Map<String, int> countByCategory;
  final List<MasterDataAuditIssue> issues;

  int get errorCount => _count(MasterDataAuditSeverity.error);

  int get warningCount => _count(MasterDataAuditSeverity.warning);

  int get informationCount => _count(MasterDataAuditSeverity.information);

  bool get hasErrors => errorCount > 0;

  int _count(MasterDataAuditSeverity severity) {
    return issues.where((issue) => issue.severity == severity).length;
  }
}
