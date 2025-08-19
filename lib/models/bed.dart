class Bed {
  final String wardType;
  final String bedNo;
  final String patientName;
  final String ipdNo;
  final String ageGender;
  final String doctorName;
  final String category;
  final bool isAvailable;
  final String thirdParty;
  final String admissionDate;
  final String colorHex;
  final bool toBeDischarged;

  const Bed({
    required this.wardType,
    required this.bedNo,
    required this.patientName,
    required this.ipdNo,
    required this.ageGender,
    required this.doctorName,
    required this.category,
    required this.isAvailable,
    required this.thirdParty,
    required this.admissionDate,
    required this.colorHex,
     required this.toBeDischarged,
  });
}
