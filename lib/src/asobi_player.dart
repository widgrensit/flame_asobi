import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;

/// A networked player component with position interpolation.
///
/// Updates position smoothly via [applyServerState] which lerps
/// from the current position to the server-provided target.
class AsobiPlayer extends PositionComponent {
  final String playerId;
  final bool isLocal;
  final double lerpSpeed;

  Color color;
  int hp;
  int kills;
  int deaths;
  String label;

  Vector2 _targetPosition = Vector2.zero();

  AsobiPlayer({
    required this.playerId,
    this.isLocal = false,
    this.lerpSpeed = 0.3,
    this.color = const Color(0xFFFF4444),
    this.hp = 100,
    this.kills = 0,
    this.deaths = 0,
    String? label,
    super.position,
    super.size,
    super.anchor = Anchor.center,
    super.priority = 5,
  }) : label = label ?? (isLocal ? 'YOU' : playerId.substring(0, 8)) {
    _targetPosition = position.clone();
  }

  /// Apply state received from the server. Position is interpolated.
  void applyServerState(Map<String, dynamic> state, double pixelsPerUnit) {
    _targetPosition = Vector2(
      (state['x'] as num).toDouble() / pixelsPerUnit,
      (state['y'] as num).toDouble() / pixelsPerUnit,
    );
    hp = (state['hp'] as num?)?.toInt() ?? 0;
    kills = (state['kills'] as num?)?.toInt() ?? 0;
    deaths = (state['deaths'] as num?)?.toInt() ?? 0;
  }

  bool get isDead => hp <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    position.lerp(_targetPosition, lerpSpeed);
  }

  @override
  void render(Canvas canvas) {
    // Body circle
    final bodyPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      bodyPaint,
    );

    // HP bar background
    final hpBgPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, size.y + 0.05, size.x, 0.08), hpBgPaint);

    // HP bar
    final hpPaint = Paint()..color = const Color(0xFF00FF00);
    final hpWidth = size.x * (hp / 100).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, size.y + 0.05, hpWidth, 0.08), hpPaint);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 1.4, color: const Color(0xFFFFFFFF)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, -1.6));
  }
}
