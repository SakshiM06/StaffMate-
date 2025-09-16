import 'package:intl/intl.dart';

class Patient {
  final String patientname;
  final String ipdNo;
  final String uhid;
  final String dob;
  final int age;
  final String gender;
  final String party;
  final String practitionername;
  final String ward;
  final String bedname;
  final DateTime admissionDateTime;
  final String diagnosis;
  final String scdNo;
  final String dischargeStatus;
  final String isMlc;
  final num patientBalance;

  Patient({
    required this.patientname,
    required this.ipdNo,
    required this.uhid,
    required this.dob,
    required this.age,
    required this.gender,
    required this.party,
    required this.practitionername,
    required this.ward,
    required this.bedname,
    required this.admissionDateTime,
    required this.diagnosis,
    required this.scdNo,
    required this.dischargeStatus,
    required this.isMlc,
    required this.patientBalance,
  });

  /// Safe parser for admission date
  static DateTime _parseAdmissionDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Try dd-MM-yyyy HH:mm:ss
      final format = DateFormat('dd-MM-yyyy HH:mm:ss');
      return format.parse(dateStr);
    } catch (_) {
      try {
        // Try yyyy-MM-dd
        final format = DateFormat('yyyy-MM-dd');
        return format.parse(dateStr);
      } catch (_) {
        try {
          // Try ISO8601
          return DateTime.parse(dateStr);
        } catch (_) {
          // Fallback to now
          return DateTime.now();
        }
      }
    }
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      patientname: json['patient_name']?.toString() ?? 'N/A',
      ipdNo: json['ipdabrivationid']?.toString() ?? 'N/A',
      uhid: json['uhid']?.toString() ?? 'N/A',
      dob: json['dob']?.toString() ?? 'N/A',
      age: json['age'] is int
          ? json['age']
          : int.tryParse(json['age']?.toString() ?? '') ?? 0,
      gender: json['gender']?.toString() ?? 'N/A',
      party: json['whopay']?.toString() ?? 'N/A',
      practitionername: json['practitioner_name']?.toString() ?? 'N/A',
      ward: json['wardname']?.toString() ?? 'N/A',
      bedname: json['bedname']?.toString() ?? 'N/A',
      admissionDateTime:
          _parseAdmissionDate(json['admissiondate']?.toString()),
      diagnosis: json['diagnosis']?.toString() ?? 'N/A',
      scdNo: json['scdNo']?.toString() ?? 'N/A',
      dischargeStatus: json['discharge_status']?.toString() ?? '0',
      isMlc: json['is_mlc']?.toString() ?? '0',
      patientBalance:
          num.tryParse(json['patient_balance']?.toString() ?? '') ?? 0,
    );
  }

  /// Convert back to JSON (optional for posting data)
  Map<String, dynamic> toJson() {
    return {
      "patient_name": patientname,
      "ipdabrivationid": ipdNo,
      "uhid": uhid,
      "dob": dob,
      "age": age,
      "gender": gender,
      "whopay": party,
      "practitioner_name": practitionername,
      "wardname": ward,
      "bedname": bedname,
      "admissiondate": admissionDateTime.toIso8601String(),
      "diagnosis": diagnosis,
      "scdNo": scdNo,
      "discharge_status": dischargeStatus,
      "is_mlc": isMlc,
      "patient_balance": patientBalance,
    };
  }
}
