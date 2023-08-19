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
    required this.patientBalance
  
});

 
  factory Patient.fromJson(Map<String, dynamic> json) {
  
    DateTime parseAdmissionDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) {
        return DateTime.now();
      }
      try {
        final format = DateFormat('dd-MM-yyyy HH:mm:ss');
        return format.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    return Patient(
      patientname: json['patient_name'] as String? ?? 'N/A',
      ipdNo: json['ipdabrivationid'] as String? ?? 'N/A',
      uhid: json['uhid'] as String? ?? 'N/A',
      dob: json['dob'] as String? ?? 'N/A',
      gender: json['gender'] as String? ?? 'N/A',
      party: json['whopay'] as String? ?? 'N/A',
      practitionername: json['practitioner_name'] as String? ?? 'N/A',
      admissionDateTime: parseAdmissionDate(json['admissiondate'] as String?),
      age: json['age'] as int? ?? 0,
      ward: json['wardname'] as String? ?? 'N/A',
      bedname: json['bedname'] as String? ?? 'N/A',
      diagnosis: json['diagnosis'] as String? ?? 'N/A',
      scdNo: json['scdNo'] as String? ?? 'N/A',
      dischargeStatus: json['discharge_status'] as String? ?? '0',
      isMlc: json['is_mlc'] as String? ?? '0',
      patientBalance: json['patient_balance'] as num? ?? 0,
    );
  }
}