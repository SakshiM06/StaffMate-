import 'package:flutter/material.dart';
import '../models/vitals.dart';
import '../services/vitals_service.dart';

class CaptureVitalsSheet extends StatefulWidget {
  final String patientName;
  const CaptureVitalsSheet({super.key, required this.patientName});

  @override
  State<CaptureVitalsSheet> createState() => _CaptureVitalsSheetState();
}

class _CaptureVitalsSheetState extends State<CaptureVitalsSheet> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date;
  late int _hh;
  late int _mm;

  final _tempCtl = TextEditingController();
  final _hrCtl = TextEditingController();
  final _rrCtl = TextEditingController();
  final _sysBpCtl = TextEditingController();
  final _diaBpCtl = TextEditingController();
  final _rbsCtl = TextEditingController();
  final _spo2Ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _hh = now.hour;
    _mm = now.minute;
  }

  @override
  void dispose() {
    _tempCtl.dispose();
    _hrCtl.dispose();
    _rrCtl.dispose();
    _sysBpCtl.dispose();
    _diaBpCtl.dispose();
    _rbsCtl.dispose();
    _spo2Ctl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final entry = VitalsEntry(
      patientName: widget.patientName,
      date: _date,
      hour: _hh,
      minute: _mm,
      tempF: _tempCtl.text.trim(),
      hr: _hrCtl.text.trim(),
      rr: _rrCtl.text.trim(),
      sysBp: _sysBpCtl.text.trim(),
      diaBp: _diaBpCtl.text.trim(),
      rbs: _rbsCtl.text.trim(),
      spo2: _spo2Ctl.text.trim(),
    );

    VitalsService.I.save(entry);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vitals saved successfully ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material( // ✅ Fix: Wrap with Material
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.patientName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vitals',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date + Time Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              "${_date.day.toString().padLeft(2, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.year}",
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _hh,
                          decoration: const InputDecoration(
                            labelText: 'HH',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            24,
                            (i) => DropdownMenuItem(value: i, child: Text('$i')),
                          ),
                          onChanged: (v) => setState(() => _hh = v ?? _hh),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _mm,
                          decoration: const InputDecoration(
                            labelText: 'MM',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            60,
                            (i) => DropdownMenuItem(value: i, child: Text('$i')),
                          ),
                          onChanged: (v) => setState(() => _mm = v ?? _mm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fields
                  _VitalsField(controller: _tempCtl, label: 'Temperature (°F)', helper: 'Normal: 97 - 99'),
                  _VitalsField(controller: _hrCtl, label: 'Heart Rate (bpm)', helper: 'Normal: 60 - 100'),
                  _VitalsField(controller: _rrCtl, label: 'Respiratory Rate', helper: 'Normal: 12 - 20'),
                  _VitalsField(controller: _sysBpCtl, label: 'Systolic BP', helper: 'Normal: 120 - 140'),
                  _VitalsField(controller: _diaBpCtl, label: 'Diastolic BP', helper: 'Normal: 80 - 90'),
                  _VitalsField(controller: _rbsCtl, label: 'Random Blood Sugar', helper: 'Normal: < 140'),
                  _VitalsField(controller: _spo2Ctl, label: 'SpO₂ (%)', helper: 'Normal: > 95'),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Vitals'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helper;

  const _VitalsField({
    required this.controller,
    required this.label,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(helper, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Enter number only';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
