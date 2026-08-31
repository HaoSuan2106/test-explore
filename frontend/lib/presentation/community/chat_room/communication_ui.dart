import 'package:flutter/material.dart';

class CommunicationUI extends StatelessWidget {
  const CommunicationUI({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Communication'),
      ),
    );
  }
}

typedef CommunicationUi = CommunicationUI;
