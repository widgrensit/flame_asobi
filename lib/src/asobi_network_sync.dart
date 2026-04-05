import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';
import 'package:flame_asobi/src/asobi_player.dart';
import 'package:flame_asobi/src/asobi_projectile.dart';

/// Factory for creating player components.
typedef PlayerBuilder =
    PositionComponent Function(String playerId, {required bool isLocal});

/// Factory for creating projectile components.
typedef ProjectileBuilder =
    PositionComponent Function(int id, String owner, {required bool isLocal});

/// Synchronises server match state with local Flame components.
///
/// Listens to [AsobiClient.realtime] for [MatchState] updates and
/// automatically spawns, updates, and removes player and projectile
/// entities to match the server state.
class AsobiNetworkSync extends Component {
  /// The client providing the realtime match stream.
  final AsobiClient client;

  /// Conversion factor from server pixel coordinates to world units.
  final double pixelsPerUnit;

  /// Factory used to create player components.
  final PlayerBuilder playerBuilder;

  /// Factory used to create projectile components.
  final ProjectileBuilder projectileBuilder;

  /// Optional callback invoked on every state update.
  final void Function(MatchState state)? onStateUpdate;

  /// Optional callback invoked when the match finishes.
  final void Function(MatchResult result)? onMatchFinished;

  final Map<String, PositionComponent> _players = {};
  final Map<int, PositionComponent> _projectiles = {};
  MatchState? _latestState;
  String _myId = '';

  StreamSubscription<MatchState>? _stateSub;
  StreamSubscription<MatchResult>? _finishSub;

  /// Creates a network sync component.
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
    if (state == null) {
      return;
    }

    _syncPlayers(state);
    _syncProjectiles(state);
    onStateUpdate?.call(state);
  }

  /// The most recently received match state, or `null` if none yet.
  MatchState? get latestState => _latestState;

  /// The local player's component, or `null` if not yet spawned.
  PositionComponent? get localPlayer => _players[_myId];

  /// An unmodifiable view of all current player components keyed by ID.
  Map<String, PositionComponent> get players => Map.unmodifiable(_players);

  /// Remaining match time in milliseconds from the latest state.
  double get timeRemainingMs => _latestState?.timeRemaining ?? 0;

  void _syncPlayers(MatchState state) {
    final seenIds = <String>{};

    for (final entry in state.players.entries) {
      final playerId = entry.key;
      final playerState = entry.value;
      final isMe = playerId == _myId;
      seenIds.add(playerId);

      if (!_players.containsKey(playerId)) {
        final player = playerBuilder(playerId, isLocal: isMe);
        (player as AsobiPlayer).initPlayer(id: playerId, local: isMe);
        _players[playerId] = player;
        add(player);
      }

      (_players[playerId]! as AsobiPlayer).applyServerState(
        playerState,
        pixelsPerUnit,
      );
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
        final projectile = projectileBuilder(
          projectileId,
          ownerId,
          isLocal: isLocal,
        );
        (projectile as AsobiProjectile).initProjectile(
          id: projectileId,
          ownerId: ownerId,
          local: isLocal,
        );
        _projectiles[projectileId] = projectile;
        add(projectile);
      }

      (_projectiles[projectileId]! as AsobiProjectile).applyServerState(
        projectileState,
        pixelsPerUnit,
      );
    }

    for (final projectileId in _projectiles.keys.toList()) {
      if (!seenIds.contains(projectileId)) {
        _projectiles[projectileId]!.removeFromParent();
        _projectiles.remove(projectileId);
      }
    }
  }
}
