enum PriorityLevel {
  lowest('最低', 1, '★☆☆☆☆'),
  low('低', 2, '★★☆☆☆'),
  medium('普通', 3, '★★★☆☆'),
  high('高', 4, '★★★★☆'),
  highest('最高', 5, '★★★★★');

  const PriorityLevel(this.label, this.value, this.stars);

  final String label;
  final int value;
  final String stars;
}
