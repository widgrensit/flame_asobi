import 'package:flame/components.dart';

/// A mixin for networked player components with position interpolation.
///
/// Apply to any [PositionComponent] to add multiplayer state synchronization.
/// The component's position is smoothly interpolated towards the server target.
///
/// ```dart
/// class MyPlayer extends SpriteComponent with AsobiPlayer {
///   MyPlayer({required super.playerId});
/// }
/// ```
mixin AsobiPlayer on PositionComponent {
  late final String playerId;
  bool isLocal = false;
  double lerpSpeed = 0.3;

  int hp = 100;
  int kills = 0;
  int deaths = 0;
  String label = '';

  Vector2 _targetPosition = Vector2.zero();

  void initPlayer({required String id, bool local = false, double lerp = 0.3, String? playerLabel}) {
    playerId = id;
    isLocal = local;
    lerpSpeed = lerp;
    label = playerLabel ?? (local ? 'YOU' : id.substring(0, (id.length < 8) ? id.length : 8));
    _targetPosition = position.clone();
  }

  /// Apply state received from the server. Position is interpolated.
  void applyServerState(Map<String, dynamic> state, double pixelsPerUnit) {
    _targetPosition = Vector2(
      (state['x'] as num).toDouble() / pixelsPerUnit,
      (state['y'] as num).toDouble() / pixelsPerUnit,
    );
    hp = (state['hp'] as num?)?.toInt() ?? 0;
    kills = (state['kills'] as num?)?.toInt() ?? 0;
    deaths = (state['deaths'] as num?)?.toInt() ?? 0;
  }

  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    position.lerp(_targetPosition, lerpSpeed);
  }
}
