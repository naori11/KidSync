class PickupTask {
  final String id;
  final DateTime date;
  final String schoolName;
  final String pickupTime;
  final List<Student> students;
  final bool isCompleted;

  const PickupTask({
    required this.id,
    required this.date,
    required this.schoolName,
    required this.pickupTime,
    required this.students,
    this.isCompleted = false,
  });

  int get studentCount => students.length;

  PickupTask copyWith({
    String? id,
    DateTime? date,
    String? schoolName,
    String? pickupTime,
    List<Student>? students,
    bool? isCompleted,
  }) {
    return PickupTask(
      id: id ?? this.id,
      date: date ?? this.date,
      schoolName: schoolName ?? this.schoolName,
      pickupTime: pickupTime ?? this.pickupTime,
      students: students ?? this.students,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class Student {
  final String id;
  final String name;
  final String grade;
  final bool isPickedUp;
  final DateTime? pickupTime;
  final String? driverName;
  final int? studentDbId;
  final String? sectionName;

  const Student({
    required this.id,
    required this.name,
    required this.grade,
    this.isPickedUp = false,
    this.pickupTime,
    this.driverName,
    this.studentDbId,
    this.sectionName,
  });

  Student copyWith({
    String? id,
    String? name,
    String? grade,
    bool? isPickedUp,
    DateTime? pickupTime,
    String? driverName,
    int? studentDbId,
    String? sectionName,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      isPickedUp: isPickedUp ?? this.isPickedUp,
      pickupTime: pickupTime ?? this.pickupTime,
      driverName: driverName ?? this.driverName,
      studentDbId: studentDbId ?? this.studentDbId,
      sectionName: sectionName ?? this.sectionName,
    );
  }
}

class DriverInfo {
  final String id;
  final String name;
  final String vehicleNumber;
  final String phoneNumber;

  const DriverInfo({
    required this.id,
    required this.name,
    required this.vehicleNumber,
    required this.phoneNumber,
  });
}

class DriverAssignment {
  final int id;
  final int studentId;
  final String driverId;
  final String? pickupTime;
  final String? dropoffTime;
  final String? pickupAddress;
  final List<String>? scheduleDays;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final StudentDb? student;

  const DriverAssignment({
    required this.id,
    required this.studentId,
    required this.driverId,
    this.pickupTime,
    this.dropoffTime,
    this.pickupAddress,
    this.scheduleDays,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.student,
  });

  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      driverId: json['driver_id'] ?? '',
      pickupTime: json['pickup_time']?.toString(),
      dropoffTime: json['dropoff_time']?.toString(),
      pickupAddress: json['pickup_address']?.toString(),
      scheduleDays:
          json['schedule_days'] != null
              ? List<String>.from(json['schedule_days'])
              : null,
      status: json['status']?.toString() ?? 'active',
      notes: json['notes']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'].toString())
              : DateTime.now(),
      student:
          json['students'] != null
              ? StudentDb.fromJson(json['students'])
              : null,
    );
  }
}

class StudentDb {
  final int id;
  final String fname;
  final String? mname;
  final String lname;
  final String? gradeLevel;
  final int? sectionId;
  final String? rfidUid;
  final String? profileImageUrl;
  final SectionDb? section;

  const StudentDb({
    required this.id,
    required this.fname,
    this.mname,
    required this.lname,
    this.gradeLevel,
    this.sectionId,
    this.rfidUid,
    this.profileImageUrl,
    this.section,
  });

  factory StudentDb.fromJson(Map<String, dynamic> json) {
    return StudentDb(
      id: json['id'] ?? 0,
      fname: json['fname']?.toString() ?? '',
      mname: json['mname']?.toString(),
      lname: json['lname']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString(),
      sectionId: json['section_id'],
      rfidUid: json['rfid_uid']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      section:
          json['sections'] != null
              ? SectionDb.fromJson(json['sections'])
              : null,
    );
  }
}

class SectionDb {
  final int id;
  final String name;
  final String gradeLevel;
  final String? teacherId;
  final String? schedule;
  final DateTime createdAt;
  final bool isTesting;

  const SectionDb({
    required this.id,
    required this.name,
    required this.gradeLevel,
    this.teacherId,
    this.schedule,
    required this.createdAt,
    required this.isTesting,
  });

  factory SectionDb.fromJson(Map<String, dynamic> json) {
    return SectionDb(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      gradeLevel: json['grade_level']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString(),
      schedule: json['schedule']?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now(),
      isTesting: json['is_testing'] ?? false,
    );
  }
}

class PickupDropoffLog {
  final int id;
  final int studentId;
  final String driverId;
  final DateTime? pickupTime;
  final DateTime? dropoffTime;
  final String eventType;
  final String? notes;
  final DateTime createdAt;
  final StudentDb? student;

  const PickupDropoffLog({
    required this.id,
    required this.studentId,
    required this.driverId,
    this.pickupTime,
    this.dropoffTime,
    required this.eventType,
    this.notes,
    required this.createdAt,
    this.student,
  });

  factory PickupDropoffLog.fromJson(Map<String, dynamic> json) {
    return PickupDropoffLog(
      id: json['id'],
      studentId: json['student_id'],
      driverId: json['driver_id'],
      pickupTime:
          json['pickup_time'] != null
              ? DateTime.parse(json['pickup_time'])
              : null,
      dropoffTime:
          json['dropoff_time'] != null
              ? DateTime.parse(json['dropoff_time'])
              : null,
      eventType: json['event_type'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      student:
          json['students'] != null
              ? StudentDb.fromJson(json['students'])
              : null,
    );
  }
}
