import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/api/ipd_service.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:staff_mate/services/addcharge_api.dart';

class AddChargesScreen extends StatefulWidget {
  final Patient patient;
  final Map<String, dynamic> packageData;
  final List<dynamic> practitionerList;

  const AddChargesScreen({
    super.key,
    required this.patient,
    required this.packageData,
    required this.practitionerList,
    required List specializationList,
  });

  @override
  State<AddChargesScreen> createState() => _AddChargesScreenState();
}

class _AddChargesScreenState extends State<AddChargesScreen> {
  // --- CONTROLLERS ---
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: "0");
  final TextEditingController _amountController = TextEditingController(text: "0.00");
  final TextEditingController _discountAmountController = TextEditingController(text: "0");

  // --- STATE VARIABLES ---
  String? _selectedReferralType;
  String? _selectedReferredBy;
  String? _selectedLocation;
  String? _selectedPackage;
  String? _selectedChargeType;
  String? _selectedChargeId;
  String? _selectedChargeDisplayName;

  String? _selectedPractitioner;
  String? _selectedSpeciality;
  
  String _paidBy = "Self"; 
  bool _hasPackage = false;
  bool _isLoadingReferenceList = false;
  List<Map<String, dynamic>> _referenceList = [];
  String? _selectedReferredById;

  List<dynamic> _specializationList = [];
  bool _isLoadingSpecializations = false;
  String? _specializationError;

  List<dynamic> _chargeTypeList = [];
  bool _isLoadingChargeTypes = false;
  String? _chargeTypeError;

  List<dynamic> _chargeNameList = [];
  bool _isLoadingChargeNames = false;
  String? _chargeNameError;

  String? _selectedDiscountType;
  final List<Map<String, dynamic>> _addedCharges = [];
  bool _isSubmitting = false;

  // --- STYLING CONSTANTS ---
  final Color darkBlue = const Color(0xFF1A237E);
  final Color bgGrey = const Color(0xFFF5F7FA);

  final Map<String, String> _referralTypeMap = {
    "Others": "0",
    "Lab": "1",
    "Agent": "2",
    "Ambulance": "3",
    "Referring Dr.": "5",
  };

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());

    _hasPackage = widget.packageData.isNotEmpty &&
        widget.packageData['package_name'] != null &&
        widget.packageData['package_name'].toString().isNotEmpty;

    if (_hasPackage) {
      _selectedPackage = widget.packageData['package_name']?.toString();
    } else {
      // Default to General since UI is removed to prevent validation error
      _selectedPackage = "General"; 
    }

    if (widget.patient.practitionername.isNotEmpty &&
        widget.patient.practitionername != "N/A") {
      _selectedPractitioner = widget.patient.practitionername;
    }

    _initializeLocation();
    _initializePaidBy();

    _qtyController.addListener(_calculateTotal);
    _priceController.addListener(_calculateTotal);
    _discountController.addListener(_calculateTotal);
    _discountAmountController.addListener(_calculateTotal);

    _fetchSpecializations();
    _loadCachedChargeTypes();
    _fetchChargeTypes(); 
  }

  @override
  void dispose() {
    _dateController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _amountController.dispose();
    _discountAmountController.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---

  void _initializeLocation() {
    if (widget.patient.ward != null && widget.patient.ward!.isNotEmpty) {
      _selectedLocation = widget.patient.ward;
    } else if (widget.patient.bedname != null && widget.patient.bedname!.isNotEmpty) {
      _selectedLocation = widget.patient.bedname;
    } else {
      _selectedLocation = "EM ( Bilaspur )";
    }
  }

  void _initializePaidBy() {
    _paidBy = "Self";
  }

  Future<void> _loadCachedChargeTypes() async {
    try {
      final cachedList = await PackageService.getCachedChargeTypeList();
      if (cachedList.isNotEmpty) {
        if (mounted) setState(() => _chargeTypeList = cachedList);
      }
    } catch (e) {
      debugPrint('Error loading cached charge types: $e');
    }
  }

  Future<void> _fetchChargeTypes() async {
    if (mounted) setState(() { _isLoadingChargeTypes = true; _chargeTypeError = null; });
    try {
      final chargeTypes = await PackageService.getChargeTypeList();
      if (mounted) setState(() { _chargeTypeList = chargeTypes; _isLoadingChargeTypes = false; });
    } catch (e) {
      if (mounted) setState(() { _chargeTypeError = e.toString(); _isLoadingChargeTypes = false; });
    }
  }

  Future<void> _fetchChargeNames(String? chargeTypeId) async {
    if (chargeTypeId == null || chargeTypeId == "0") {
      setState(() {
        _chargeNameList = [];
        _selectedChargeId = null;
        _selectedChargeDisplayName = null;
        _selectedDiscountType = null;
        _discountAmountController.text = "0";
        _qtyController.text = "1";
        _priceController.text = "";
        _discountController.text = "0";
        _amountController.text = "0.00";
      });
      return;
    }

    setState(() {
      _isLoadingChargeNames = true;
      _chargeNameError = null;
      _selectedChargeId = null;
      _selectedChargeDisplayName = null;
      _selectedDiscountType = null;
      _discountAmountController.text = "0";
      _qtyController.text = "1";
      _priceController.text = "";
      _discountController.text = "0";
      _amountController.text = "0.00";
    });

    try {
      final response = await PackageService.getMasterDetailList(
        chargeTypeId: chargeTypeId,
        practitionerId: null,
        searchKey: null,
        showWard: false,
        thirdPartyId: 0,
        wardId: 1,
      );

      if (response != null && response is Map && response['status_code'] == 200) {
        final safeResponse = Map<String, dynamic>.from(response);
        final chargeList = PackageService.extractChargeListFromMasterDetail(safeResponse);
        
        if (mounted) {
          setState(() {
            _chargeNameList = chargeList;
            _isLoadingChargeNames = false;
            if (_chargeNameList.isNotEmpty) {
              final firstCharge = _chargeNameList.first;
              if (firstCharge is Map) {
                _onChargeNameSelected(firstCharge['id']?.toString(), Map<String, dynamic>.from(firstCharge));
              }
            }
          });
        }
      } else {
        if (mounted) setState(() { _chargeNameList = []; _isLoadingChargeNames = false; _chargeNameError = 'Failed to load'; });
      }
    } catch (e) {
      if (mounted) setState(() { _chargeNameError = e.toString(); _isLoadingChargeNames = false; });
    }
  }

  void _onChargeNameSelected(String? id, Map<String, dynamic> selectedCharge) {
    setState(() {
      _selectedChargeId = id;
      _selectedChargeDisplayName = selectedCharge['name']?.toString();
      _qtyController.text = "1";
      
      double price = 0.0;
      if (selectedCharge['amount'] != null) {
        price = double.tryParse(selectedCharge['amount'].toString()) ?? 0.0;
      }
      _priceController.text = price.toString();

      if (selectedCharge['chargeDiscount'] != null) {
        double discount = double.tryParse(selectedCharge['chargeDiscount'].toString()) ?? 0.0;
        if (discount > 0) {
          _selectedDiscountType = "fixed";
          _discountAmountController.text = discount.toString();
        } else {
          _selectedDiscountType = null;
          _discountAmountController.text = "0";
        }
      } else {
        _selectedDiscountType = null;
        _discountAmountController.text = "0";
      }
      _calculateTotal();
    });
  }

  Future<void> _fetchSpecializations() async {
    if (mounted) setState(() => _isLoadingSpecializations = true);
    try {
      final specializations = await IpdService().fetchSpecializationList(branchId: "1");
      if (mounted) setState(() { _specializationList = specializations; _isLoadingSpecializations = false; });
    } catch (e) {
      if (mounted) setState(() { _specializationError = e.toString(); _isLoadingSpecializations = false; });
    }
  }

  void _calculateTotal() {
    double qty = double.tryParse(_qtyController.text) ?? 0;
    double price = double.tryParse(_priceController.text) ?? 0;
    double discountAmount = double.tryParse(_discountAmountController.text) ?? 0;

    double total = qty * price;
    
    if (_selectedDiscountType == 'percentage' && discountAmount > 0) {
      double discountValue = (total * discountAmount) / 100;
      total -= discountValue;
    } else if ((_selectedDiscountType == 'amount' || _selectedDiscountType == 'fixed') && discountAmount > 0) {
      total -= discountAmount;
    }

    if (total < 0) total = 0;
    if(mounted) _amountController.text = total.toStringAsFixed(2);
  }

  Future<void> _fetchReferenceList(String referralType) async {
    // Kept as per requirement
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: darkBlue)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  void _addChargeItem() {
    if (_selectedChargeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select charge type")));
      return;
    }
    if (_selectedChargeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select charge name")));
      return;
    }

    _calculateTotal();
    final double totalAmount = double.tryParse(_amountController.text) ?? 0;

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Total amount must be greater than 0")));
      return;
    }

    String chargeTypeName = "Unknown";
    String chargeTypeId = _selectedChargeType!;
    for (var chargeType in _chargeTypeList) {
      if (chargeType is Map && (chargeType['id'].toString() == _selectedChargeType || chargeType['name']?.toString() == _selectedChargeType)) {
        chargeTypeName = chargeType['name']?.toString() ?? "Unknown";
        chargeTypeId = chargeType['id']?.toString() ?? _selectedChargeType!;
        break;
      }
    }

    Map<String, dynamic>? selectedChargeDetails;
    for (var charge in _chargeNameList) {
      if (charge is Map && charge['id']?.toString() == _selectedChargeId) {
        selectedChargeDetails = Map<String, dynamic>.from(charge);
        break;
      }
    }

    final newCharge = {
      'chargeType': chargeTypeName,
      'chargeName': _selectedChargeDisplayName ?? "Unknown",
      'qty': _qtyController.text,
      'unitPrice': _priceController.text,
      'discountType': _selectedDiscountType == 'percentage' ? '%' : (_selectedDiscountType == 'amount' ? 'Amount' : 'Fixed'),
      'discountAmount': _discountAmountController.text,
      'amount': _amountController.text,
      'date': _dateController.text,
      'chargeId': _selectedChargeId,
      'chargeTypeId': chargeTypeId,
      'chargeDetails': selectedChargeDetails,
    };

    setState(() {
      _addedCharges.add(newCharge);
      _qtyController.text = "1";
      _priceController.text = "";
      _selectedDiscountType = null;
      _discountAmountController.text = "0";
      _amountController.text = "0.00";
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item Added: $_selectedChargeDisplayName"), duration: const Duration(seconds: 1)));
  }

  String _calculateTotalAmount() {
    double total = 0.0;
    for (var charge in _addedCharges) {
      total += double.tryParse(charge['amount'] ?? '0') ?? 0.0;
    }
    return total.toStringAsFixed(2);
  }

  Future<void> _createChargeInvoice() async {
    if (_addedCharges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one charge")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('userId') ?? '';

      List<Map<String, dynamic>> childListDTO = [];
      for (var charge in _addedCharges) {
        final quantity = int.tryParse(charge['qty'] ?? '1') ?? 1;
        final unitPrice = double.tryParse(charge['unitPrice'] ?? '0') ?? 0.0;
        final discountAmount = double.tryParse(charge['discountAmount'] ?? '0') ?? 0.0;
        final totalAmount = unitPrice * quantity - discountAmount;

        childListDTO.add(PackageService.createChildListItem(
          chargeId: int.tryParse(charge['chargeId'] ?? '0') ?? 0,
          chargeAmount: totalAmount.toString(),
          chargeDiscountAmount: charge['discountAmount'] ?? '0',
          chargeName: charge['chargeName'] ?? 'Service',
          chargeTypeId: int.tryParse(charge['chargeTypeId'] ?? '0') ?? 0,
          discountGrpId: 0,
          id: 0,
          isDiscard: false,
          quantity: quantity,
          serviceChargeId: null,
          unitId: null,
        ));
      }

      DateTime parsedDate;
      try {
        parsedDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      } catch (e) {
        parsedDate = DateTime.now();
      }

      String practitionerID = "0";
      String practitionerName = _selectedPractitioner ?? widget.patient.practitionername;
      
      for (var p in widget.practitionerList) {
        if (p is Map && p['practitionername'] == practitionerName) {
          practitionerID = p['id'].toString();
          break;
        }
      }

      final response = await PackageService.createCharge(
        opdId: 0, branchId: 1,
        date: DateFormat('yyyy-MM-dd').format(parsedDate),
        dateTime: PackageService.getCurrentDateTime(),
        discountGrpId: 0, chargeAmount: 0, chargeDiscountAmount: 0, chargeId: 0,
        childListDTO: childListDTO,
        patientId: widget.patient.patientid ?? '0',
        patientName: widget.patient.patientname,
        practitionerID: practitionerID,
        practitionerName: practitionerName,
        specializationId: "0",
        standardChargeDate: DateFormat('yyyy-MM-dd').format(parsedDate),
        standardChargeId: 0, thirdPartyId: 0, investigationRequestId: 0,
        investigationParentId: "", packageidAppliedId: 0, discountTeamId: 0,
        discountTeamUserid: 0, opdCompleted: false, userId: currentUserId,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice Created Successfully'), backgroundColor: Colors.green));
          Future.delayed(const Duration(seconds: 1), () {
             if (mounted) Navigator.pop(context, true);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Failed'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- MODERN UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 15, right: 15, bottom: 20),
            decoration: BoxDecoration(
              color: darkBlue,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Add Charges", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(widget.patient.patientname, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                      child: Text("${widget.patient.ward}/${widget.patient.bedname}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 15),
                // Compact Header Row
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Practitioner", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 9)),
                          Text(widget.patient.practitionername, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("IPD No", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 9)),
                          Text(widget.patient.ipdNo ?? 'N/A', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Location", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 9)),
                          Text(_selectedLocation ?? 'N/A', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- SCROLLABLE BODY ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Column(
                children: [
                  // CARD 1: CONFIGURATION (Practitioner, Speciality, Paid By)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,5))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune, size: 16, color: darkBlue),
                            const SizedBox(width: 8),
                            Text("Configuration", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: darkBlue)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Practitioner & Speciality
                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectableField(
                                value: _selectedPractitioner,
                                label: "Practitioner",
                                icon: Icons.person_pin,
                                items: widget.practitionerList.map((p) => p['practitionername'].toString()).toSet().toList(),
                                onSelect: (v) => setState(() => _selectedPractitioner = v),
                                isSearchable: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSelectableField(
                                value: _selectedSpeciality,
                                label: "Speciality",
                                icon: Icons.local_hospital,
                                items: _specializationList.map((s) => s['name'].toString()).toSet().toList(),
                                onSelect: (v) => setState(() => _selectedSpeciality = v),
                                isSearchable: true,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        
                        // Paid By (Package removed from UI)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Paid By", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                              child: Row(
                                children: [
                                  _buildRadioItem("Self"),
                                  Container(width: 1, height: 20, color: Colors.grey[300]),
                                  _buildRadioItem("TP"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CARD 2: CHARGE ENTRY
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,5))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long, size: 16, color: darkBlue),
                            const SizedBox(width: 8),
                            Text("Entry Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: darkBlue)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: () => _selectDate(context),
                                child: _buildModernInput(controller: _dateController, label: "Date", icon: Icons.calendar_today, readOnly: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _buildSelectableField(
                                value: _selectedChargeType,
                                label: "Charge Type",
                                icon: Icons.category,
                                items: _chargeTypeList.map((e) => e is Map ? (e['name']?.toString() ?? '') : '').where((e) => e.isNotEmpty).toList(),
                                onSelect: (name) {
                                  final type = _chargeTypeList.firstWhere((e) => e['name'] == name);
                                  setState(() => _selectedChargeType = name);
                                  _fetchChargeNames(type['id'].toString());
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Charge Name (Smart Searchable)
                        _isLoadingChargeNames
                          ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                          : _buildSelectableField(
                              value: _selectedChargeDisplayName,
                              label: "Charge Name",
                              icon: Icons.medication,
                              items: _chargeNameList.map((e) => e is Map ? (e['name']?.toString() ?? '') : '').where((e) => e.isNotEmpty).toList(),
                              onSelect: (name) {
                                final charge = _chargeNameList.firstWhere((e) => e['name'] == name);
                                if (charge is Map) {
                                  _onChargeNameSelected(charge['id'].toString(), Map<String, dynamic>.from(charge));
                                }
                              },
                              isSearchable: true,
                            ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildModernInput(controller: _qtyController, label: "Qty", icon: Icons.numbers, type: TextInputType.number)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildModernInput(controller: _priceController, label: "Price", icon: Icons.currency_rupee, type: TextInputType.number)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSelectableField(
                                value: _selectedDiscountType == 'percentage' ? '%' : (_selectedDiscountType == 'amount' ? 'Amt' : (_selectedDiscountType == 'fixed' ? 'Fix' : 'None')),
                                label: "Disc. Type",
                                icon: Icons.percent,
                                items: ["None", "%", "Amount", "Fixed"],
                                onSelect: (v) {
                                  setState(() => _selectedDiscountType = (v == "None" ? null : (v == "%" ? "percentage" : (v == "Amount" ? "amount" : "fixed"))));
                                  _calculateTotal();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _buildModernInput(controller: _discountAmountController, label: "Disc. Val", icon: Icons.money_off, type: TextInputType.number)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Total:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green[800])),
                                    Text("₹ ${_amountController.text}", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green[900])),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Added Charges Summary
                  if (_addedCharges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
                              child: Icon(Icons.list_alt, color: Colors.orange[800], size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${_addedCharges.length} Items Pending", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text("Total: ₹ ${_calculateTotalAmount()}", style: GoogleFonts.poppins(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 80), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // --- FLOATING BOTTOM BAR ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))]),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _addChargeItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: darkBlue,
                    side: BorderSide(color: darkBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text("Add Item +", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                   onPressed: _addedCharges.isNotEmpty ? _showAddedChargesSheet : null,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey[100],
                     foregroundColor: Colors.black87,
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     elevation: 0,
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.list, size: 18),
                       if(_addedCharges.isNotEmpty) ...[
                         const SizedBox(width: 4),
                         Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text("${_addedCharges.length}", style: const TextStyle(fontSize: 10, color: Colors.white, height: 1)))
                       ]
                     ],
                   ),
                 ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createChargeInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: darkBlue.withOpacity(0.3),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Create Invoice", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildRadioItem(String value) {
    bool isSelected = _paidBy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paidBy = value),
        child: Container(
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? darkBlue : Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? darkBlue : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            readOnly: readOnly,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 16),
              border: InputBorder.none,
              isDense: true,
              hintText: label,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String) onSelect,
    bool isSearchable = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            _showSmartSelectionSheet(label, items, onSelect, isSearchable);
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: value != null ? darkBlue : Colors.grey[500], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? "Select",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: value != null ? Colors.black87 : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSmartSelectionSheet(String title, List<String> items, Function(String) onSelect, bool isSearchable) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Internal state for search filtering
        String query = "";
        
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final filteredItems = query.isEmpty 
              ? items 
              : items.where((i) => i.toLowerCase().contains(query.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text("Select $title", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  
                  if (isSearchable || items.length > 8)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search...",
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)
                          ),
                          onChanged: (val) => setStateSheet(() => query = val),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  const Divider(thickness: 1, height: 1),
                  
                  Expanded(
                    child: filteredItems.isEmpty 
                    ? Center(child: Text("No items found", style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
                            ),
                            title: Text(filteredItems[index], style: GoogleFonts.poppins(fontSize: 14)),
                            onTap: () {
                              onSelect(filteredItems[index]);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showAddedChargesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin:const EdgeInsets.only(bottom:20), decoration: BoxDecoration(color:Colors.grey[300], borderRadius:BorderRadius.circular(10))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Added Charges", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Total: ₹ ${_calculateTotalAmount()}", style: GoogleFonts.poppins(color: darkBlue, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: _addedCharges.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _addedCharges[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                      child: Row(
                        children: [
                           CircleAvatar(
                            backgroundColor: darkBlue.withOpacity(0.1),
                            radius: 14,
                            child: Text("${index + 1}", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['chargeName'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text("${item['qty']} x ₹${item['unitPrice']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                if(double.tryParse(item['discountAmount'])! > 0)
                                  Text("Disc: ${item['discountAmount']}", style: TextStyle(fontSize: 11, color: Colors.orange[700])),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₹${item['amount']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800])),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _addedCharges.removeAt(index);
                                  });
                                  Navigator.pop(context);
                                  _showAddedChargesSheet();
                                },
                                // CHANGED: Replaced delete icon with red cancel cross
                                child: const Icon(Icons.cancel, color: Colors.red, size: 22),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicReferredByDropdown() {
    /* Commented out as per requirements
    List<DropdownMenuItem<String>> items = [
      DropdownMenuItem(
        value: null,
        child: Text("Select",
            style:
                TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      )
    ];

    if (_referenceList.isNotEmpty) {
      _referenceList.sort((a, b) =>
          (a['displayName'] ?? '').compareTo(b['displayName'] ?? ''));

      for (var refItem in _referenceList) {
        final displayName = refItem['displayName'] ?? 'Unknown';
        items.add(
          DropdownMenuItem(
            value: displayName,
            child: Text(
              displayName,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } else {
      items.add(
        DropdownMenuItem(
          value: 'empty',
          enabled: false,
          child: Text(
            _selectedReferralType != null && _selectedReferralType != "Select"
                ? 'No references found'
                : 'Select a referral type first',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedReferredBy,
      items: items,
      onChanged: (val) {
        if (val != null && val != 'empty') {
          setState(() {
            _selectedReferredBy = val;
            for (var refItem in _referenceList) {
              if (refItem['displayName'] == val) {
                _selectedReferredById = refItem['id'];
                break;
              }
            }
          });
        }
      },
      decoration: getDecoration(""),
      icon:
          const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      hint: Text(
        _referenceList.isNotEmpty ? "Select reference" : "No references",
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
    */
    return Container(); // Return empty container
  }
}