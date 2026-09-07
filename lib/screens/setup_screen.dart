import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player.dart';
import 'scoreboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _bestOf = 5;
  Player? _firstServer;

  void _tossCoin() {
    setState(() {
      _firstServer = Random().nextBool() ? Player.one : Player.two;
    });
  }

  void _start() {
    final firstServer = _firstServer;
    if (firstServer == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScoreboardScreen(
          bestOf: _bestOf,
          firstServer: firstServer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New match')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Best of'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const Key('bestOfSelector'),
              segments: const [
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 7, label: Text('7')),
              ],
              selected: {_bestOf},
              onSelectionChanged: (selection) {
                setState(() => _bestOf = selection.first);
              },
            ),
            const SizedBox(height: 32),
            Text(
              _firstServer == null
                  ? 'Toss to decide who serves first'
                  : 'First server: '
                      '${_firstServer == Player.one ? 'Player 1' : 'Player 2'}',
              key: const Key('firstServerLabel'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('tossButton'),
              onPressed: _tossCoin,
              child: const Text('Toss coin'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('startMatchButton'),
              onPressed: _firstServer == null ? null : _start,
              child: const Text('Start match'),
            ),
          ],
        ),
      ),
    );
  }
}
