class Facility {
  final int id;
  final String type;
  final String name;
  final String area;
  final int durationMinutes;
  final int priority;
  bool selected;

  Facility({
    required this.id,
    required this.type,
    required this.name,
    required this.area,
    required this.durationMinutes,
    required this.priority,
    required this.selected,
  });

  factory Facility.fromJson(Map<String, dynamic> json, String type) {
    return Facility(
      id: json['id'],
      type: type,
      name: json['name'],
      area: json['area'],
      durationMinutes: json['durationMinutes'],
      priority: json['priority'],
      selected: json['selected'],
    );
  }
}