enum CrowdFactorConfidence {
  low('低'),
  medium('中'),
  high('高');

  const CrowdFactorConfidence(this.label);

  final String label;

  static CrowdFactorConfidence fromName(String? value) {
    return CrowdFactorConfidence.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CrowdFactorConfidence.low,
    );
  }
}
