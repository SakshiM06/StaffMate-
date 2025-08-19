// import 'package:flutter/material.dart';
// import 'package:staff_mate/pages/opd_tab.dart';
// import 'package:staff_mate/pages/ipd_tab.dart';

// class Services extends StatelessWidget {
//   const Services({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2, 
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text(
//             'Services',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           backgroundColor: Colors.teal,
//           bottom: PreferredSize(
//             preferredSize: const Size.fromHeight(60),
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.teal.shade50,
//                 borderRadius: BorderRadius.circular(30),
//                 border: Border.all(color: Colors.teal, width: 1.5),
//               ),
//               child: const TabBar(
//                 labelColor: Colors.white,
//                 unselectedLabelColor: Color.fromARGB(255, 54, 54, 54),
//                 indicator: BoxDecoration(
//                   color: Colors.teal,
//                   borderRadius: BorderRadius.all(Radius.circular(30)),
//                 ),
//                 indicatorSize: TabBarIndicatorSize.tab,
//                 labelStyle: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 tabs: [
//                   Tab(text: 'IPD'),
//                   Tab(text: 'OPD'),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         body: const TabBarView(
//           children: [
        
          
//           ],
//         ),
//       ),
//     );
//   }
// }
