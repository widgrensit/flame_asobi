import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

/// Component that captures keyboard and mouse input and sends it
/// to the Asobi backend as match input.
///
/// Attach to a [FlameGame] that uses [KeyboardEvents] and [TapCallbacks].
///
/// ```dart
/// add(AsobiInputSender(
///   client: asobi,
///   pixelsPerUnit: 50,
/// ));
/// ```
class AsobiInputSender extends Component with KeyboardHandler {
  final AsobiClient client;
  final double pixelsPerUnit;

  final Set<LogicalKeyboardKey> _keysPressed = {};
  Vector2 _mouseWorld = Vector2.zero();
  bool _mouseDown = false;

  /// Keys mapped to movement directions. Override to customize.
  LogicalKeyboardKey keyUp;
  LogicalKeyboardKey keyDown;
  LogicalKeyboardKey keyLeft;
  LogicalKeyboardKey keyRight;
  LogicalKeyboardKey keyShoot;

  AsobiInputSender({
    required this.client,
    this.pixelsPerUnit = 50,
    this.keyUp = LogicalKeyboardKey.keyW,
    this.keyDown = LogicalKeyboardKey.keyS,
    this.keyLeft = LogicalKeyboardKey.keyA,
    this.keyRight = LogicalKeyboardKey.keyD,
    this.keyShoot = LogicalKeyboardKey.space,
  });

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

    client.realtime.sendMatchInput({
      'up': up,
      'down': down,
      'left': left,
      'right': right,
      'shoot': shoot,
      'aim_x': _mouseWorld.x * pixelsPerUnit,
      'aim_y': _mouseWorld.y * pixelsPerUnit,
    });
  }
}
