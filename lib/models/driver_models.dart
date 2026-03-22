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
  final int? studentDbId; // Database ID for the student
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

// Static data for demonstration
class StaticDriverData {
  static const driverInfo = DriverInfo(
    id: 'driver_001',
    name: 'John Smith',
    vehicleNumber: 'BB-001',
    phoneNumber: '+1234567890',
  );

  static final List<PickupTask> monthlyTasks = [
    PickupTask(
      id: 'task_001',
      date: DateTime(2024, 1, 15),
      schoolName: 'Sunny Hills Elementary School',
      pickupTime: '3:30 PM',
      students: [
        Student(id: 'std_001', name: 'Emma Williams', grade: 'Grade 2'),
        Student(id: 'std_002', name: 'Liam Johnson', grade: 'Grade 4'),
        Student(id: 'std_003', name: 'Sofia Martinez', grade: 'Grade 1'),
      ],
    ),
    PickupTask(
      id: 'task_002',
      date: DateTime(2024, 1, 16),
      schoolName: 'Bright Stars Preschool',
      pickupTime: '2:45 PM',
      students: [
        Student(id: 'std_004', name: 'Noah Brown', grade: 'Preschool'),
        Student(id: 'std_005', name: 'Ava Garcia', grade: 'Pre-K'),
      ],
    ),
    PickupTask(
      id: 'task_003',
      date: DateTime(2024, 1, 17),
      schoolName: 'Rainbow Elementary School',
      pickupTime: '3:15 PM',
      students: [
        Student(id: 'std_006', name: 'Oliver Davis', grade: 'Grade 6'),
        Student(id: 'std_007', name: 'Isabella Chen', grade: 'Grade 5'),
        Student(id: 'std_008', name: 'Mason Rodriguez', grade: 'Grade 6'),
        Student(id: 'std_009', name: 'Mia Thompson', grade: 'Grade 3'),
      ],
    ),
    PickupTask(
      id: 'task_004',
      date: DateTime(2024, 1, 18),
      schoolName: 'Sunny Hills Elementary School',
      pickupTime: '3:30 PM',
      students: [
        Student(id: 'std_001', name: 'Emma Williams', grade: 'Grade 2'),
        Student(id: 'std_010', name: 'Ethan Wilson', grade: 'Grade 3'),
      ],
    ),
    PickupTask(
      id: 'task_005',
      date: DateTime(2024, 1, 19),
      schoolName: 'Little Sprouts Kindergarten',
      pickupTime: '3:00 PM',
      students: [
        Student(
          id: 'std_011',
          name: 'Charlotte Anderson',
          grade: 'Kindergarten',
        ),
        Student(id: 'std_012', name: 'Lucas White', grade: 'Kindergarten'),
        Student(id: 'std_013', name: 'Amelia Taylor', grade: 'Kindergarten'),
      ],
    ),
    PickupTask(
      id: 'task_006',
      date: DateTime(2024, 1, 22),
      schoolName: 'Pine Valley Elementary School',
      pickupTime: '3:20 PM',
      students: [
        Student(id: 'std_014', name: 'Benjamin Miller', grade: 'Grade 2'),
        Student(id: 'std_015', name: 'Harper Lee', grade: 'Grade 4'),
      ],
    ),
    PickupTask(
      id: 'task_007',
      date: DateTime(2024, 1, 23),
      schoolName: 'Rainbow Elementary School',
      pickupTime: '3:15 PM',
      students: [
        Student(id: 'std_016', name: 'Elijah Jones', grade: 'Grade 5'),
        Student(id: 'std_017', name: 'Luna Garcia', grade: 'Grade 1'),
        Student(id: 'std_018', name: 'Jackson Smith', grade: 'Grade 6'),
      ],
    ),
    PickupTask(
      id: 'task_008',
      date: DateTime(2024, 1, 24),
      schoolName: 'Bright Stars Preschool',
      pickupTime: '2:45 PM',
      students: [
        Student(id: 'std_019', name: 'Zoe Clark', grade: 'Pre-K'),
        Student(id: 'std_020', name: 'Aiden Hall', grade: 'Preschool'),
      ],
    ),
    PickupTask(
      id: 'task_009',
      date: DateTime(2024, 1, 25),
      schoolName: 'Sunny Hills Elementary School',
      pickupTime: '3:30 PM',
      students: [
        Student(id: 'std_021', name: 'Grace Turner', grade: 'Grade 3'),
        Student(id: 'std_022', name: 'Henry Young', grade: 'Grade 1'),
        Student(id: 'std_023', name: 'Lily Adams', grade: 'Grade 4'),
      ],
    ),
  ];

  static PickupTask? getTodaysTask() {
    final today = DateTime.now();
    try {
      return monthlyTasks.firstWhere(
        (task) =>
            task.date.year == today.year &&
            task.date.month == today.month &&
            task.date.day == today.day,
      );
    } catch (e) {
      // Return a default task if no task found for today
      return PickupTask(
        id: 'default_today',
        date: today,
        schoolName: 'Sunny Hills Elementary School',
        pickupTime: '3:30 PM',
        students: [
          Student(id: 'std_default1', name: 'Emma Williams', grade: 'Grade 2'),
          Student(id: 'std_default2', name: 'Liam Johnson', grade: 'Grade 4'),
        ],
      );
    }
  }

  static List<PickupTask> getUpcomingTasks({int limit = 5}) {
    final now = DateTime.now();
    return monthlyTasks
        .where((task) => task.date.isAfter(now))
        .take(limit)
        .toList();
  }

  static List<PickupTask> getTasksByDateRange(DateTime start, DateTime end) {
    return monthlyTasks
        .where(
          (task) =>
              task.date.isAfter(start.subtract(const Duration(days: 1))) &&
              task.date.isBefore(end.add(const Duration(days: 1))),
        )
        .toList();
  }
}

// Database models for driver functionality

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
    try {
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
    } catch (e) {
      print('Error in DriverAssignment.fromJson: $e');
      print('JSON: $json');
      rethrow;
    }
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
    try {
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
    } catch (e) {
      print('Error in StudentDb.fromJson: $e');
      print('JSON: $json');
      rethrow;
    }
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
    try {
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
    } catch (e) {
      print('Error in SectionDb.fromJson: $e');
      print('JSON: $json');
      rethrow;
    }
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
