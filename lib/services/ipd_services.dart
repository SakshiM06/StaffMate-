// import 'package:flutter/foundation.dart';
// import 'package:staff_mate/models/bed.dart';

// class IPDService {
//   IPDService._();
//   static final IPDService I = IPDService._();

//   // seed data
//   final ValueNotifier<List<Bed>> beds = ValueNotifier<List<Bed>>([
//     Bed(
//       wardType: "GEN",
//       bedNo: "201",
//       ipdNo: "(SCD/IP/25/0344)",
//       patientName: "Jayesh Dudure",
//       ageGender: "22Y 9M 29D / Male",
//       thirdParty: "",
//       admissionDate: "08-06-2025 11:12:16",
//       doctorName: "Rohit Hatwar",
//       colorHex: "0xFFB3B333",
//       category: "Self",
//       toBeDischarged: true,
//     ),
//     Bed(
//       wardType: "ICU",
//       bedNo: "212",
//       ipdNo: "(SCD/IP/25/0347)",
//       patientName: "Pratik Das",
//       ageGender: "34Y 10M 9D / Male",
//       thirdParty: "CGHS Kolkata",
//       admissionDate: "04-07-2025 12:39:53",
//       doctorName: "Meghnaa A",
//       colorHex: "0xFF4CAF50",
//       category: "TP",
//     ),
//     Bed(
//       wardType: "Twin Sharing",
//       bedNo: "216",
//       ipdNo: "",
//       patientName: "AVAILABLE BED",
//       ageGender: "",
//       thirdParty: "",
//       admissionDate: "",
//       doctorName: "",
//       colorHex: "0xFF1565C0",
//       isAvailable: true,
//     ),
//   ]);

//   // mutations
//   void addBed(Bed bed) => beds.value = [...beds.value, bed];

//   // counters
//   int get totalBeds => beds.value.length;
//   int get available => beds.value.where((b) => b.isAvailable).length;
//   int get inhousePatients => totalBeds - available;
//   int get self => beds.value.where((b) => b.category == "Self").length;
//   int get mlc => beds.value.where((b) => b.category == "MLC").length;
//   int get tp => beds.value.where((b) => b.category == "TP").length;
//   int get tpCorporate =>
//       beds.value.where((b) => b.category == "TPCorporate").length;
//   int get toBeDischarged =>
//       beds.value.where((b) => b.toBeDischarged && !b.isAvailable).length;
// }
