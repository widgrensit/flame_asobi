import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

class TestProjectile extends PositionComponent with AsobiProjectile {}

final gameTester = FlameTester(FlameGame.new);

void main() {
  group('AsobiProjectile', () {
    gameTester.test('initProjectile sets fields correctly', (game) async {
      final proj = TestProjectile();
      await game.add(proj);
      await game.ready();

      proj.initProjectile(id: 42, ownerId: 'player-1', local: true);

      expect(proj.projectileId, 42);
      expect(proj.owner, 'player-1');
      expect(proj.isLocal, isTrue);
    });

    gameTester.test('initProjectile defaults local to false', (game) async {
      final proj = TestProjectile();
      await game.add(proj);
      await game.ready();

      proj.initProjectile(id: 1, ownerId: 'enemy');

      expect(proj.isLocal, isFalse);
    });

    gameTester.test('applyServerState sets position directly', (game) async {
      final proj = TestProjectile()..position = Vector2.zero();
      await game.add(proj);
      await game.ready();

      proj.initProjectile(id: 1, ownerId: 'p1');

      final state = ProjectileState(id: 1, owner: 'p1', x: 250, y: 150);
      proj.applyServerState(state, 50);

      expect(proj.position.x, closeTo(5, 0.001));
      expect(proj.position.y, closeTo(3, 0.001));
    });

    gameTester.test('applyServerState respects pixelsPerUnit', (game) async {
      final proj = TestProjectile()..position = Vector2.zero();
      await game.add(proj);
      await game.ready();

      proj.initProjectile(id: 1, ownerId: 'p1');

      final state = ProjectileState(id: 1, owner: 'p1', x: 100, y: 200);
      proj.applyServerState(state, 100);

      expect(proj.position.x, closeTo(1, 0.001));
      expect(proj.position.y, closeTo(2, 0.001));
    });
  });
}
