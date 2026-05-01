import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// Mixin that captures keyboard and mouse input and sends it to the server.
///
/// Mix into your `FlameGame` alongside `HasAsobi` to automatically
/// send `match.input` at a configurable tick rate.
///
/// The default payload shape matches `sdk_demo_backend`:
/// `{move_x, move_y, shoot, aim_x, aim_y}`. Override [buildMatchInput]
/// to emit a different shape (for example, the boolean flag shape used
/// by `asobi_arena`).
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

  /// Builds the `match.input` payload sent to the server each tick.
  /// Return `null` to skip a send (e.g. when no input is active).
  ///
  /// Default emits `{move_x, move_y, shoot, aim_x, aim_y}` matching
  /// `sdk_demo_backend`. Override for game-specific shapes.
  Map<String, dynamic>? buildMatchInput({
    required Set<LogicalKeyboardKey> keysPressed,
    required Vector2 mouseWorld,
    required bool mouseDown,
  }) {
    final mx = (keysPressed.contains(keyRight) ? 1 : 0) -
        (keysPressed.contains(keyLeft) ? 1 : 0);
    final my = (keysPressed.contains(keyDown) ? 1 : 0) -
        (keysPressed.contains(keyUp) ? 1 : 0);
    final shoot = mouseDown || keysPressed.contains(keyShoot);

    if (mx == 0 && my == 0 && !shoot) {
      return null;
    }
    return {
      'move_x': mx,
      'move_y': my,
      'shoot': shoot,
      'aim_x': mouseWorld.x * inputPixelsPerUnit,
      'aim_y': mouseWorld.y * inputPixelsPerUnit,
    };
  }

  @override
  void update(double dt) {
    super.update(dt);

    _inputAccumulator += dt;
    if (_inputAccumulator < inputSendInterval) {
      return;
    }
    _inputAccumulator = 0;

    final input = buildMatchInput(
      keysPressed: _keysPressed,
      mouseWorld: _mouseWorld,
      mouseDown: _mouseDown,
    );
    if (input != null) {
      inputClient.realtime.sendMatchInput(input);
    }
  }
}
