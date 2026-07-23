enum WaitTolerance {
  short('短め：15分まで', 15),
  medium('標準：30分まで', 30),
  long('長め：60分まで', 60),
  any('気にしない', null);

  const WaitTolerance(this.label, this.maxMinutes);

  final String label;
  final int? maxMinutes;

  bool get hasLimit {
    return maxMinutes != null;
  }

  bool allows(int waitMinutes) {
    final limit = maxMinutes;

    if (limit == null) {
      return true;
    }

    return waitMinutes <= limit;
  }

  int exceededMinutes(int waitMinutes) {
    final limit = maxMinutes;

    if (limit == null || waitMinutes <= limit) {
      return 0;
    }

    return waitMinutes - limit;
  }
}
