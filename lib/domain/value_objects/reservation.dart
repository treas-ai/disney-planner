import '../enums/reservation_type.dart';

class Reservation {
  const Reservation({required this.type, this.time});

  final ReservationType type;
  final DateTime? time;

  bool get isRequired => type != ReservationType.none;
}
