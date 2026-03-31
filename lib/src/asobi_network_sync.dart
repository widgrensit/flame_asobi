import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

import 'asobi_player.dart';
import 'asobi_projectile.dart';

typedef PlayerBuilder = PositionComponent Function(String playerId, bool isLocal);

typedef ProjectileBuilder = PositionComponent Function(int id, String owner, bool isLocal);

class AsobiNetworkSync extends Component {
  final AsobiClient client;
  final double pixelsPerUnit;
  final PlayerBuilder playerBuilder;
  final ProjectileBuilder projectileBuilder;
  final void Function(MatchState state)? onStateUpdate;
  final void Function(MatchResult result)? onMatchFinished;

  final Map<String, PositionComponent> _players = {};
  final Map<int, PositionComponent> _projectiles = {};
  MatchState? _latestState;
  String _myId = '';

  StreamSubscription<MatchState>? _stateSub;
  StreamSubscription<MatchResult>? _finishSub;

  AsobiNetworkSync({
    required this.client,
    required this.playerBuilder,
    required this.projectileBuilder,
    this.pixelsPerUnit = 50,
    this.onStateUpdate,
    this.onMatchFinished,
  });

  @override
  Future<void> onLoad() async {
    _myId = client.playerId ?? '';

    _stateSub = client.realtime.onMatchState.stream.listen((state) {
      _latestState = state;
    });

    _finishSub = client.realtime.onMatchFinished.stream.listen((result) {
      onMatchFinished?.call(result);
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
    final state = _latestState;
    if (state == null) return;

    _syncPlayers(state);
    _syncProjectiles(state);
    onStateUpdate?.call(state);
  }

  MatchState? get latestState => _latestState;

  PositionComponent? get localPlayer => _players[_myId];

  Map<String, PositionComponent> get players => Map.unmodifiable(_players);

  double get timeRemainingMs => _latestState?.timeRemaining ?? 0;

  void _syncPlayers(MatchState state) {
    final seenIds = <String>{};

    for (final entry in state.players.entries) {
      final playerId = entry.key;
      final playerState = entry.value;
      final isMe = playerId == _myId;
      seenIds.add(playerId);

      if (!_players.containsKey(playerId)) {
        final player = playerBuilder(playerId, isMe);
        (player as AsobiPlayer).initPlayer(id: playerId, local: isMe);
        _players[playerId] = player;
        add(player);
      }

      (_players[playerId]! as AsobiPlayer).applyServerState(playerState, pixelsPerUnit);
    }

    for (final playerId in _players.keys.toList()) {
      if (!seenIds.contains(playerId)) {
        _players[playerId]!.removeFromParent();
        _players.remove(playerId);
      }
    }
  }

  void _syncProjectiles(MatchState state) {
    final seenIds = <int>{};

    for (final projectileState in state.projectiles) {
      final projectileId = projectileState.id;
      final ownerId = projectileState.owner;
      final isLocal = ownerId == _myId;
      seenIds.add(projectileId);

      if (!_projectiles.containsKey(projectileId)) {
        final projectile = projectileBuilder(projectileId, ownerId, isLocal);
        (projectile as AsobiProjectile).initProjectile(id: projectileId, ownerId: ownerId, local: isLocal);
        _projectiles[projectileId] = projectile;
        add(projectile);
      }

      (_projectiles[projectileId]! as AsobiProjectile).applyServerState(projectileState, pixelsPerUnit);
    }

    for (final projectileId in _projectiles.keys.toList()) {
      if (!seenIds.contains(projectileId)) {
        _projectiles[projectileId]!.removeFromParent();
        _projectiles.remove(projectileId);
      }
    }
  }
}
