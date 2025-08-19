import 'package:flutter/foundation.dart';
import '../models/vitals.dart';

class VitalsService {
  VitalsService._();
  static final VitalsService I = VitalsService._();

  final ValueNotifier<List<VitalsEntry>> entries =
      ValueNotifier<List<VitalsEntry>>(<VitalsEntry>[]);

  void save(VitalsEntry v) {
    final copy = List<VitalsEntry>.from(entries.value)..add(v);
    entries.value = copy;
    debugPrint('Saved vitals for ${v.patientName} at ${v.hour}:${v.minute.toString().padLeft(2, '0')}');
  }

  List<VitalsEntry> forPatient(String name) =>
      entries.value.where((e) => e.patientName == name).toList();

  // ✅ Add this missing method
  List<VitalsEntry> getAll() => List.unmodifiable(entries.value);
}
