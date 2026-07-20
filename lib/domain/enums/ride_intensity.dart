enum RideIntensity {
  veryLow('とても低い'),
  low('低い'),
  medium('普通'),
  high('高い'),
  veryHigh('とても高い');

  const RideIntensity(this.label);

  final String label;
}
