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
  final int active;
  final String isPrivateTp;
  final int isUnderMaintenance;
  final int bedid;
  final String admissionId; 
  final String patientid;
  final String practitionerid;
  final String clientId;
final double patientBalanceDouble;

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
    required this.active,
    required this.isPrivateTp,
    required this.isUnderMaintenance,
    required this.bedid,
    required this.admissionId,
    required this.patientid,
    required this.practitionerid,
    required this.clientId,
    required this.patientBalanceDouble,
  });

  // Factory constructor to create Patient from JSON
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
      admissionDateTime: _parseAdmissionDate(json['admissiondate']?.toString()),
      diagnosis: json['diagnosis']?.toString() ?? 'N/A',
      scdNo: json['scdNo']?.toString() ?? 'N/A',
      dischargeStatus: json['discharge_status']?.toString() ?? '0',
      isMlc: json['ismlc']?.toString() ?? '0',
      bedid: json['bedid'] is int
          ? json['bedid']
          : int.tryParse(json['bedid']?.toString() ?? '') ?? 0,
      patientBalance:
          num.tryParse(json['patient_balance']?.toString() ?? '') ?? 0,
      active: int.tryParse(json['active']?.toString() ?? '') ?? 0,
      isPrivateTp: json['isprivatetp']?.toString() ?? '0',
      isUnderMaintenance:
          int.tryParse(json['isUnderMaintainance']?.toString() ?? '') ?? 0,
      admissionId: json['admissionid']?.toString() ?? '0',
      patientid: json['patientid']?.toString() ?? json['clientid']?.toString() ?? '0',
     practitionerid: json['practitionerid']?.toString() ?? '0',
     clientId: json['clientid']?.toString() ?? '0',
      patientBalanceDouble: double.tryParse(json['patient_balance']?.toString() ?? '') ?? 0.0
    );
  }
  String get patientId => patientid;
String get id => patientid; // Alias for compatibility
String get addmissionId => admissionId;
String get ipdNumber => ipdNo;

  // get id => null;

  // get patientId => null;

  // Convert Patient object to JSON
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
      "active": active,
      "isprivatetp": isPrivateTp,
      "isUnderMaintainance": isUnderMaintenance,
      "bedid": bedid,
      "admissionid": admissionId,
      "patientid": patientid,
      "practitionerid": practitionerid,
      "clientId": clientId,
    };
    
  }

  static DateTime _parseAdmissionDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime(1970, 1, 1);
    }
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime(1970, 1, 1);
    }
  }
}
