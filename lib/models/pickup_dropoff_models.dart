class StudentSchedule {
  final int studentId;
  final List<int> classDays;
  final Map<int, TimeRange> classSchedule;

  StudentSchedule({
    required this.studentId,
    required this.classDays,
    required this.classSchedule,
  });
}

class TimeRange {
  final String startTime;
  final String endTime;

  TimeRange({required this.startTime, required this.endTime});
}

class PickupDropoffPattern {
  final int studentId;
  final int dayOfWeek;
  final String dropoffPerson;
  final String pickupPerson;

  PickupDropoffPattern({
    required this.studentId,
    required this.dayOfWeek,
    required this.dropoffPerson,
    required this.pickupPerson,
  });

  factory PickupDropoffPattern.fromJson(Map<String, dynamic> json) {
    return PickupDropoffPattern(
      studentId: json['student_id'],
      dayOfWeek: json['day_of_week'],
      dropoffPerson: json['dropoff_person'],
      pickupPerson: json['pickup_person'],
    );
  }
}

class PickupDropoffException {
  final int studentId;
  final DateTime exceptionDate;
  final String dropoffPerson;
  final String pickupPerson;

  PickupDropoffException({
    required this.studentId,
    required this.exceptionDate,
    required this.dropoffPerson,
    required this.pickupPerson,
  });

  factory PickupDropoffException.fromJson(Map<String, dynamic> json) {
    return PickupDropoffException(
      studentId: json['student_id'],
      exceptionDate: DateTime.parse(json['exception_date']),
      dropoffPerson: json['dropoff_person'],
      pickupPerson: json['pickup_person'],
    );
  }
}
