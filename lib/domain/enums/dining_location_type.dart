enum DiningLocationType {
  inPark('パーク内'),
  disneyHotel('ディズニーホテル'),
  resortArea('リゾート内'),
  external('リゾート外');

  const DiningLocationType(this.label);
  final String label;
}
