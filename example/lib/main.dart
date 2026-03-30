import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show runApp;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flame_asobi/flame_asobi.dart';

/// Minimal multiplayer arena game using flame_asobi.
void main() {
  runApp(GameWidget(game: ArenaGame()));
}

/// Custom player with sprite-friendly rendering.
class ArenaPlayer extends CircleComponent with AsobiPlayer {
  ArenaPlayer({required Vector2 size})
      : super(radius: size.x / 2, anchor: Anchor.center, priority: 5);

  @override
  void update(double dt) {
    super.update(dt);
    paint.color = isDead
        ? const Color(0xFF888888)
        : isLocal
            ? const Color(0xFF00FFFF)
            : const Color(0xFFFF4444);
  }
}

/// Custom projectile.
class ArenaBullet extends CircleComponent with AsobiProjectile {
  ArenaBullet()
      : super(radius: 0.15, anchor: Anchor.center, priority: 3);

  @override
  void update(double dt) {
    super.update(dt);
    paint.color = isLocal ? const Color(0xFFFFFF00) : const Color(0xFFFFFFFF);
  }
}

class ArenaGame extends FlameGame
    with HasAsobi, KeyboardEvents, MouseMovementDetector, TapCallbacks {
  late final AsobiInputSender _input;
  late final AsobiNetworkSync _sync;

  @override
  Future<void> onLoad() async {
    await asobiConnect('localhost', port: 8084);
    await asobi.auth.register('player_${DateTime.now().millisecond}', 'pass');
    await asobi.realtime.connect();

    asobi.realtime.onMatchmakerMatched.stream.listen((_) => _startGame());
    await asobi.realtime.addToMatchmaker(mode: 'arena');
  }

  void _startGame() {
    _sync = AsobiNetworkSync(
      client: asobi,
      pixelsPerUnit: 50,
      playerBuilder: (id, isLocal) =>
          ArenaPlayer(size: Vector2.all(0.64))..initPlayer(id: id, local: isLocal),
      projectileBuilder: (id, owner, isLocal) =>
          ArenaBullet()..initProjectile(id: id, ownerId: owner, local: isLocal),
      onMatchFinished: (result) {
        // Handle game over
      },
    );
    world.add(_sync);

    _input = AsobiInputSender(client: asobi, pixelsPerUnit: 50);
    world.add(_input);

    camera.viewfinder.position = Vector2(8, 6);
    camera.viewfinder.zoom = size.y / 13;

    world.add(RectangleComponent(
      size: Vector2(16, 12),
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04,
    ));
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _input.onKeyEvent(event, keysPressed);
    return KeyEventResult.handled;
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    _input.updateMousePosition(camera.viewfinder.globalToLocal(info.eventPosition.global));
  }

  @override
  void onTapDown(TapDownEvent event) {
    _input.setMouseDown(true);
    _input.updateMousePosition(camera.viewfinder.globalToLocal(event.canvasPosition));
  }

  @override
  void onTapUp(TapUpEvent event) => _input.setMouseDown(false);
}
