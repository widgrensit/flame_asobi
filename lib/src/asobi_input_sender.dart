import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// Mixin that captures keyboard and mouse input and sends it to the server.
///
/// Mix into your `FlameGame` alongside `HasAsobi` to automatically
/// send player input at a configurable tick rate.
mixin HasAsobiInput on Component {
  /// The [AsobiClient] used to send input messages.
  AsobiClient get inputClient;

  /// Conversion factor from world units to server pixel coordinates.
  double get inputPixelsPerUnit => 50;

  /// Minimum interval between input sends in seconds.
  /// Default 0.1 (10Hz) to match typical server tick rate.
  double get inputSendInterval => 0.1;

  final Set<LogicalKeyboardKey> _keysPressed = {};
  Vector2 _mouseWorld = Vector2.zero();
  bool _mouseDown = false;
  double _inputAccumulator = 0;

  /// Key binding for moving up.
  LogicalKeyboardKey get keyUp => LogicalKeyboardKey.keyW;

  /// Key binding for moving down.
  LogicalKeyboardKey get keyDown => LogicalKeyboardKey.keyS;

  /// Key binding for moving left.
  LogicalKeyboardKey get keyLeft => LogicalKeyboardKey.keyA;

  /// Key binding for moving right.
  LogicalKeyboardKey get keyRight => LogicalKeyboardKey.keyD;

  /// Key binding for shooting.
  LogicalKeyboardKey get keyShoot => LogicalKeyboardKey.space;

  /// Call from your game's key event handler to track pressed keys.
  void handleKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);
  }

  /// Updates the current mouse position in world coordinates.
  // ignore: use_setters_to_change_properties
  void updateMousePosition(Vector2 worldPosition) {
    _mouseWorld = worldPosition;
  }

  /// Sets whether the mouse button is currently pressed.
  // ignore: use_setters_to_change_properties
  void setMouseDown({required bool down}) {
    _mouseDown = down;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _inputAccumulator += dt;
    if (_inputAccumulator < inputSendInterval) {
      return;
    }
    _inputAccumulator = 0;

    final up = _keysPressed.contains(keyUp);
    final down = _keysPressed.contains(keyDown);
    final left = _keysPressed.contains(keyLeft);
    final right = _keysPressed.contains(keyRight);
    final shoot = _mouseDown || _keysPressed.contains(keyShoot);

    if (!(up || down || left || right || shoot)) {
      return;
    }

    inputClient.realtime.sendMatchInput(
      MatchInput(
        up: up,
        down: down,
        left: left,
        right: right,
        shoot: shoot,
        aimX: _mouseWorld.x * inputPixelsPerUnit,
        aimY: _mouseWorld.y * inputPixelsPerUnit,
      ),
    );
  }
}
