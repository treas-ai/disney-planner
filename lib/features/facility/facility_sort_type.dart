enum FacilitySortType {
  areaOrder(label: 'エリア順'),
  nameOrder(label: '施設名順'),
  categoryOrder(label: 'カテゴリ順'),
  operatingStatusOrder(label: '営業状態順'),
  selectedFirst(label: '選択済みを先頭');

  const FacilitySortType({required this.label});

  final String label;
}
