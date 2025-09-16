// import 'package:http/http.dart';
// import 'package:staff_mate/models/dashboard_data.dart';

import '../models/bed.dart';

class IpdServices {
  static List<Bed> getBeds() {
    return const [
      Bed(
        wardType: "GEN",
        bedNo: "201",
        patientName: "Rahul Sharma",
        ipdNo: "IPD123",
        ageGender: "35/M",
        doctorName: "Dr. Verma",
        category: "General",
        isAvailable: false,
        thirdParty: "Self",
        admissionDate: "2023-10-01",
        colorHex: "0xFF1565C0",
        toBeDischarged: false,
      ),
      Bed(
        wardType: "ICU",
        bedNo: "212",
        patientName: "Aarti Singh",
        ipdNo: "IPD456",
        ageGender: "42/F",
        doctorName: "Dr. Rao",
        category: "Critical",
        isAvailable: false,
        thirdParty: "Self",
        admissionDate: "2023-10-01",
        colorHex: "0xFF1565C0",
        toBeDischarged: false,
      ),
      Bed(
        wardType: "GEN",
        bedNo: "202",
        patientName: "",
        ipdNo: "",
        ageGender: "",
        doctorName: "",
        category: "General",
        isAvailable: true,
        thirdParty: "Self",
        admissionDate: "2023-10-01",
        colorHex: "0xFF1565C0",
        toBeDischarged: false,
      ),
    ];
  }
}


