import 'package:flutter_test/flutter_test.dart';
import 'package:tabletennis_scoreboard/models/player_names.dart';

void main() {
  group('PlayerNames', () {
    test('resolve returns the default label when no custom name is set',
        () {
      final names = PlayerNames();
      expect(names.resolve(1, 'Player 1'), 'Player 1');
      expect(names.isCustom(1), isFalse);
    });

    test('set stores a trimmed custom name, returned by resolve', () {
      final names = PlayerNames();
      names.set(1, '  Alex  ');
      expect(names.resolve(1, 'Player 1'), 'Alex');
      expect(names.isCustom(1), isTrue);
    });

    test('setting one slot does not affect another', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      expect(names.resolve(2, 'Player 2'), 'Player 2');
      expect(names.isCustom(2), isFalse);
    });

    test('setting to null clears back to the default', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      names.set(1, null);
      expect(names.resolve(1, 'Player 1'), 'Player 1');
      expect(names.isCustom(1), isFalse);
    });

    test('setting to an empty or whitespace-only string clears back to '
        'the default (no blank names)', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      names.set(1, '   ');
      expect(names.resolve(1, 'Player 1'), 'Player 1');
      expect(names.isCustom(1), isFalse);

      names.set(1, '');
      expect(names.isCustom(1), isFalse);
    });

    test('a name at exactly maxLength is accepted', () {
      final names = PlayerNames();
      final name = 'A' * PlayerNames.maxLength;
      names.set(1, name);
      expect(names.resolve(1, 'Player 1'), name);
      expect(names.isCustom(1), isTrue);
    });

    test('a name longer than maxLength is rejected (left at default), not '
        'silently truncated', () {
      final names = PlayerNames();
      final tooLong = 'A' * (PlayerNames.maxLength + 1);
      names.set(1, tooLong);
      expect(names.resolve(1, 'Player 1'), 'Player 1');
      expect(names.isCustom(1), isFalse);
    });

    test('clear() reverts every slot to its default', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      names.set(2, 'Sam');
      names.set(3, 'Robin');
      names.clear();
      expect(names.resolve(1, 'Player 1'), 'Player 1');
      expect(names.resolve(2, 'Player 2'), 'Player 2');
      expect(names.resolve(3, 'Player 3'), 'Player 3');
      expect(names.isCustom(1), isFalse);
    });

    test('all 4 doubles slots can hold independent custom names', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      names.set(2, 'Sam');
      names.set(3, 'Robin');
      names.set(4, 'Jordan');
      expect(names.resolve(1, 'Player 1'), 'Alex');
      expect(names.resolve(2, 'Player 2'), 'Sam');
      expect(names.resolve(3, 'Player 3'), 'Robin');
      expect(names.resolve(4, 'Player 4'), 'Jordan');
    });
  });

  group('PlayerNames: team names (Phase 4G)', () {
    test('resolveTeam returns the default label when no custom team name '
        'is set', () {
      final names = PlayerNames();
      expect(names.resolveTeam(1, 'Team 1'), 'Team 1');
      expect(names.isTeamCustom(1), isFalse);
    });

    test('setTeam stores a trimmed custom team name', () {
      final names = PlayerNames();
      names.setTeam(1, '  The Smashers  ');
      expect(names.resolveTeam(1, 'Team 1'), 'The Smashers');
      expect(names.isTeamCustom(1), isTrue);
    });

    test('team names and player names are completely independent stores '
        '— setting one never touches the other', () {
      final names = PlayerNames();
      names.set(1, 'Alex');
      names.setTeam(1, 'The Smashers');

      expect(names.resolve(1, 'Player 1'), 'Alex');
      expect(names.resolveTeam(1, 'Team 1'), 'The Smashers');

      names.setTeam(1, null);
      expect(names.resolve(1, 'Player 1'), 'Alex',
          reason: 'clearing the team name must not clear the player name');

      names.set(1, null);
      names.setTeam(1, 'The Smashers');
      expect(names.resolve(1, 'Player 1'), 'Player 1',
          reason: 'setting a team name must not set the player name');
    });

    test('team 1 and team 2 are independent', () {
      final names = PlayerNames();
      names.setTeam(1, 'The Smashers');
      expect(names.resolveTeam(2, 'Team 2'), 'Team 2');
      expect(names.isTeamCustom(2), isFalse);
    });

    test('an empty/whitespace/too-long team name reverts to the default, '
        'same validation as player names', () {
      final names = PlayerNames();
      names.setTeam(1, 'The Smashers');
      names.setTeam(1, '   ');
      expect(names.resolveTeam(1, 'Team 1'), 'Team 1');

      names.setTeam(1, 'A' * (PlayerNames.maxLength + 1));
      expect(names.isTeamCustom(1), isFalse);
    });

    test('clear() also reverts custom team names', () {
      final names = PlayerNames();
      names.setTeam(1, 'The Smashers');
      names.setTeam(2, 'The Spinners');
      names.clear();
      expect(names.resolveTeam(1, 'Team 1'), 'Team 1');
      expect(names.resolveTeam(2, 'Team 2'), 'Team 2');
    });
  });
}
