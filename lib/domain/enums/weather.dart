enum Weather {
  sunny('晴れ'),
  cloudy('くもり'),
  rainy('雨'),
  storm('荒天');

  const Weather(this.label);

  final String label;
}