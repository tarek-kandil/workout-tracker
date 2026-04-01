import 'package:flutter/material.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Workout')),
      body: const Center(
        child: Text('Workout logging — coming in Slice 3'),
      ),
    );
  }
}
