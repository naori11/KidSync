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
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      fname: json['fname'],
      mname: json['mname'],
      lname: json['lname'],
      address: json['address'],
      birthday: json['birthday'],
      gradeLevel: json['grade_level']?.toString(),
      sectionId: json['section_id'],
      gender: json['gender'],
      status: json['status'],
      rfidUid: json['rfid_uid'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Helper getters for display
  String get fullName {
    if (mname != null && mname!.isNotEmpty) {
      return '$fname $mname $lname';
    }
    return '$fname $lname';
  }

  String get studentId => 'STU${id.toString().padLeft(3, '0')}';

  String get classSection {
    if (gradeLevel != null && sectionId != null) {
      return 'Grade $gradeLevel - Section $sectionId';
    } else if (gradeLevel != null) {
      return 'Grade $gradeLevel';
    }
    return 'No class assigned';
  }

  // Generate placeholder image URL (you can replace this with actual student photos later)
  String get imageUrl => 'https://i.pravatar.cc/150?u=$id';
}

// Fetcher class to include database fields
class Fetcher {
  final int id;
  final String name;
  final String imageUrl;
  final String relationship;
  final String contact;
  final String email;
  final bool authorized;
  final bool isPrimary;

  Fetcher({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.relationship,
    required this.contact,
    required this.email,
    this.authorized = true,
    this.isPrimary = false,
  });

  factory Fetcher.fromParentData(
    Map<String, dynamic> parentData,
    Map<String, dynamic> relationshipData,
  ) {
    final parentInfo = parentData;
    final fullName = '${parentInfo['fname']} ${parentInfo['lname']}';

    return Fetcher(
      id: parentInfo['id'],
      name: fullName,
      imageUrl:
          'https://i.pravatar.cc/150?u=${parentInfo['id']}', // Placeholder image
      relationship: relationshipData['relationship_type'] ?? 'Parent',
      contact: parentInfo['phone'] ?? 'No phone',
      email: parentInfo['email'] ?? 'No email',
      authorized: true, // All parents in database are considered authorized
      isPrimary: relationshipData['is_primary'] ?? false,
    );
  }
}

// Activity model for Recent Activity page
class Activity {
  final String time;
  final String studentName;
  final String gradeClass;
  final String status;
  final String reason;
  final DateTime timestamp;

  Activity({
    required this.time,
    required this.studentName,
    required this.gradeClass,
    required this.status,
    required this.reason,
    required this.timestamp,
  });
}

// Navigation item model
class NavItem {
  final String label;
  final IconData icon;

  NavItem(this.label, this.icon);
}