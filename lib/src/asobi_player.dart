import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

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

  void applyServerState(PlayerState state, double pixelsPerUnit) {
    _targetPosition = Vector2(
      state.x / pixelsPerUnit,
      state.y / pixelsPerUnit,
    );
    hp = state.hp;
    kills = state.kills;
    deaths = state.deaths;
  }

  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    position.lerp(_targetPosition, lerpSpeed);
  }
}
