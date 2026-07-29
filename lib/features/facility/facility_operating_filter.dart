enum FacilityOperatingFilter {
  all(label: 'すべて'),
  operatingOnly(label: '営業中'),
  closedOnly(label: '休止中'),
  permanentlyClosedOnly(label: '運営終了');

  const FacilityOperatingFilter({required this.label});

  final String label;
}
