// lib/core/api/api_endpoints.dart
import 'package:staff_mate/APIs/api_host.dart';

/// ALL API Endpoints consolidated from your 11 Flutter files
class ApiEndpoints {
  // ============ FROM ApiService (login) ============
  static String get login => '${ApiHost.loginBaseUrl}security/auth/login';
  
  // ============ FROM IpdService ============
  static String get ipdPatients => '${ApiHost.baseUrl}ipd/patient/all';
  static String get practitionerList => '${ApiHost.smartcaremainUrl}practitionerlist';
  static String get specializationList => '${ApiHost.smartcaremainUrl}clinic/specializationlist';
  static String wardList(String branchId) => '${ApiHost.smartcaremainUrl}clinic/branchwisewardlist/$branchId';
  static String get vitalsMaster => '${ApiHost.baseUrl}ipd/common/get/vitals';
  static String vitalsByType(int vitalType) => '${ApiHost.baseUrl}ipd/common/get/vitals/$vitalType';
  static String get saveVitals => '${ApiHost.baseUrl}ipd/common/save/timewise/vitals';
  static String prescriptionNotification(String admissionId) => '${ApiHost.baseUrl}ipd/patient/getNotification/priscription/$admissionId';
  static String investigationNotification(String admissionId) => '${ApiHost.baseUrl}ipd/patient/getNotification/investigation/$admissionId';
  
  // ============ FROM AddMedicineService ============
  static String get addMedicine => '${ApiHost.smartcaremainUrl}priscriptionmaster/medicinedetails/saveorupdate';
  
  // ============ FROM PackageService ============
  static String get packageExists => '${ApiHost.billingUrl}patientpackage/getPackageIfExists';
  static String get referenceList => '${ApiHost.smartcaremainUrl}refrencelist';
  static String get chargeTypeList => '${ApiHost.billingUrl}charges/chargetype/list';
  static String get masterDetailList => '${ApiHost.billingUrl}charges/master-detail-list';
  static String get createCharge => '${ApiHost.billingUrl}charges/createnew';
  
  // ============ FROM ClinicService ============
  static String clinicDetails(String clinicId) => '${ApiHost.smartcaremainUrl}clinic/details/clinicid/$clinicId';
  
  // ============ FROM FrequencyService ============
  static String get frequencyData => '${ApiHost.smartcaremainUrl}priscriptionmaster/datalist';
  
  // ============ FROM InvestigationService ============
  static String get packageList => '${ApiHost.masterUrl}package/packagelist';
  static String investigationTypes(int typeId) => '${ApiHost.smartcaremainUrl}investigation/master/testtypelist/$typeId/0';
  static String get investigationTemplate => '${ApiHost.smartcaremainUrl}investigation/investigtiontemplate';
  static String get saveInvestigation => '${ApiHost.smartcaremainUrl}investigation/savetestrequest';
  static String get parameterList => '${ApiHost.smartcaremainUrl}investigation/master/parameterlist';
  static String get getCharge => '${ApiHost.smartcaremainUrl}investigation/master/getcharge';
  static String get jobTitleList => '${ApiHost.smartcaremainUrl}clinic/jobtitle/list';
  static String patientInformation(String patientId) => '${ApiHost.smartcaremainUrl}patient/information/$patientId';
  static String patientIpdDetails(String patientId) => '${ApiHost.billingUrl}statement/patientinfoandlastipddetails/$patientId';
  
  // ============ FROM MedicineService ============
  static String get medicineList => '${ApiHost.smartcaremainUrl}priscriptionmaster/medicinelist';
  static String get medicineDetails => '${ApiHost.smartcaremainUrl}priscriptionmaster/medicinedetails';
  
  // ============ FROM RepeatPrescriptionService ============
  static String get repeatPrescriptionList => '${ApiHost.smartcaremainUrl}priscription/repeatpriscriptionList';
  
  // ============ FROM SavePrescriptionService ============
  static String get savePrescription => '${ApiHost.smartcaremainUrl}priscription/save';
  
  // ============ FROM UnitService ============
  static String get unitStrength => '${ApiHost.smartcaremainUrl}priscriptionmaster/strengthlist';
  
  // ============ FROM UserInformationService ============
  static String get userInformation => '${ApiHost.smartcaremainUrl}userinformation';
}