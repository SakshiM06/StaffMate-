import 'package:flutter/material.dart';

class BedListPage extends StatelessWidget {
  const BedListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample bed data — replace with API or DB data
    final List<Map<String, String>> beds = [
      {'bedNumber': '101', 'status': 'Occupied', 'patientName': 'John Doe'},
      {'bedNumber': '102', 'status': 'Available', 'patientName': ''},
      {'bedNumber': '103', 'status': 'Cleaning', 'patientName': ''},
      {'bedNumber': '104', 'status': 'Occupied', 'patientName': 'Jane Smith'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bed List"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: ListView.builder(
        itemCount: beds.length,
        itemBuilder: (context, index) {
          final bed = beds[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(bed['status'] ?? ''),
                child: Text(
                  bed['bedNumber'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text("Bed No: ${bed['bedNumber']}"),
              subtitle: Text(
                bed['status'] == 'Occupied'
                    ? "Patient: ${bed['patientName']}"
                    : "Status: ${bed['status']}",
              ),
              trailing: Icon(
                Icons.circle,
                color: _getStatusColor(bed['status'] ?? ''),
                size: 16,
              ),
              onTap: () {
                // Navigate to patient details or booking page
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Clicked Bed ${bed['bedNumber']}")),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Occupied':
        return Colors.red;
      case 'Available':
        return Colors.green;
      case 'Cleaning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
