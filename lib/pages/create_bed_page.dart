import 'package:flutter/material.dart';
import 'package:staff_mate/models/bed.dart';

class CreateBedForm extends StatefulWidget {
  final void Function(Bed) onSave;
  const CreateBedForm({super.key, required this.onSave});

  @override
  State<CreateBedForm> createState() => _CreateBedFormState();
}

class _CreateBedFormState extends State<CreateBedForm> {
  final _formKey = GlobalKey<FormState>();
  String wardType = '';
  String bedNo = '';
  String ipdNo = '';
  String patientName = '';
  String ageGender = '';
  String thirdParty = '';
  String doctorName = '';
  String colorHex = '0xFF1565C0';
  String category = '';
  bool isAvailable = false;
  bool toBeDischarged = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Create Bed", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _text('Ward Type', (v) => wardType = v, req: true)),
              const SizedBox(width: 10),
              Expanded(child: _text('Bed No', (v) => bedNo = v, req: true)),
            ]),
            SwitchListTile(
              title: const Text('Mark as Available (empty)'),
              value: isAvailable,
              onChanged: (v) => setState(() => isAvailable = v),
            ),
            if (!isAvailable) ...[
              _text('IPD No', (v) => ipdNo = v),
              _text('Patient Name', (v) => patientName = v, req: true),
              _text('Age/Gender', (v) => ageGender = v),
              _text('Third Party', (v) => thirdParty = v),
              _text('Doctor Name', (v) => doctorName = v),
              CheckboxListTile(
                value: toBeDischarged,
                onChanged: (v) => setState(() => toBeDischarged = v ?? false),
                title: const Text('To be Discharged'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('None')),
                  DropdownMenuItem(value: 'Self', child: Text('Self')),
                  DropdownMenuItem(value: 'MLC', child: Text('MLC')),
                  DropdownMenuItem(value: 'TP', child: Text('TP')),
                  DropdownMenuItem(value: 'TPCorporate', child: Text('TP Corporate')),
                ],
                onChanged: (v) => category = v ?? '',
              ),
            ],
            DropdownButtonFormField<String>(
              value: colorHex,
              decoration: const InputDecoration(labelText: 'Card Color'),
              items: const [
                DropdownMenuItem(value: '0xFF1565C0', child: Text('Blue')),
                DropdownMenuItem(value: '0xFF4CAF50', child: Text('Green')),
                DropdownMenuItem(value: '0xFFB3B333', child: Text('Yellow')),
                DropdownMenuItem(value: '0xFF673AB7', child: Text('Purple')),
                DropdownMenuItem(value: '0xFF607D8B', child: Text('Blue Grey')),
              ],
              onChanged: (v) => setState(() => colorHex = v ?? colorHex),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }

  Widget _text(String label, void Function(String) onSave, {bool req = false}) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      validator: (v) => (req && (v == null || v.trim().isEmpty)) ? 'Required' : null,
      onSaved: (v) => onSave(v?.trim() ?? ''),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final bed = Bed(
      wardType: wardType,
      bedNo: bedNo,
      ipdNo: isAvailable ? '' : ipdNo,
      patientName: isAvailable ? '' : patientName,
      ageGender: isAvailable ? '' : ageGender,
      thirdParty: isAvailable ? '' : thirdParty,
      admissionDate: isAvailable ? '' : DateTime.now().toString(),
      doctorName: isAvailable ? '' : doctorName,
      colorHex: colorHex,
      category: isAvailable ? '' : category,
      isAvailable: isAvailable,
      toBeDischarged: isAvailable ? false : toBeDischarged,
    );

    widget.onSave(bed);
    Navigator.pop(context);
  }
}
