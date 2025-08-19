import 'package:flutter/material.dart';
import '../services/ipd_services.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/search_bar.dart';
import '../widgets/bed_card.dart';
import '../widgets/filter_dropdowns.dart';

class IpdDashboardPage extends StatelessWidget {
  const IpdDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final beds = IpdServices.getBeds();

    return Padding(
      padding: const EdgeInsets.all(12.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashboardStats(),
          const SizedBox(height: 16), 

          const SearchBarWidget(),
          const SizedBox(height: 12), 

          const FilterDropdowns(),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: beds.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: BedCard(bed: beds[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
