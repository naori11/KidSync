/// Static pickup status data that would be shared with parents
/// This simulates the static pickup information that parents would see
class PickupStatus {
  final String studentId;
  final String studentName;
  final DateTime pickupTime;
  final String driverName;
  final String vehicleNumber;
  final String schoolName;
  final bool isPickedUp;

  const PickupStatus({
    required this.studentId,
    required this.studentName,
    required this.pickupTime,
    required this.driverName,
    required this.vehicleNumber,
    required this.schoolName,
    this.isPickedUp = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'pickupTime': pickupTime.toIso8601String(),
      'driverName': driverName,
      'vehicleNumber': vehicleNumber,
      'schoolName': schoolName,
      'isPickedUp': isPickedUp,
    };
  }

  factory PickupStatus.fromJson(Map<String, dynamic> json) {
    return PickupStatus(
      studentId: json['studentId'],
      studentName: json['studentName'],
      pickupTime: DateTime.parse(json['pickupTime']),
      driverName: json['driverName'],
      vehicleNumber: json['vehicleNumber'],
      schoolName: json['schoolName'],
      isPickedUp: json['isPickedUp'] ?? true,
    );
  }

  /// Creates a pickup status from a student and driver information
  factory PickupStatus.fromPickup({
    required String studentId,
    required String studentName,
    required DateTime pickupTime,
    required String driverName,
    required String vehicleNumber,
    required String schoolName,
  }) {
    return PickupStatus(
      studentId: studentId,
      studentName: studentName,
      pickupTime: pickupTime,
      driverName: driverName,
      vehicleNumber: vehicleNumber,
      schoolName: schoolName,
      isPickedUp: true,
    );
  }
}

/// Static storage for pickup statuses that would typically be sent to a backend
/// or shared with the parents app
class StaticPickupStatusStorage {
  static final List<PickupStatus> _pickupStatuses = [];

  /// Add a new pickup status
  static void addPickupStatus(PickupStatus status) {
    // Remove any existing status for the same student and date
    _pickupStatuses.removeWhere(
      (s) =>
          s.studentId == status.studentId &&
          _isSameDay(s.pickupTime, status.pickupTime),
    );

    _pickupStatuses.add(status);
  }

  /// Get pickup status for a specific student on a specific day
  static PickupStatus? getPickupStatus(String studentId, DateTime date) {
    try {
      return _pickupStatuses.firstWhere(
        (status) =>
            status.studentId == studentId &&
            _isSameDay(status.pickupTime, date),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all pickup statuses for a specific date
  static List<PickupStatus> getPickupStatusesForDate(DateTime date) {
    return _pickupStatuses
        .where((status) => _isSameDay(status.pickupTime, date))
        .toList();
  }

  /// Get all pickup statuses for a specific student
  static List<PickupStatus> getPickupStatusesForStudent(String studentId) {
    return _pickupStatuses
        .where((status) => status.studentId == studentId)
        .toList();
  }

  /// Get recent pickup statuses (last 7 days)
  static List<PickupStatus> getRecentPickupStatuses() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return _pickupStatuses
        .where((status) => status.pickupTime.isAfter(sevenDaysAgo))
        .toList();
  }

  /// Clear all pickup statuses (for testing)
  static void clearAll() {
    _pickupStatuses.clear();
  }

  /// Get all pickup statuses
  static List<PickupStatus> getAllStatuses() {
    return List.unmodifiable(_pickupStatuses);
  }

  /// Check if student was picked up today
  static bool wasPickedUpToday(String studentId) {
    final today = DateTime.now();
    return getPickupStatus(studentId, today) != null;
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Sample static data for demonstration
  static void loadSampleData() {
    clearAll();

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Sample pickup statuses
    final sampleStatuses = [
      PickupStatus.fromPickup(
        studentId: 'std_001',
        studentName: 'Emma Johnson',
        pickupTime: today.copyWith(hour: 15, minute: 35),
        driverName: 'John Smith',
        vehicleNumber: 'BB-001',
        schoolName: 'Greenwood Elementary',
      ),
      PickupStatus.fromPickup(
        studentId: 'std_002',
        studentName: 'Michael Chen',
        pickupTime: today.copyWith(hour: 15, minute: 37),
        driverName: 'John Smith',
        vehicleNumber: 'BB-001',
        schoolName: 'Greenwood Elementary',
      ),
      PickupStatus.fromPickup(
        studentId: 'std_004',
        studentName: 'James Wilson',
        pickupTime: yesterday.copyWith(hour: 16, minute: 5),
        driverName: 'John Smith',
        vehicleNumber: 'BB-001',
        schoolName: 'Oak Valley Middle School',
      ),
    ];

    for (final status in sampleStatuses) {
      addPickupStatus(status);
    }
  }
}
