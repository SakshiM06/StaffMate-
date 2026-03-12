import 'package:staff_mate/APIs/api_host.dart';

class ApiEndpoints {
  // ============ FROM ApiService (login) ============
  static String get login => '${ApiHost.loginBaseUrl}security/auth/login';
  
  // ============ FROM IpdService ============
  static String get ipdPatients => '${ApiHost.baseUrl}ipd/patient/all';
  static String get practitionerList => '${ApiHost.baseUrl}practitionerlist';
  static String get specializationList => '${ApiHost.baseUrl}clinic/specializationlist';
  static String wardList(String branchId) => '${ApiHost.baseUrl}clinic/branchwisewardlist/$branchId';
  static String availableBeds(String wardId) => '${ApiHost.baseUrl}clinic/availablebedinward/$wardId';
  static String get vitalsMaster => '${ApiHost.baseUrl}ipd/common/get/vitals';
  static String vitalsByType(int vitalType) => '${ApiHost.baseUrl}ipd/common/get/vitals/$vitalType';
  static String get saveVitals => '${ApiHost.baseUrl}ipd/common/save/timewise/vitals';
  static String prescriptionNotification(String admissionId) => '${ApiHost.baseUrl}ipd/patient/getNotification/priscription/$admissionId';
  static String investigationNotification(String admissionId) => '${ApiHost.baseUrl}ipd/patient/getNotification/investigation/$admissionId';
  static String get dayToDayNotes => '${ApiHost.baseUrl}ipd/patient/daytodaynotes/fetch';
  static String get saveDayToDayNotes => '${ApiHost.baseUrl}ipd/patient/daytodaynotes/save';
  static String get shiftBed => '${ApiHost.baseUrl}ipd/common/shiftbed';
  static String get addStdCharges => '${ApiHost.baseUrl}ipd/patient/addstdcharges';
  static String get uploadDocument => '${ApiHost.baseUrl}patient/uploadDocuments';
  
  // ============ FROM AddMedicineService ============
  static String get addMedicine => '${ApiHost.baseUrl}priscriptionmaster/medicinedetails/saveorupdate';
  
  // ============ FROM PackageService ============
  static String get packageExists => '${ApiHost.billingUrl}patientpackage/getPackageIfExists';
  static String get referenceList => '${ApiHost.baseUrl}refrencelist';
  static String get chargeTypeList => '${ApiHost.billingUrl}charges/chargetype/list';
  static String get masterDetailList => '${ApiHost.billingUrl}charges/master-detail-list';
  static String get createCharge => '${ApiHost.billingUrl}charges/createnew';
  
  // ============ FROM ClinicService ============
  static String clinicDetails(String clinicId) => '${ApiHost.baseUrl}clinic/details/clinicid/$clinicId';
  
  // ============ FROM FrequencyService ============
  static String get frequencyData => '${ApiHost.baseUrl}priscriptionmaster/datalist';
  
  // ============ FROM InvestigationService ============
  static String get packageList => '${ApiHost.masterUrl}package/packagelist';
  static String investigationTypes(int typeId) => '${ApiHost.baseUrl}investigation/master/testtypelist/$typeId/0';
  static String get investigationTemplate => '${ApiHost.baseUrl}investigation/investigtiontemplate';
  static String get saveInvestigation => '${ApiHost.baseUrl}investigation/savetestrequest';
  static String get parameterList => '${ApiHost.baseUrl}investigation/master/parameterlist';
  static String get getCharge => '${ApiHost.baseUrl}investigation/master/getcharge';
  static String get jobTitleList => '${ApiHost.baseUrl}clinic/jobtitle/list';
  static String patientInformation(String patientId) => '${ApiHost.baseUrl}patient/information/$patientId';
  static String patientIpdDetails(String patientId) => '${ApiHost.billingUrl}statement/patientinfoandlastipddetails/$patientId';
  
  // ============ FROM MedicineService ============
  static String get medicineList => '${ApiHost.baseUrl}priscriptionmaster/medicinelist';
  static String get medicineDetails => '${ApiHost.baseUrl}priscriptionmaster/medicinedetails';
  
  // ============ FROM RepeatPrescriptionService ============
  static String get repeatPrescriptionList => '${ApiHost.baseUrl}priscription/repeatpriscriptionList';
  
  // ============ FROM SavePrescriptionService ============
  static String get savePrescription => '${ApiHost.baseUrl}priscription/save';
  
  // ============ FROM UnitService ============
  static String get unitStrength => '${ApiHost.baseUrl}priscriptionmaster/strengthlist';
  
  // ============ FROM UserInformationService ============
  static String get userInformation => '${ApiHost.baseUrl}userinformation';

  // ============ FROM DocumentService ============
  static String get documentTypes => '${ApiHost.baseUrl}patient/documenttypes';

  // ============ FROM DashboardService ============
  static String get dashboardData => '${ApiHost.baseUrl}dashboard/summary';

  // ============ FROM DischargeService ============
  static String get dischargeSummary => '${ApiHost.baseUrl}discharge/summary';

  // ============ FROM TransferService ============
  static String get transferPatient => '${ApiHost.baseUrl}patient/transfer';

  // ============ FROM LogoutService ============
  static String get logout => '${ApiHost.loginBaseUrl}security/auth/logout';

  // ============ FROM ProfileService ============
  static String get profile => '${ApiHost.baseUrl}user/profile';

  // ============ FROM ChangePasswordService ============
  static String get changePassword => '${ApiHost.loginBaseUrl}security/auth/changepassword';

  // ============ FROM NotificationService ============
  static String get notifications => '${ApiHost.baseUrl}notification/list';

  // ============ FROM SearchService ============
  static String searchPatients(String query) => '${ApiHost.baseUrl}patient/search?query=$query';

  // ============ FROM AdmissionService ============
  static String get admission => '${ApiHost.baseUrl}admission/save';

  // ============ FROM BedService ============
  static String get bedList => '${ApiHost.baseUrl}clinic/bedlist';

  // ============ FROM BranchService ============
  static String get branchList => '${ApiHost.baseUrl}clinic/branchlist';

//=========== FROM MYTASKS SERVICE ============
  static String get myTasksCategory => '${ApiHost.baseUrl}/master/category/master/getAll';  
  static String get saveTask => '${ApiHost.baseUrl}/master/task/master/save';
  static String get myTasksList => '${ApiHost.baseUrl}/master/task/master/fetch';
 static String get updateTaskStatus => '${ApiHost.baseUrl}/master/task/master/update';

}