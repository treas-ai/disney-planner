import '../../domain/entities/resort.dart';

class ResortModel {
  const ResortModel._();

  static Resort fromMap(
    Map<String, Object?> map, {
    List<String> parkIds = const [],
  }) {
    return Resort(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      country: map['country'] as String? ?? '',
      parkIds: List.unmodifiable(parkIds),
    );
  }

  static Map<String, Object?> toMap(Resort resort) {
    return {'id': resort.id, 'name': resort.name, 'country': resort.country};
  }
}
