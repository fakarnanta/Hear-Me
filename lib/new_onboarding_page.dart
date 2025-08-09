
import 'package:flutter/material.dart';

class NewOnboardingPage extends StatelessWidget {
  const NewOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Onboarding'),
      ),
      body: const Center(
        child: Text('This is the new onboarding page for Windows.'),
      ),
    );
  }
}
