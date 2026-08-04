import 'master_data_audit_issue.dart';
import 'master_data_audit_report.dart';

class MasterDataAuditor {
  const MasterDataAuditor({this.staleStatusDays = 90});

  final int staleStatusDays;

  MasterDataAuditReport audit({
    required Map<String, List<Map<String, dynamic>>> facilityRowsByFile,
    DateTime? now,
  }) {
    final auditTime = now ?? DateTime.now();
    final issues = <MasterDataAuditIssue>[];
    final countByPark = <String, int>{};
    final countByCategory = <String, int>{};
    var facilityCount = 0;

    for (final entry in facilityRowsByFile.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final row = entry.value[index];
        final location = '${entry.key}[$index]';
        facilityCount++;

        final parkId = _text(row['parkId']);
        final category = _text(row['category']);

        if (parkId != null) {
          countByPark.update(parkId, (value) => value + 1, ifAbsent: () => 1);
        }

        if (category != null) {
          countByCategory.update(
            category,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }

        _auditDisplayText(row, location, issues);
        _auditOfficialUrl(row, location, issues);
        _auditRestaurant(row, category, location, issues);
        _auditEntertainment(row, category, location, issues);
        _auditOperatingStatus(row, location, auditTime, issues);
      }
    }

    return MasterDataAuditReport(
      generatedAt: auditTime,
      facilityCount: facilityCount,
      countByPark: Map<String, int>.unmodifiable(countByPark),
      countByCategory: Map<String, int>.unmodifiable(countByCategory),
      issues: List<MasterDataAuditIssue>.unmodifiable(issues),
    );
  }

  void _auditDisplayText(
    Map<String, dynamic> row,
    String location,
    List<MasterDataAuditIssue> issues,
  ) {
    final name = _text(row['name']);
    if (name == null) {
      return;
    }

    if (name.contains('_') ||
        name.startsWith('tdl_') ||
        name.startsWith('tds_')) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.error,
          code: 'internal_id_in_display_name',
          location: location,
          message: '表示名に内部IDと思われる文字列が含まれています。',
        ),
      );
    }
  }

  void _auditOfficialUrl(
    Map<String, dynamic> row,
    String location,
    List<MasterDataAuditIssue> issues,
  ) {
    final officialUrl = _text(row['officialUrl']);
    if (officialUrl == null) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'missing_official_url',
          location: location,
          message: '公式URLが未設定です。',
        ),
      );
      return;
    }

    final uri = Uri.tryParse(officialUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'www.tokyodisneyresort.jp') {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'non_official_url',
          location: location,
          message: '公式ドメインのHTTPS URLではありません。',
        ),
      );
    }
  }

  void _auditRestaurant(
    Map<String, dynamic> row,
    String? category,
    String location,
    List<MasterDataAuditIssue> issues,
  ) {
    if (category != 'restaurant') {
      return;
    }

    // Show restaurants are entertainment programs with a bundled meal.
    // The official show page may not provide a standalone menu URL or one
    // representative menu, so those fields are not mandatory here.
    if (row['isShowRestaurant'] == true) {
      return;
    }

    if (_text(row['representativeMenu']) == null) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'missing_representative_menu',
          location: location,
          message: '代表メニューまたは料理ジャンルが未設定です。',
        ),
      );
    }

    if (_text(row['menuUrl']) == null) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'missing_menu_url',
          location: location,
          message: '公式メニューURLが未設定です。',
        ),
      );
    }
  }

  void _auditEntertainment(
    Map<String, dynamic> row,
    String? category,
    String location,
    List<MasterDataAuditIssue> issues,
  ) {
    if (!{'show', 'parade', 'greeting'}.contains(category)) {
      return;
    }

    if ((row['durationMinutes'] as num?)?.toInt() == null) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.information,
          code: 'missing_duration',
          location: location,
          message: '所要時間が未設定です。',
        ),
      );
    }

    final hasDynamicCharacters =
        row['hasDynamicCharacters'] == true ||
        _text(row['characterDisplayName']) == '当日のお楽しみ';

    if (category == 'greeting' &&
        !hasDynamicCharacters &&
        _stringList(row['characterIds']).isEmpty) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'missing_character_reference',
          location: location,
          message: 'キャラクター参照が未設定です。',
        ),
      );
    }
  }

  void _auditOperatingStatus(
    Map<String, dynamic> row,
    String location,
    DateTime now,
    List<MasterDataAuditIssue> issues,
  ) {
    final status = _text(row['operatingStatus']);
    if (status == null || status == 'operating') {
      return;
    }

    final checkedAtText = _text(row['operatingStatusCheckedAt']);
    final checkedAt = checkedAtText == null
        ? null
        : DateTime.tryParse(checkedAtText);

    if (checkedAt == null) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'missing_status_checked_at',
          location: location,
          message: '休止情報の確認日が未設定です。',
        ),
      );
      return;
    }

    if (now.difference(checkedAt).inDays > staleStatusDays) {
      issues.add(
        MasterDataAuditIssue(
          severity: MasterDataAuditSeverity.warning,
          code: 'stale_operating_status',
          location: location,
          message: '休止情報の確認日から$staleStatusDays日以上経過しています。',
        ),
      );
    }
  }

  String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().where((item) => item.isNotEmpty).toList();
  }
}
