import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

import 'asobi_player.dart';
import 'asobi_projectile.dart';

/// Callback for building a player component from server data.
///
/// Must return a [PositionComponent] with the [AsobiPlayer] mixin applied.
typedef PlayerBuilder = PositionComponent Function(String playerId, bool isLocal);

/// Callback for building a projectile component from server data.
///
/// Must return a [PositionComponent] with the [AsobiProjectile] mixin applied.
typedef ProjectileBuilder = PositionComponent Function(int id, String owner, bool isLocal);

/// Synchronizes server match state with Flame components.
///
/// Automatically creates, updates, and removes player and projectile
/// children based on the match state received from the server via WebSocket.
///
/// Provide custom [playerBuilder] and [projectileBuilder] callbacks to
/// use your own components with the [AsobiPlayer] and [AsobiProjectile] mixins.
///
/// ```dart
/// add(AsobiNetworkSync(
///   client: asobi,
///   pixelsPerUnit: 50,
///   playerBuilder: (id, isLocal) {
///     final p = MyPlayerSprite()..initPlayer(id: id, local: isLocal);
///     return p;
///   },
///   onStateUpdate: (state) => updateHud(state),
///   onMatchFinished: (result) => showResults(result),
/// ));
/// ```
class AsobiNetworkSync extends Component {
  final AsobiClient client;
  final double pixelsPerUnit;
  final PlayerBuilder? playerBuilder;
  final ProjectileBuilder? projectileBuilder;
  final void Function(Map<String, dynamic> state)? onStateUpdate;
  final void Function(Map<String, dynamic> result)? onMatchFinished;

  final Map<String, PositionComponent> _players = {};
  final Map<int, PositionComponent> _projectiles = {};
  Map<String, dynamic> _latestState = {};
  String _myId = '';

  StreamSubscription? _stateSub;
  StreamSubscription? _finishSub;

  AsobiNetworkSync({
    required this.client,
    this.pixelsPerUnit = 50,
    this.playerBuilder,
    this.projectileBuilder,
    this.onStateUpdate,
    this.onMatchFinished,
  });

  @override
  Future<void> onLoad() async {
    _myId = client.playerId ?? '';

    _stateSub = client.realtime.onMatchState.stream.listen((payload) {
      _latestState = payload;
    });

    _finishSub = client.realtime.onMatchFinished.stream.listen((payload) {
      onMatchFinished?.call(payload);
    });
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    _finishSub?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_latestState.isEmpty) return;

    _syncPlayers();
    _syncProjectiles();
    onStateUpdate?.call(_latestState);
  }

  /// The latest match state received from the server.
  Map<String, dynamic> get latestState => _latestState;

  /// The local player component, if present.
  PositionComponent? get localPlayer => _players[_myId];

  /// All player components by ID.
  Map<String, PositionComponent> get players => Map.unmodifiable(_players);

  /// Time remaining in milliseconds.
  double get timeRemainingMs =>
      (_latestState['time_remaining'] as num?)?.toDouble() ?? 0;

  void _syncPlayers() {
    final players = _latestState['players'] as Map<String, dynamic>? ?? {};
    final seenIds = <String>{};

    for (final entry in players.entries) {
      final pid = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final isMe = pid == _myId;
      seenIds.add(pid);

      if (!_players.containsKey(pid)) {
        final player = playerBuilder?.call(pid, isMe) ??
            _defaultPlayer(pid, isMe);
        _players[pid] = player;
        add(player);
      }

      (_players[pid]! as AsobiPlayer).applyServerState(data, pixelsPerUnit);
    }

    for (final pid in _players.keys.toList()) {
      if (!seenIds.contains(pid)) {
        _players[pid]!.removeFromParent();
        _players.remove(pid);
      }
    }
  }

  void _syncProjectiles() {
    final projectiles = _latestState['projectiles'] as List<dynamic>? ?? [];
    final seenIds = <int>{};

    for (final proj in projectiles) {
      final data = proj as Map<String, dynamic>;
      final id = (data['id'] as num).toInt();
      final owner = data['owner'] as String? ?? '';
      final isLocal = owner == _myId;
      seenIds.add(id);

      if (!_projectiles.containsKey(id)) {
        final projectile = projectileBuilder?.call(id, owner, isLocal) ??
            _defaultProjectile(id, owner, isLocal);
        _projectiles[id] = projectile;
        add(projectile);
      }

      (_projectiles[id]! as AsobiProjectile).applyServerState(data, pixelsPerUnit);
    }

    for (final id in _projectiles.keys.toList()) {
      if (!seenIds.contains(id)) {
        _projectiles[id]!.removeFromParent();
        _projectiles.remove(id);
      }
    }
  }

  PositionComponent _defaultPlayer(String pid, bool isMe) {
    return _DefaultPlayer(size: Vector2.all(0.64))
      ..initPlayer(id: pid, local: isMe);
  }

  PositionComponent _defaultProjectile(int id, String owner, bool isLocal) {
    return _DefaultProjectile(radius: 0.15)
      ..initProjectile(id: id, ownerId: owner, local: isLocal);
  }
}

/// Minimal default player — a simple circle. Override via [playerBuilder].
class _DefaultPlayer extends CircleComponent with AsobiPlayer {
  _DefaultPlayer({required Vector2 size})
      : super(radius: size.x / 2, anchor: Anchor.center, priority: 5);
}

/// Minimal default projectile — a small circle. Override via [projectileBuilder].
class _DefaultProjectile extends CircleComponent with AsobiProjectile {
  _DefaultProjectile({required double radius})
      : super(radius: radius, anchor: Anchor.center, priority: 3);
}
