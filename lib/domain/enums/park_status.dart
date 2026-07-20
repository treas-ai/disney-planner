enum ParkStatus {
  open('営業中'),
  closed('休止中'),
  temporarilyClosed('一時休止');

  const ParkStatus(this.label);

  final String label;
}
