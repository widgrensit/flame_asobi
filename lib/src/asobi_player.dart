import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Mixin for player entities that receive server state updates.
///
/// Mix onto a [PositionComponent] to get automatic position interpolation,
/// health tracking, and kill/death stats from the server.
mixin AsobiPlayer on PositionComponent {
  /// The server-assigned player ID.
  late final String playerId;

  /// Whether this player represents the local user.
  bool isLocal = false;

  /// Interpolation speed for smoothing position updates (0..1).
  double lerpSpeed = 0.3;

  /// Current hit points.
  int hp = 100;

  /// Number of kills this match.
  int kills = 0;

  /// Number of deaths this match.
  int deaths = 0;

  /// Display label (defaults to "YOU" for local, truncated ID otherwise).
  String label = '';

  Vector2 _targetPosition = Vector2.zero();

  /// Initializes player state. Called automatically by `AsobiNetworkSync`.
  void initPlayer({
    required String id,
    bool local = false,
    double lerp = 0.3,
    String? playerLabel,
  }) {
    playerId = id;
    isLocal = local;
    lerpSpeed = lerp;
    label =
        playerLabel ??
        (local ? 'YOU' : id.substring(0, (id.length < 8) ? id.length : 8));
    _targetPosition = position.clone();
  }

  /// Applies authoritative server state to this player.
  void applyServerState(PlayerState state, double pixelsPerUnit) {
    _targetPosition = Vector2(
      state.x / pixelsPerUnit,
      state.y / pixelsPerUnit,
    );
    hp = state.hp;
    kills = state.kills;
    deaths = state.deaths;
  }

  /// Whether this player is dead.
  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    position.lerp(_targetPosition, lerpSpeed);
  }
}
