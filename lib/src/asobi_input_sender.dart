import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

/// Mixin that captures keyboard and mouse input and sends it
/// to the Asobi backend as match input.
///
/// Apply to any [Component] that uses [KeyboardHandler].
///
/// ```dart
/// class MyGame extends FlameGame with HasAsobi, HasAsobiInput, KeyboardEvents {
///   @override
///   AsobiClient get inputClient => asobi;
/// }
/// ```
mixin HasAsobiInput on Component, KeyboardHandler {
  /// The Asobi client to send input through.
  AsobiClient get inputClient;

  /// Pixels per world unit for coordinate conversion.
  double get inputPixelsPerUnit => 50;

  final Set<LogicalKeyboardKey> _keysPressed = {};
  Vector2 _mouseWorld = Vector2.zero();
  bool _mouseDown = false;

  /// Keys mapped to movement directions. Override to customize.
  LogicalKeyboardKey get keyUp => LogicalKeyboardKey.keyW;
  LogicalKeyboardKey get keyDown => LogicalKeyboardKey.keyS;
  LogicalKeyboardKey get keyLeft => LogicalKeyboardKey.keyA;
  LogicalKeyboardKey get keyRight => LogicalKeyboardKey.keyD;
  LogicalKeyboardKey get keyShoot => LogicalKeyboardKey.space;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);
    return false;
  }

  /// Call from the game's mouse/tap handlers to update aim position.
  void updateMousePosition(Vector2 worldPosition) {
    _mouseWorld = worldPosition;
  }

  /// Call from the game's tap handlers.
  void setMouseDown(bool down) {
    _mouseDown = down;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final up = _keysPressed.contains(keyUp);
    final down = _keysPressed.contains(keyDown);
    final left = _keysPressed.contains(keyLeft);
    final right = _keysPressed.contains(keyRight);
    final shoot = _mouseDown || _keysPressed.contains(keyShoot);

    if (!(up || down || left || right || shoot)) return;

    inputClient.realtime.sendMatchInput({
      'up': up,
      'down': down,
      'left': left,
      'right': right,
      'shoot': shoot,
      'aim_x': _mouseWorld.x * inputPixelsPerUnit,
      'aim_y': _mouseWorld.y * inputPixelsPerUnit,
    });
  }
}
