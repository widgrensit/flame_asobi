import 'dart:async';
import 'dart:ui';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

import 'asobi_player.dart';
import 'asobi_projectile.dart';

/// Callback for building a player component from server data.
typedef PlayerBuilder = AsobiPlayer Function(String playerId, bool isLocal);

/// Callback for building a projectile component from server data.
typedef ProjectileBuilder = AsobiProjectile Function(int id, String owner, bool isLocal);

/// Synchronizes server match state with Flame components.
///
/// Automatically creates, updates, and removes [AsobiPlayer] and
/// [AsobiProjectile] children based on the match state received
/// from the server via WebSocket.
///
/// ```dart
/// add(AsobiNetworkSync(
///   client: asobi,
///   pixelsPerUnit: 50,
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

  final Map<String, AsobiPlayer> _players = {};
  final Map<int, AsobiProjectile> _projectiles = {};
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
  AsobiPlayer? get localPlayer => _players[_myId];

  /// All player components by ID.
  Map<String, AsobiPlayer> get players => Map.unmodifiable(_players);

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

      final player = _players[pid]!;
      player.applyServerState(data, pixelsPerUnit);

      if (player.isDead) {
        player.color = const Color(0xFF888888);
      } else if (isMe) {
        player.color = const Color(0xFF00FFFF);
      } else {
        player.color = const Color(0xFFFF4444);
      }
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
            AsobiProjectile(projectileId: id, owner: owner, isLocal: isLocal);
        _projectiles[id] = projectile;
        add(projectile);
      }

      _projectiles[id]!.applyServerState(data, pixelsPerUnit);
    }

    for (final id in _projectiles.keys.toList()) {
      if (!seenIds.contains(id)) {
        _projectiles[id]!.removeFromParent();
        _projectiles.remove(id);
      }
    }
  }

  AsobiPlayer _defaultPlayer(String pid, bool isMe) {
    return AsobiPlayer(
      playerId: pid,
      isLocal: isMe,
      size: Vector2.all(0.64),
    );
  }
}
