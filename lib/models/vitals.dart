// models/vitals.dart
class VitalsEntry {
  final String patientName;
  final DateTime date;
  final int hour;
  final int minute;
  final String tempF;
  final String hr;
  final String rr;
  final String sysBp;
  final String diaBp;
  final String rbs;
  final String spo2;

  VitalsEntry({
    required this.patientName,
    required this.date,
    required this.hour,
    required this.minute,
    required this.tempF,
    required this.hr,
    required this.rr,
    required this.sysBp,
    required this.diaBp,
    required this.rbs,
    required this.spo2,
  });
}