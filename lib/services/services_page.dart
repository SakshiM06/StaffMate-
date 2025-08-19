import 'package:flutter/material.dart';
import 'package:staff_mate/pages/ipd_dashboard_page.dart';
import 'package:staff_mate/pages/opd_dashboard_page.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Services',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: EdgeInsets.symmetric(vertical: 3.0,horizontal: 50.0),
         indicator: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),

            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            tabs: [
              Tab(text: 'IPD'),
              Tab(text: 'OPD'),
            ],
           ),
        ),
        body: const TabBarView(
          children: [
            IpdDashboardPage(),
            OpdDashboardPage(),
          ],
        ),
      ),
    );
  }
}

class IPDTab extends StatelessWidget {
  const IPDTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'IPD Services Content',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class OPDTab extends StatelessWidget {
  const OPDTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'OPD Services Content',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}