import 'dart:async';
import 'package:asobi/asobi.dart';
import 'package:flame/components.dart';

/// Factory for creating entity components in a world.
/// Called when a new entity appears in the zone.
typedef EntityBuilder = PositionComponent Function(
  String entityId,
  Map<String, dynamic> data,
  bool isLocal,
);

/// Synchronises world server zone state with local Flame components.
///
/// Listens to [AsobiClient.realtime] for [WorldTick] updates and
/// applies entity deltas (add/update/remove) to maintain a live view
/// of the player's visible zone entities.
class AsobiWorldSync extends Component {
  final AsobiClient client;
  final double pixelsPerUnit;
  final EntityBuilder entityBuilder;
  final void Function(WorldTick tick)? onTick;

  final Map<String, PositionComponent> _entities = {};
  final Map<String, Map<String, dynamic>> _entityState = {};
  String _myId = '';

  StreamSubscription<WorldTick>? _tickSub;

  AsobiWorldSync({
    required this.client,
    required this.entityBuilder,
    this.pixelsPerUnit = 1.0,
    this.onTick,
  });

  @override
  Future<void> onLoad() async {
    _myId = client.playerId ?? '';

    _tickSub = client.realtime.onWorldTick.stream.listen((tick) {
      _applyDeltas(tick.updates);
      onTick?.call(tick);
    });
  }

  @override
  void onRemove() {
    _tickSub?.cancel();
    super.onRemove();
  }

  /// The local player's component, or `null` if not yet spawned.
  PositionComponent? get localPlayer => _entities[_myId];

  /// All current entity components keyed by ID.
  Map<String, PositionComponent> get entities => Map.unmodifiable(_entities);

  /// Full state for an entity (accumulated from deltas).
  Map<String, dynamic>? entityState(String id) => _entityState[id];

  void _applyDeltas(List<EntityDelta> deltas) {
    for (final delta in deltas) {
      switch (delta.op) {
        case 'a':
          _addEntity(delta);
        case 'u':
          _updateEntity(delta);
        case 'r':
          _removeEntity(delta.id);
      }
    }
  }

  void _addEntity(EntityDelta delta) {
    final id = delta.id;
    final isLocal = id == _myId;

    _entityState[id] = Map<String, dynamic>.from(delta.data);

    final component = entityBuilder(id, delta.data, isLocal);
    component.position.x = delta.x / pixelsPerUnit;
    component.position.y = delta.y / pixelsPerUnit;
    _entities[id] = component;
    add(component);
  }

  void _updateEntity(EntityDelta delta) {
    final id = delta.id;

    // Accumulate state
    final state = _entityState[id];
    if (state != null) {
      state.addAll(delta.data);
    } else {
      // Got an update for unknown entity — treat as add
      _addEntity(EntityDelta(op: 'a', id: id, data: delta.data));
      return;
    }

    final component = _entities[id];
    if (component == null) return;

    // Update position if present in delta
    if (delta.data.containsKey('x') || delta.data.containsKey('y')) {
      final x = (state['x'] as num?)?.toDouble() ?? component.position.x;
      final y = (state['y'] as num?)?.toDouble() ?? component.position.y;
      component.position.x = x / pixelsPerUnit;
      component.position.y = y / pixelsPerUnit;
    }

    // Update angle/heading if present
    if (delta.data.containsKey('heading')) {
      component.angle = ((state['heading'] as num?)?.toDouble() ?? 0) *
          3.14159265358979 /
          180.0;
    }
  }

  void _removeEntity(String id) {
    _entities[id]?.removeFromParent();
    _entities.remove(id);
    _entityState.remove(id);
  }
}
