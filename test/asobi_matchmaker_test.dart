import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAsobiClient extends Mock implements AsobiClient {}

class MockAsobiRealtime extends Mock implements AsobiRealtime {}

class TestMatchmaker extends Component with HasAsobiMatchmaker {
  final AsobiClient _client;
  bool connectedCalled = false;
  MatchmakerMatch? lastMatch;
  RealtimeError? lastError;

  TestMatchmaker(this._client);

  @override
  AsobiClient get matchmakerClient => _client;

  @override
  void onMatchmakerConnected() {
    connectedCalled = true;
  }

  @override
  void onMatchmakerMatched(MatchmakerMatch match) {
    lastMatch = match;
  }

  @override
  void onMatchmakerError(RealtimeError error) {
    lastError = error;
  }
}

final gameTester = FlameTester(FlameGame.new);

void main() {
  late MockAsobiClient mockClient;
  late MockAsobiRealtime mockRealtime;
  late StreamController<void> onConnected;
  late StreamController<MatchmakerMatch> onMatchmakerMatched;
  late StreamController<RealtimeError> onError;

  setUp(() {
    mockClient = MockAsobiClient();
    mockRealtime = MockAsobiRealtime();
    onConnected = StreamController<void>.broadcast();
    onMatchmakerMatched = StreamController<MatchmakerMatch>.broadcast();
    onError = StreamController<RealtimeError>.broadcast();

    when(() => mockClient.realtime).thenReturn(mockRealtime);
    when(() => mockRealtime.onConnected).thenReturn(onConnected);
    when(
      () => mockRealtime.onMatchmakerMatched,
    ).thenReturn(onMatchmakerMatched);
    when(() => mockRealtime.onError).thenReturn(onError);
    when(
      () => mockRealtime.connect(autoReconnect: any(named: 'autoReconnect')),
    ).thenAnswer((_) async {});
    when(
      () => mockRealtime.addToMatchmaker(mode: any(named: 'mode')),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    onConnected.close();
    onMatchmakerMatched.close();
    onError.close();
  });

  group('HasAsobiMatchmaker', () {
    gameTester.test('findMatch sets isSearching', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      expect(mm.isSearching, isFalse);

      mm.findMatch();

      expect(mm.isSearching, isTrue);
      verify(() => mockRealtime.addToMatchmaker(mode: 'default')).called(1);
    });

    gameTester.test('cancelSearch clears isSearching', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      mm.findMatch();
      expect(mm.isSearching, isTrue);

      mm.cancelSearch();
      expect(mm.isSearching, isFalse);
    });

    gameTester.test('update accumulates searchTime when searching', (
      game,
    ) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      mm.findMatch();

      game.update(0.5);
      expect(mm.searchTime, closeTo(0.5, 0.001));

      game.update(0.3);
      expect(mm.searchTime, closeTo(0.8, 0.001));
    });

    gameTester.test('update does not accumulate when not searching', (
      game,
    ) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      game.update(1.0);

      expect(mm.searchTime, 0);
    });

    gameTester.test('findMatch resets searchTime', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      mm.findMatch();
      game.update(1.0);
      expect(mm.searchTime, greaterThan(0));

      mm.cancelSearch();
      mm.findMatch();
      expect(mm.searchTime, 0);
    });

    gameTester.test('connectMatchmaker subscribes to events', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      await mm.connectMatchmaker();

      verify(() => mockRealtime.connect()).called(1);

      // Fire connected event
      onConnected.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(mm.connectedCalled, isTrue);
    });

    gameTester.test('onMatchmakerMatched clears searching', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      await mm.connectMatchmaker();
      mm.findMatch();
      expect(mm.isSearching, isTrue);

      final match = MatchmakerMatch(
        matchId: 'match-1',
        mode: 'default',
        playerIds: ['p1', 'p2'],
      );
      onMatchmakerMatched.add(match);
      await Future<void>.delayed(Duration.zero);

      expect(mm.isSearching, isFalse);
      expect(mm.lastMatch?.matchId, 'match-1');
    });

    gameTester.test('onError clears searching', (game) async {
      final mm = TestMatchmaker(mockClient);
      await game.add(mm);
      await game.ready();

      await mm.connectMatchmaker();
      mm.findMatch();

      onError.add(RealtimeError(message: 'timeout'));
      await Future<void>.delayed(Duration.zero);

      expect(mm.isSearching, isFalse);
      expect(mm.lastError?.message, 'timeout');
    });
  });
}
