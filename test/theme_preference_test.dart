import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletennis_scoreboard/services/theme_preference.dart';

void main() {
  group('ThemePreference', () {
    test('load() returns dark when nothing has been saved yet — dark stays '
        'the default for a fresh install (PHASE4B_UI_POLISH.md)', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemePreference().load(), ThemeMode.dark);
    });

    test('save() then load() round-trips light', () async {
      SharedPreferences.setMockInitialValues({});
      final pref = ThemePreference();
      await pref.save(ThemeMode.light);
      expect(await pref.load(), ThemeMode.light);
    });

    test('save() then load() round-trips dark', () async {
      SharedPreferences.setMockInitialValues({});
      final pref = ThemePreference();
      await pref.save(ThemeMode.dark);
      expect(await pref.load(), ThemeMode.dark);
    });

    test('save() then load() round-trips system', () async {
      SharedPreferences.setMockInitialValues({});
      final pref = ThemePreference();
      await pref.save(ThemeMode.system);
      expect(await pref.load(), ThemeMode.system);
    });

    test('a fresh ThemePreference instance sees a previous instance\'s '
        'saved value — simulating the choice surviving an app restart',
        () async {
      SharedPreferences.setMockInitialValues({});
      await ThemePreference().save(ThemeMode.light);
      // A brand-new instance, as main.dart creates at every cold start.
      expect(await ThemePreference().load(), ThemeMode.light);
    });
  });
}
