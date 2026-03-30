import 'dart:ui';
import 'package:flame/components.dart';

/// A networked projectile component.
///
/// Position is set directly from server state (no interpolation —
/// projectiles move fast enough that lerping looks worse).
class AsobiProjectile extends CircleComponent {
  final int projectileId;
  final String owner;
  final bool isLocal;

  AsobiProjectile({
    required this.projectileId,
    required this.owner,
    this.isLocal = false,
    super.position,
    double radius = 0.15,
    super.anchor = Anchor.center,
    super.priority = 3,
  }) : super(radius: radius) {
    paint = Paint()..color = isLocal ? const Color(0xFFFFFF00) : const Color(0xFFFFFFFF);
  }

  /// Apply position from server state.
  void applyServerState(Map<String, dynamic> state, double pixelsPerUnit) {
    position.setValues(
      (state['x'] as num).toDouble() / pixelsPerUnit,
      (state['y'] as num).toDouble() / pixelsPerUnit,
    );
  }
}
