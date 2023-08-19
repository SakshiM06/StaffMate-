import 'package:flutter/foundation.dart';
import 'package:staff_mate/models/patient.dart';

class OPDService {
  static final OPDService I = OPDService._();
  OPDService._();

  // List of OPD patients
  final ValueNotifier<List<Patient>> patients = ValueNotifier([]);

  // Example stats
  int get totalPatients => patients.value.length;
  // int get newCases => patients.value.where((p) => p.isNew).length;
  // int get followUps => patients.value.where((p) => !p.isNew).length;

  void addPatient(Patient p) {
    patients.value = [...patients.value, p];
  }
}
