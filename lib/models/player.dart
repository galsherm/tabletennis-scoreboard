/// The two sides of a singles table tennis match.
enum Player { one, two }

extension PlayerX on Player {
  /// The other player.
  Player get opponent => this == Player.one ? Player.two : Player.one;
}
