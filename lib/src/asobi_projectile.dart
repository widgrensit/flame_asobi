import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Mixin for projectile entities that receive server state updates.
///
/// Mix onto a [PositionComponent] to get automatic position syncing
/// from the server. Unlike `AsobiPlayer`, projectiles snap to position
/// without interpolation.
mixin AsobiProjectile on PositionComponent {
  /// The server-assigned projectile ID.
  late final int projectileId;

  /// The player ID of the projectile's owner.
  late final String owner;

  /// Whether this projectile was fired by the local player.
  bool isLocal = false;

  /// Initializes projectile state. Called automatically by `AsobiNetworkSync`.
  void initProjectile({
    required int id,
    required String ownerId,
    bool local = false,
  }) {
    projectileId = id;
    owner = ownerId;
    isLocal = local;
  }

  /// Applies authoritative server state to this projectile.
  void applyServerState(ProjectileState state, double pixelsPerUnit) {
    position.setValues(
      state.x / pixelsPerUnit,
      state.y / pixelsPerUnit,
    );
  }
}
