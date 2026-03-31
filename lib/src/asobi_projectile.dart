import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

mixin AsobiProjectile on PositionComponent {
  late final int projectileId;
  late final String owner;
  bool isLocal = false;

  void initProjectile({required int id, required String ownerId, bool local = false}) {
    projectileId = id;
    owner = ownerId;
    isLocal = local;
  }

  void applyServerState(ProjectileState state, double pixelsPerUnit) {
    position.setValues(
      state.x / pixelsPerUnit,
      state.y / pixelsPerUnit,
    );
  }
}
