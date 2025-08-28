
import 'package:flutter/material.dart';

class SummaryPage extends StatefulWidget {
  final String summaryText;

  const SummaryPage({
    super.key,
    required this.summaryText,
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            widget.summaryText,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
