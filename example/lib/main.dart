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

class ArenaGame extends FlameGame
    with HasAsobi, KeyboardEvents, MouseMovementDetector, TapCallbacks {
  late final AsobiInputSender _input;
  late final AsobiNetworkSync _sync;

  @override
  Future<void> onLoad() async {
    // 1. Connect to backend
    await asobiConnect('localhost', port: 8084);
    await asobi.auth.register('player_${DateTime.now().millisecond}', 'pass');
    await asobi.realtime.connect();

    // 2. Find a match
    asobi.realtime.onMatchmakerMatched.stream.listen((_) => _startGame());
    await asobi.realtime.addToMatchmaker(mode: 'arena');
  }

  void _startGame() {
    // 3. Add network sync — handles all entity lifecycle
    _sync = AsobiNetworkSync(
      client: asobi,
      pixelsPerUnit: 50,
      onStateUpdate: (_) {
        // Access local player stats via _sync.localPlayer
      },
      onMatchFinished: (result) {
        // Handle game over
      },
    );
    world.add(_sync);

    // 4. Add input sender — captures WASD + mouse
    _input = AsobiInputSender(client: asobi, pixelsPerUnit: 50);
    world.add(_input);

    // 5. Setup camera
    camera.viewfinder.position = Vector2(8, 6); // center of 800x600 / 50
    camera.viewfinder.zoom = size.y / 13;

    // 6. Arena bounds
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
