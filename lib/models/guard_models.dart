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

// Fetcher class to include database fields
class Fetcher {
  final int id;
  final String name;
  final String contact;
  final String address;
  final String relationship;
  final bool isPrimary;
  final String imageUrl;

  Fetcher({
    required this.id,
    required this.name,
    required this.contact,
    required this.address,
    required this.relationship,
    required this.isPrimary,
    required this.imageUrl,
  });

  factory Fetcher.fromParentData(
    Map<String, dynamic> parentData,
    Map<String, dynamic> relationshipData,
  ) {
    final fname = parentData['fname'] ?? '';
    final mname = parentData['mname'] ?? '';
    final lname = parentData['lname'] ?? '';
    final fullName = '$fname $mname $lname'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // Extract profile image URL from nested users data - Fixed approach
    String profileImageUrl = '';
    try {
      // The users data comes as an array from the join
      if (parentData['users'] != null) {
        if (parentData['users'] is List &&
            (parentData['users'] as List).isNotEmpty) {
          final userData = (parentData['users'] as List)[0];
          if (userData is Map<String, dynamic>) {
            profileImageUrl = userData['profile_image_url'] ?? '';
          }
        } else if (parentData['users'] is Map<String, dynamic>) {
          // Sometimes it might come as a direct object
          profileImageUrl = parentData['users']['profile_image_url'] ?? '';
        }
      }
    } catch (e) {
      print('Error extracting profile image URL: $e');
      profileImageUrl = '';
    }

    return Fetcher(
      id: parentData['id'],
      name: fullName,
      contact: parentData['phone'] ?? parentData['email'] ?? 'No contact',
      address: parentData['address'] ?? 'No address provided',
      relationship: relationshipData['relationship_type'] ?? 'Guardian',
      isPrimary: relationshipData['is_primary'] ?? false,
      imageUrl: profileImageUrl,
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

  factory Activity.fromJson(Map<String, dynamic> json) {
    final scanTime = DateTime.parse(json['scan_time']);
    final student = json['students'];

    // Build grade/class information
    String gradeClass = '';
    if (student != null) {
      final gradeLevel = student['grade_level']?.toString() ?? '';
      final sectionId = student['section_id'];
      if (gradeLevel.isNotEmpty) {
        gradeClass = gradeLevel;
        if (sectionId != null) {
          gradeClass += ' - Section $sectionId';
        }
      }
    }

    // Build student name
    String studentName = 'Unknown';
    if (student != null) {
      final fname = student['fname'] ?? '';
      final mname = student['mname'] ?? '';
      final lname = student['lname'] ?? '';
      studentName = '$fname ${mname.isNotEmpty ? '$mname ' : ''}$lname'.trim();
    }

    // Determine status based on action and status fields
    String statusMessage;
    final action = (json['action'] ?? '').toString().toLowerCase();
    final dbStatus = (json['status'] ?? '').toString().toLowerCase();

    switch (action) {
      case 'entry':
        statusMessage = "Entry Recorded";
        break;
      case 'exit':
        // For exit actions, check the status field or verified_by to determine if approved
        if (dbStatus.contains('checked out') ||
            json['verified_by'] == 'parent') {
          statusMessage = "Pickup Approved";
        } else {
          statusMessage = "Checked Out";
        }
        break;
      case 'denied':
        statusMessage = "Pickup Denied";
        break;
      case 'approved':
        statusMessage = "Pickup Approved";
        break;
      default:
        statusMessage = "Activity";
        break;
    }

    return Activity(
      time:
          "${scanTime.hour.toString().padLeft(2, '0')}:${scanTime.minute.toString().padLeft(2, '0')}",
      studentName: studentName,
      gradeClass: gradeClass,
      status: statusMessage,
      reason: json['notes'] ?? '',
      timestamp: scanTime,
    );
  }
}

// Navigation item model
class NavItem {
  final String label;
  final IconData icon;

  NavItem(this.label, this.icon);
}
