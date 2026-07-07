class Attraction {
  final int id;
  final String name;
  final String area;
  final int durationMinutes;
  final int priority;
  bool selected;

  Attraction({
    required this.id,
    required this.name,
    required this.area,
    required this.durationMinutes,
    required this.priority,
    required this.selected,
  });

  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['id'],
      name: json['name'],
      area: json['area'],
      durationMinutes: json['durationMinutes'],
      priority: json['priority'],
      selected: json['selected'],
    );
  }
}