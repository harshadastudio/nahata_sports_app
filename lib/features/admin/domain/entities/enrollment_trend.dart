/// One month on the enrollment chart (`GET /dashboard/enrollment-trends`).
class EnrollmentPoint {
  const EnrollmentPoint({required this.label, this.students, this.enquiries});

  /// The month as the server labelled it — displayed verbatim on the x-axis,
  /// so no locale assumption is baked into the chart.
  final String label;

  final int? students;
  final int? enquiries;

  /// A point the server sent with neither series is still a real month; it
  /// plots at zero rather than breaking the line.
  int get studentsValue => students ?? 0;
  int get enquiriesValue => enquiries ?? 0;

  @override
  String toString() =>
      'EnrollmentPoint($label: students=$students, enquiries=$enquiries)';
}

/// The whole series, with the bits the chart needs to scale itself.
class EnrollmentTrend {
  const EnrollmentTrend({this.points = const []});

  final List<EnrollmentPoint> points;

  static const EnrollmentTrend empty = EnrollmentTrend();

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  /// True when every point is zero — the chart then shows its empty state
  /// instead of a pair of flat lines along the axis.
  bool get isAllZero => points.every(
    (point) => point.studentsValue == 0 && point.enquiriesValue == 0,
  );

  int get maxValue {
    var max = 0;
    for (final point in points) {
      if (point.studentsValue > max) max = point.studentsValue;
      if (point.enquiriesValue > max) max = point.enquiriesValue;
    }
    return max;
  }

  int get totalStudents =>
      points.fold(0, (sum, point) => sum + point.studentsValue);

  int get totalEnquiries =>
      points.fold(0, (sum, point) => sum + point.enquiriesValue);

  @override
  String toString() =>
      'EnrollmentTrend(${points.length} months, max $maxValue)';
}
