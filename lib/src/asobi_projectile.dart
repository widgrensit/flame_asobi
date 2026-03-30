import 'package:flame/components.dart';

/// A mixin for networked projectile components.
///
/// Apply to any [PositionComponent] to add server state synchronization.
/// Position is set directly (no interpolation — projectiles move too fast).
///
/// ```dart
/// class MyBullet extends CircleComponent with AsobiProjectile {
///   MyBullet({required super.radius});
/// }
/// ```
mixin AsobiProjectile on PositionComponent {
  late final int projectileId;
  late final String owner;
  bool isLocal = false;

  void initProjectile({required int id, required String ownerId, bool local = false}) {
    projectileId = id;
    owner = ownerId;
    isLocal = local;
  }

  /// Apply position from server state.
  void applyServerState(Map<String, dynamic> state, double pixelsPerUnit) {
    position.setValues(
      (state['x'] as num).toDouble() / pixelsPerUnit,
      (state['y'] as num).toDouble() / pixelsPerUnit,
    );
  }
}
