import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAsobiClient extends Mock implements AsobiClient {}

class MockAsobiRealtime extends Mock implements AsobiRealtime {}

class TestPlayer extends PositionComponent with AsobiPlayer {}

class TestProjectile extends PositionComponent with AsobiProjectile {}

void main() {
  late MockAsobiClient mockClient;
  late MockAsobiRealtime mockRealtime;
  late StreamController<MatchState> onMatchState;
  late StreamController<MatchResult> onMatchFinished;

  final gameTester = FlameTester(FlameGame.new);

  setUp(() {
    mockClient = MockAsobiClient();
    mockRealtime = MockAsobiRealtime();
    onMatchState = StreamController<MatchState>.broadcast();
    onMatchFinished = StreamController<MatchResult>.broadcast();

    when(() => mockClient.playerId).thenReturn('my-id');
    when(() => mockClient.realtime).thenReturn(mockRealtime);
    when(() => mockRealtime.onMatchState).thenReturn(onMatchState);
    when(() => mockRealtime.onMatchFinished).thenReturn(onMatchFinished);
  });

  tearDown(() {
    onMatchState.close();
    onMatchFinished.close();
  });

  AsobiNetworkSync createSync({
    void Function(MatchState)? onUpdate,
    void Function(MatchResult)? onFinished,
  }) {
    return AsobiNetworkSync(
      client: mockClient,
      playerBuilder: (id, isLocal) => TestPlayer(),
      projectileBuilder: (id, owner, isLocal) => TestProjectile(),
      pixelsPerUnit: 50,
      onStateUpdate: onUpdate,
      onMatchFinished: onFinished,
    );
  }

  group('AsobiNetworkSync', () {
    gameTester.test('creates player components from MatchState', (game) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      final state = MatchState(
        players: {
          'p1': PlayerState(x: 100, y: 200, hp: 100, kills: 0, deaths: 0),
          'p2': PlayerState(x: 300, y: 400, hp: 80, kills: 1, deaths: 0),
        },
        projectiles: [],
        timeRemaining: 60,
      );

      onMatchState.add(state);
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      expect(sync.players.length, 2);
      expect(sync.players.containsKey('p1'), isTrue);
      expect(sync.players.containsKey('p2'), isTrue);
    });

    gameTester.test('removes player components when they disappear', (
      game,
    ) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      // Add two players
      onMatchState.add(
        MatchState(
          players: {
            'p1': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
            'p2': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
          },
          projectiles: [],
          timeRemaining: 60,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);
      expect(sync.players.length, 2);

      // Remove p2
      onMatchState.add(
        MatchState(
          players: {
            'p1': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
          },
          projectiles: [],
          timeRemaining: 55,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      expect(sync.players.length, 1);
      expect(sync.players.containsKey('p1'), isTrue);
      expect(sync.players.containsKey('p2'), isFalse);
    });

    gameTester.test('creates projectile components from MatchState', (
      game,
    ) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      onMatchState.add(
        MatchState(
          players: {},
          projectiles: [
            ProjectileState(id: 1, owner: 'p1', x: 100, y: 200),
            ProjectileState(id: 2, owner: 'p2', x: 300, y: 400),
          ],
          timeRemaining: 60,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      // Verify projectile components were created by checking children
      final projectiles = sync.children.whereType<TestProjectile>().toList();
      expect(projectiles.length, 2);
    });

    gameTester.test('removes projectile components when they disappear', (
      game,
    ) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      // Add two projectiles
      onMatchState.add(
        MatchState(
          players: {},
          projectiles: [
            ProjectileState(id: 1, owner: 'p1', x: 0, y: 0),
            ProjectileState(id: 2, owner: 'p2', x: 0, y: 0),
          ],
          timeRemaining: 60,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      var projectiles = sync.children.whereType<TestProjectile>().toList();
      expect(projectiles.length, 2);

      // Remove projectile 2
      onMatchState.add(
        MatchState(
          players: {},
          projectiles: [
            ProjectileState(id: 1, owner: 'p1', x: 0, y: 0),
          ],
          timeRemaining: 55,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);
      // Process removals
      game.update(0);

      projectiles = sync.children.whereType<TestProjectile>().toList();
      expect(projectiles.length, 1);
    });

    gameTester.test('calls onStateUpdate callback', (game) async {
      MatchState? receivedState;
      final sync = createSync(onUpdate: (state) => receivedState = state);
      await game.add(sync);
      await game.ready();

      final state = MatchState(
        players: {
          'p1': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
        },
        projectiles: [],
        timeRemaining: 30,
      );

      onMatchState.add(state);
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      expect(receivedState, isNotNull);
      expect(receivedState!.timeRemaining, 30);
      expect(receivedState!.players.containsKey('p1'), isTrue);
    });

    gameTester.test('calls onMatchFinished callback', (game) async {
      MatchResult? receivedResult;
      final sync = createSync(onFinished: (result) => receivedResult = result);
      await game.add(sync);
      await game.ready();

      final result = MatchResult(
        matchId: 'match-123',
        winnerId: 'p1',
        players: {
          'p1': PlayerState(x: 0, y: 0, hp: 50, kills: 5, deaths: 2),
        },
      );

      onMatchFinished.add(result);
      await Future<void>.delayed(Duration.zero);

      expect(receivedResult, isNotNull);
      expect(receivedResult!.matchId, 'match-123');
      expect(receivedResult!.winnerId, 'p1');
    });

    gameTester.test('identifies local player', (game) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      onMatchState.add(
        MatchState(
          players: {
            'my-id': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
            'other': PlayerState(x: 0, y: 0, hp: 100, kills: 0, deaths: 0),
          },
          projectiles: [],
          timeRemaining: 60,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      expect(sync.localPlayer, isNotNull);
      final local = sync.localPlayer as TestPlayer;
      expect(local.isLocal, isTrue);
      expect(local.playerId, 'my-id');
    });

    gameTester.test('timeRemainingMs reflects latest state', (game) async {
      final sync = createSync();
      await game.add(sync);
      await game.ready();

      expect(sync.timeRemainingMs, 0);

      onMatchState.add(
        MatchState(
          players: {},
          projectiles: [],
          timeRemaining: 45.5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      game.update(0.016);

      expect(sync.timeRemainingMs, 45.5);
    });
  });
}
