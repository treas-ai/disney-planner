class Resort {
  const Resort({
    required this.id,
    required this.name,
    required this.country,
    required this.parkIds,
  });

  final String id;
  final String name;
  final String country;
  final List<String> parkIds;
}