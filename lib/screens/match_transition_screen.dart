import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/match_start_transition.dart';

/// The choreographed match-start transition shown between tapping "Start
/// match" on the setup screen and actually landing on the scoreboard —
/// see PHASE4D_TEAM_CLARITY_AND_TRANSITION.md (original ball flyby) and
/// PHASE4E_MATCH_START_TRANSITION.md (the full ball-strikes-text sequence
/// this screen now plays via [MatchStartTransition]).
///
/// [destination] is pushed as a replacement (not a second entry on top of
/// this screen) once the sequence finishes, so the back stack reads as
/// setup → scoreboard, with this screen never appearing in it — pressing
/// back from the scoreboard returns straight to setup, not to a blank
/// transition frame.
class MatchTransitionScreen extends StatelessWidget {
  final Widget destination;

  const MatchTransitionScreen({super.key, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: MatchStartTransition(
          text: AppLocalizations.of(context).matchStartCheer,
          onComplete: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => destination),
            );
          },
        ),
      ),
    );
  }
}
