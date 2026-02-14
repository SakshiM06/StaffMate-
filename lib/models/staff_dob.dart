import 'package:flutter/foundation.dart';

class StaffDOB {
  final String staffId;
  final String firstName;
  final String lastName;
  final String initial;
  final String dob;
  final String? department;
  final String? designation;
  final String? email;
  final String? mobile;
  final String? gender;
  final String? age;
  final String? staffName;

  StaffDOB({
    required this.staffId,
    required this.firstName,
    required this.lastName,
    required this.initial,
    required this.dob,
    this.department,
    this.designation,
    this.email,
    this.mobile,
    this.gender,
    this.age,
    this.staffName,
  });

  // Get full name
  String get fullName {
    if (staffName != null && staffName!.isNotEmpty) {
      return staffName!;
    }
    return '$initial $firstName $lastName'.trim();
  }

  factory StaffDOB.fromJson(Map<String, dynamic> json) {
    // Extract name from the JSON
    String firstName = json['firstName']?.toString() ?? '';
    String lastName = json['lastName']?.toString() ?? '';
    String initial = json['initial']?.toString() ?? '';
    String dob = json['dob']?.toString() ?? '';
    
    // Create full name
    String fullName = '$initial $firstName $lastName'.trim();
    if (fullName.isEmpty) {
      fullName = json['name']?.toString() ?? json['staffName']?.toString() ?? '';
    }

    return StaffDOB(
      staffId: json['staffId']?.toString() ?? 
               json['employeeId']?.toString() ?? 
               json['id']?.toString() ?? 
               '',
      firstName: firstName,
      lastName: lastName,
      initial: initial,
      dob: dob,
      department: json['department']?.toString() ?? 
                  json['dept']?.toString() ?? 
                  json['deptName']?.toString(),
      designation: json['designation']?.toString() ?? 
                   json['jobTitle']?.toString() ?? 
                   json['role']?.toString(),
      email: json['email']?.toString() ?? 
             json['emailId']?.toString(),
      mobile: json['mobile']?.toString() ?? 
              json['mobileNo']?.toString() ?? 
              json['phone']?.toString(),
      gender: json['gender']?.toString() ?? 
              json['sex']?.toString(),
      age: json['age']?.toString() ?? 
           json['years']?.toString(),
      staffName: fullName,
    );
  }

  static List<StaffDOB> fromJsonList(List<dynamic> jsonList) {
    try {
      debugPrint('=== PARSING STAFF DOB DATA ===');
      debugPrint('Raw JSON list length: ${jsonList.length}');
      debugPrint('First item: ${jsonList.isNotEmpty ? jsonList[0] : "Empty"}');
      
      List<StaffDOB> staffList = [];
      
      for (var item in jsonList) {
        try {
          if (item is Map<String, dynamic>) {
            // Check if this is a direct staff object or nested
            Map<String, dynamic> staffData;
            
            if (item.containsKey('staff') && item['staff'] is Map) {
              staffData = Map<String, dynamic>.from(item['staff'] as Map);
            } else {
              staffData = Map<String, dynamic>.from(item);
            }
            
            // Log the keys for debugging
            debugPrint('Processing staff with keys: ${staffData.keys}');
            
            final staff = StaffDOB.fromJson(staffData);
            debugPrint('Parsed staff: ${staff.fullName} (ID: ${staff.staffId})');
            staffList.add(staff);
          }
        } catch (e) {
          debugPrint('Error parsing staff item: $e');
          debugPrint('Item data: $item');
        }
      }
      
      debugPrint('Successfully parsed ${staffList.length} staff members');
      return staffList;
    } catch (e) {
      debugPrint('Error in fromJsonList: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'staffId': staffId,
      'firstName': firstName,
      'lastName': lastName,
      'initial': initial,
      'dob': dob,
      'department': department,
      'designation': designation,
      'email': email,
      'mobile': mobile,
      'gender': gender,
      'age': age,
      'staffName': staffName,
    };
  }

  // For simpler API response parsing
  static StaffDOB fromApiResponse(Map<String, dynamic> item) {
    return StaffDOB(
      staffId: item['staffId']?.toString() ?? '',
      firstName: item['firstName']?.toString() ?? '',
      lastName: item['lastName']?.toString() ?? '',
      initial: item['initial']?.toString() ?? '',
      dob: item['dob']?.toString() ?? '',
      staffName: '${item['initial'] ?? ''} ${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim(),
    );
  }

  @override
  String toString() {
    return 'StaffDOB{fullName: $fullName, dob: $dob}';
  }
}