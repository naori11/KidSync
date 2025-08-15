import 'package:flutter/material.dart';

// Student model to match your database structure
class Student {
  final int id;
  final String fname;
  final String? mname;
  final String lname;
  final String address;
  final String? birthday;
  final String? gradeLevel;
  final int? sectionId;
  final String? gender;
  final String? status;
  final String? rfidUid;
  final String? profileImageUrl; // Add this field
  final String? sectionName;
  final DateTime? createdAt;

  Student({
    required this.id,
    required this.fname,
    this.mname,
    required this.lname,
    required this.address,
    this.birthday,
    this.gradeLevel,
    this.sectionId,
    this.gender,
    this.status,
    this.rfidUid,
    this.profileImageUrl, // Add this parameter
    this.sectionName,
    this.createdAt,
  });

  // Add getter for image URL with fallback
  String get imageUrl {
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return profileImageUrl!;
    }
    // Return a default placeholder URL or empty string
    return '';
  }

  String get fullName {
    if (mname != null && mname!.isNotEmpty) {
      return '$fname $mname $lname';
    }
    return '$fname $lname';
  }

  String get studentId => 'STU${id.toString().padLeft(6, '0')}';

  String get classSection {
    if (sectionName != null) {
      return sectionName!;
    }
    return gradeLevel ?? 'Unknown';
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as int,
      fname: json['fname'] as String,
      mname: json['mname'] as String?,
      lname: json['lname'] as String,
      address: json['address'] as String,
      birthday: json['birthday'] as String?,
      gradeLevel: json['grade_level'] as String?,
      sectionId: json['section_id'] as int?,
      gender: json['gender'] as String?,
      status: json['status'] as String?,
      rfidUid: json['rfid_uid'] as String?,
      profileImageUrl: json['profile_image_url'] as String?, // Add this line
      sectionName: json['sections']?['name'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }
}

// Update or ensure your Fetcher class looks like this:
class Fetcher {
  final int id;
  final String name;
  final String relationship;
  final String contact;
  final String email;
  final String address;
  final String imageUrl;
  final bool isPrimary;

  Fetcher({
    required this.id,
    required this.name,
    required this.relationship,
    required this.contact,
    required this.email,
    required this.address,
    required this.imageUrl,
    required this.isPrimary,
  });

  // Factory constructor for creating from parent data
  factory Fetcher.fromParentData(
    Map<String, dynamic> parentData,
    Map<String, dynamic> relationshipData,
  ) {
    return Fetcher(
      id: parentData['id'],
      name: '${parentData['fname']} ${parentData['mname'] ?? ''} ${parentData['lname']}'.trim(),
      relationship: relationshipData['relationship_type'] ?? 'Parent',
      contact: parentData['phone'] ?? '',
      email: parentData['email'] ?? '',
      address: parentData['address'] ?? '',
      imageUrl: '', // Will be set separately if needed
      isPrimary: relationshipData['is_primary'] ?? false,
    );
  }

  // Factory constructor from JSON (if needed for other uses)
  factory Fetcher.fromJson(Map<String, dynamic> json) {
    return Fetcher(
      id: json['id'],
      name: json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      contact: json['contact'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      isPrimary: json['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'contact': contact,
      'email': email,
      'address': address,
      'imageUrl': imageUrl,
      'isPrimary': isPrimary,
    };
  }
}

// Activity model for Recent Activity page
class Activity {
  final String time;
  final String studentName;
  final String gradeClass;
  final String status;
  final String reason;
  final String verifiedBy;
  final String action;
  final String? tempFetcherName;
  final String? tempFetcherRelationship;
  final String? tempFetcherPin;
  final DateTime? timestamp;

  Activity({
    required this.time,
    required this.studentName,
    required this.gradeClass,
    required this.status,
    required this.reason,
    required this.verifiedBy,
    required this.action,
    this.tempFetcherName,
    this.tempFetcherRelationship,
    this.tempFetcherPin,
    this.timestamp,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    // Parse temporary fetcher data from verified_by field
    String? tempName;
    String? tempRelationship;
    String? tempPin;
    
    final verifiedBy = json['verified_by'] ?? '';
    if (verifiedBy.contains('Temporary Fetcher:')) {
      // Extract temporary fetcher name
      final nameMatch = RegExp(r'Temporary Fetcher: ([^,\n]+)').firstMatch(verifiedBy);
      tempName = nameMatch?.group(1)?.trim();
    }
    
    // Parse from notes field for additional details
    final notes = json['notes'] ?? '';
    if (notes.contains('Temporary fetcher verification')) {
      // Extract PIN
      final pinMatch = RegExp(r'PIN: (\d+)').firstMatch(notes);
      tempPin = pinMatch?.group(1);
      
      // Extract relationship
      final relationshipMatch = RegExp(r'Relationship: ([^,\n]+)').firstMatch(notes);
      tempRelationship = relationshipMatch?.group(1)?.trim();
    }

    // Parse student information
    final student = json['students'];
    final studentName = student != null
        ? '${student['fname']} ${student['mname'] ?? ''} ${student['lname']}'.trim()
        : 'Unknown Student';

    final gradeLevel = student?['grade_level'] ?? '';
    final sectionId = student?['section_id'];
    final gradeClass = gradeLevel.isNotEmpty ? gradeLevel : 'Unknown Class';

    // Format time
    final scanTime = DateTime.parse(json['scan_time']);
    final timeFormatted = 
        "${scanTime.hour.toString().padLeft(2, '0')}:${scanTime.minute.toString().padLeft(2, '0')}";

    // Map action to status
    String status;
    switch (json['action']) {
      case 'entry':
        status = 'Entry Recorded';
        break;
      case 'exit':
        status = 'Checked Out';
        break;
      case 'denied':
        status = 'Pickup Denied';
        break;
      default:
        status = json['status'] ?? 'Unknown';
    }

    return Activity(
      time: timeFormatted,
      studentName: studentName,
      gradeClass: gradeClass,
      status: status,
      reason: notes,
      verifiedBy: verifiedBy,
      action: json['action'] ?? '',
      tempFetcherName: tempName,
      tempFetcherRelationship: tempRelationship,
      tempFetcherPin: tempPin,
      timestamp: scanTime,
    );
  }

  bool get isTemporaryFetcher => tempFetcherName != null;
}

// Navigation item model
class NavItem {
  final String label;
  final IconData icon;

  NavItem(this.label, this.icon);
}
