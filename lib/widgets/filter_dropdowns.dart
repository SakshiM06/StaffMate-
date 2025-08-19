import 'package:flutter/material.dart';

class FilterDropdowns extends StatelessWidget {
  const FilterDropdowns({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        _FilterDropdown(
          label: "Ward",
          options: [
            "All Ward",
            "ICU",
            "GEN",
            "CathLab",
            "Isolation",
            "Post-OPS",
            "Twin Sharing",
            "DLX Suite",
            "BMT",
            "Casualty",
          ],
        ),
        _FilterDropdown(
          label: "Status",
          options: [
            "Active",
            "Inactive",
          ],
        ),
        _FilterDropdown(
          label: "Category",
          options: [
            "Free Case",
            "Format 1",
          ],
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatefulWidget {
  final String label;
  final List<String> options;

  const _FilterDropdown({required this.label, required this.options});

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: Text(widget.label),
      value: selectedValue,
      items: widget.options
          .map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt),
              ))
          .toList(),
      onChanged: (val) {
        setState(() {
          selectedValue = val;
        });
      },
    );
  }
}
