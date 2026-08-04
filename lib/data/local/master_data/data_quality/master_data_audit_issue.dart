enum MasterDataAuditSeverity { error, warning, information }

class MasterDataAuditIssue {
  const MasterDataAuditIssue({
    required this.severity,
    required this.code,
    required this.location,
    required this.message,
  });

  final MasterDataAuditSeverity severity;
  final String code;
  final String location;
  final String message;
}
