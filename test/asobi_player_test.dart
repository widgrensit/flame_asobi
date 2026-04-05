import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

class TestPlayer extends PositionComponent with AsobiPlayer {}

final gameTester = FlameTester(FlameGame.new);

void main() {
  group('AsobiPlayer', () {
    gameTester.test('initPlayer sets fields correctly', (game) async {
      final player = TestPlayer()..position = Vector2(10, 20);
      await game.add(player);
      await game.ready();

      player.initPlayer(
        id: 'player-abc-12345678',
        local: true,
        lerp: 0.5,
        playerLabel: 'Hero',
      );

      expect(player.playerId, 'player-abc-12345678');
      expect(player.isLocal, isTrue);
      expect(player.lerpSpeed, 0.5);
      expect(player.label, 'Hero');
    });

    gameTester.test('initPlayer defaults label to YOU for local', (game) async {
      final player = TestPlayer();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'some-id', local: true);

      expect(player.label, 'YOU');
    });

    gameTester.test('initPlayer defaults label to truncated id for remote', (
      game,
    ) async {
      final player = TestPlayer();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'abcdefghij', local: false);

      expect(player.label, 'abcdefgh');
    });

    gameTester.test('initPlayer handles short id for label', (game) async {
      final player = TestPlayer();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'abc', local: false);

      expect(player.label, 'abc');
    });

    gameTester.test('applyServerState updates target position and stats', (
      game,
    ) async {
      final player = TestPlayer()..position = Vector2.zero();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'p1');

      final state = PlayerState(x: 500, y: 300, hp: 80, kills: 3, deaths: 1);
      player.applyServerState(state, 50);

      expect(player.hp, 80);
      expect(player.kills, 3);
      expect(player.deaths, 1);
    });

    gameTester.test('isDead returns true when hp <= 0', (game) async {
      final player = TestPlayer();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'p1');
      player.hp = 0;
      expect(player.isDead, isTrue);

      player.hp = -5;
      expect(player.isDead, isTrue);

      player.hp = 1;
      expect(player.isDead, isFalse);
    });

    gameTester.test('update lerps position toward target', (game) async {
      final player = TestPlayer()..position = Vector2.zero();
      await game.add(player);
      await game.ready();

      player.initPlayer(id: 'p1', lerp: 0.5);

      final state = PlayerState(x: 500, y: 500, hp: 100, kills: 0, deaths: 0);
      player.applyServerState(state, 50); // target = (10, 10)

      game.update(0.016);

      // After one lerp step at 0.5, position should move toward (10, 10)
      expect(player.position.x, greaterThan(0));
      expect(player.position.y, greaterThan(0));
      expect(player.position.x, lessThan(10));
      expect(player.position.y, lessThan(10));
    });
  });
}
