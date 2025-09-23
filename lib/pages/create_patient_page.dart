import 'package:flutter/material.dart';
import 'package:staff_mate/models/patient.dart';

class CreatePatientPage extends StatefulWidget {
  const CreatePatientPage({super.key});

  @override
  State<CreatePatientPage> createState() => _CreatePatientPageState();
}

class _CreatePatientPageState extends State<CreatePatientPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bedController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _scdController = TextEditingController();

  final List<String> _genderOptions = ['MALE', 'FEMALE', 'OTHER'];
  final List<String> _partyOptions = ['SELF', 'CORPORATE', 'INSURANCE'];
  final List<String> _doctorOptions = ['DR. ROHIT HATWAR', 'DR. JANE SMITH', 'DR. EMILY JONES'];
  final List<String> _wardOptions = ['GEN', 'ICU', 'PRIVATE', 'SEMI-PRIVATE'];

  String? _selectedGender;
  String? _selectedParty;
  String? _selectedDoctor;
  String? _selectedWard;

  @override
  void initState() {
    super.initState();
    _selectedGender = _genderOptions.first;
    _selectedParty = _partyOptions.first;
    _selectedDoctor = _doctorOptions.first;
    _selectedWard = _wardOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bedController.dispose();
    _diagnosisController.dispose();
    _scdController.dispose();
    super.dispose();
  }

  void _savePatient() {
    if (_formKey.currentState?.validate() ?? false) {
      final now = DateTime.now();

      final int age = int.tryParse(_ageController.text) ?? 0;

      final newPatient = Patient(
        patientname: _nameController.text,
        ipdNo: 'SCD/IP/25/NEW01', 
        age: age, 
        gender: _selectedGender!, 
        party: _selectedParty!,
        practitionername: _selectedDoctor!,
        ward: _selectedWard!,
        bedname: _bedController.text,
        admissionDateTime: now,
        diagnosis: _diagnosisController.text,
        scdNo: _scdController.text,
        uhid: 'N/A',
        dob: 'N/A',
        dischargeStatus: '0',
        isMlc: '0',
        patientBalance: 0,
        active: 1,
        isPrivateTp: '0',
        isUnderMaintenance: 0,
      bedid: 1,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient ${newPatient.patientname} saved!')),
      );

      Navigator.pop(context, newPatient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Patient'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextFormField(
                controller: _nameController,
                labelText: 'Patient Name',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _ageController,
                labelText: 'Age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownFormField(
                value: _selectedGender,
                items: _genderOptions,
                labelText: 'Gender',
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 16),
              _buildDropdownFormField(
                value: _selectedParty,
                items: _partyOptions,
                labelText: 'Party',
                onChanged: (value) => setState(() => _selectedParty = value),
              ),
              const SizedBox(height: 16),
              _buildDropdownFormField(
                value: _selectedDoctor,
                items: _doctorOptions,
                labelText: 'Doctor',
                onChanged: (value) => setState(() => _selectedDoctor = value),
              ),
              const SizedBox(height: 16),
              _buildDropdownFormField(
                value: _selectedWard,
                items: _wardOptions,
                labelText: 'Ward',
                onChanged: (value) => setState(() => _selectedWard = value),
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _bedController,
                labelText: 'Bed Number',
                keyboardType: TextInputType.text,
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a bed number' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _scdController,
                labelText: 'SCD No.',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an SCD No.' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _diagnosisController,
                labelText: 'Diagnosis (Optional)',
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _savePatient,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child:
                    const Text('Save Patient', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  Widget _buildDropdownFormField({
    required String? value,
    required List<String> items,
    required String labelText,
    void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((label) => DropdownMenuItem(value: label, child: Text(label)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value == null ? 'Please select an option' : null,
    );
  }
}