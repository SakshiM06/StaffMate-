import 'package:flutter/material.dart';

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
            indicator: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)), // curved rectangle
              color: Colors.orange,
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
            IPDTab(),
            OPDTab(),
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
