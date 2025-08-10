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

  const Student({
    required this.id,
    required this.name,
    required this.grade,
    this.isPickedUp = false,
    this.pickupTime,
    this.driverName,
  });

  Student copyWith({
    String? id,
    String? name,
    String? grade,
    bool? isPickedUp,
    DateTime? pickupTime,
    String? driverName,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      isPickedUp: isPickedUp ?? this.isPickedUp,
      pickupTime: pickupTime ?? this.pickupTime,
      driverName: driverName ?? this.driverName,
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
      schoolName: 'Greenwood Elementary',
      pickupTime: '3:30 PM',
      students: [
        Student(id: 'std_001', name: 'Emma Johnson', grade: '5th Grade'),
        Student(id: 'std_002', name: 'Michael Chen', grade: '4th Grade'),
        Student(id: 'std_003', name: 'Sofia Rodriguez', grade: '5th Grade'),
      ],
    ),
    PickupTask(
      id: 'task_002',
      date: DateTime(2024, 1, 16),
      schoolName: 'Oak Valley Middle School',
      pickupTime: '4:00 PM',
      students: [
        Student(id: 'std_004', name: 'James Wilson', grade: '7th Grade'),
        Student(id: 'std_005', name: 'Ava Thompson', grade: '6th Grade'),
      ],
    ),
    PickupTask(
      id: 'task_003',
      date: DateTime(2024, 1, 17),
      schoolName: 'Sunrise High School',
      pickupTime: '3:45 PM',
      students: [
        Student(id: 'std_006', name: 'Ethan Davis', grade: '9th Grade'),
        Student(id: 'std_007', name: 'Isabella Garcia', grade: '10th Grade'),
        Student(id: 'std_008', name: 'Noah Martinez', grade: '9th Grade'),
        Student(id: 'std_009', name: 'Mia Anderson', grade: '11th Grade'),
      ],
    ),
    PickupTask(
      id: 'task_004',
      date: DateTime(2024, 1, 18),
      schoolName: 'Greenwood Elementary',
      pickupTime: '3:30 PM',
      students: [
        Student(id: 'std_001', name: 'Emma Johnson', grade: '5th Grade'),
        Student(id: 'std_010', name: 'Liam Brown', grade: '3rd Grade'),
      ],
    ),
    PickupTask(
      id: 'task_005',
      date: DateTime(2024, 1, 19),
      schoolName: 'Oak Valley Middle School',
      pickupTime: '4:00 PM',
      students: [
        Student(id: 'std_011', name: 'Olivia Taylor', grade: '8th Grade'),
        Student(id: 'std_012', name: 'William Lee', grade: '7th Grade'),
        Student(id: 'std_013', name: 'Charlotte White', grade: '6th Grade'),
      ],
    ),
    PickupTask(
      id: 'task_006',
      date: DateTime(2024, 1, 22),
      schoolName: 'Maple Creek Elementary',
      pickupTime: '3:15 PM',
      students: [
        Student(id: 'std_014', name: 'Benjamin Clark', grade: '2nd Grade'),
        Student(id: 'std_015', name: 'Amelia Hall', grade: '4th Grade'),
      ],
    ),
    PickupTask(
      id: 'task_007',
      date: DateTime(2024, 1, 23),
      schoolName: 'Sunrise High School',
      pickupTime: '3:45 PM',
      students: [
        Student(id: 'std_016', name: 'Lucas King', grade: '12th Grade'),
        Student(id: 'std_017', name: 'Harper Scott', grade: '9th Grade'),
        Student(id: 'std_018', name: 'Alexander Young', grade: '11th Grade'),
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
        schoolName: 'Greenwood Elementary',
        pickupTime: '3:30 PM',
        students: [
          Student(id: 'std_default1', name: 'Alex Demo', grade: '3rd Grade'),
          Student(id: 'std_default2', name: 'Sam Demo', grade: '4th Grade'),
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
