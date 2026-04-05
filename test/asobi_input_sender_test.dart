import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAsobiClient extends Mock implements AsobiClient {}

class MockAsobiRealtime extends Mock implements AsobiRealtime {}

class TestInputComponent extends Component with HasAsobiInput {
  final AsobiClient _client;

  TestInputComponent(this._client);

  @override
  AsobiClient get inputClient => _client;

  @override
  double get inputSendInterval => 0.1;
}

final gameTester = FlameTester(FlameGame.new);

void main() {
  late MockAsobiClient mockClient;
  late MockAsobiRealtime mockRealtime;

  setUp(() {
    mockClient = MockAsobiClient();
    mockRealtime = MockAsobiRealtime();
    when(() => mockClient.realtime).thenReturn(mockRealtime);
    when(() => mockRealtime.sendMatchInput(any())).thenReturn(null);
  });

  setUpAll(() {
    registerFallbackValue(
      MatchInput(up: false, down: false, left: false, right: false),
    );
  });

  group('HasAsobiInput', () {
    gameTester.test('handleKeyEvent tracks pressed keys', (game) async {
      final input = TestInputComponent(mockClient);
      await game.add(input);
      await game.ready();

      input.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyW},
      );

      // Trigger update past the interval so it actually sends
      game.update(0.2);

      verify(() => mockRealtime.sendMatchInput(any())).called(1);
    });

    gameTester.test('update respects inputSendInterval', (game) async {
      final input = TestInputComponent(mockClient);
      await game.add(input);
      await game.ready();

      input.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
        {LogicalKeyboardKey.keyW},
      );

      // Update with dt smaller than interval — should NOT send
      game.update(0.05);
      verifyNever(() => mockRealtime.sendMatchInput(any()));

      // Update past interval threshold — should send
      game.update(0.06);
      verify(() => mockRealtime.sendMatchInput(any())).called(1);
    });

    gameTester.test('update does not send when no keys pressed', (game) async {
      final input = TestInputComponent(mockClient);
      await game.add(input);
      await game.ready();

      game.update(0.2);

      verifyNever(() => mockRealtime.sendMatchInput(any()));
    });

    gameTester.test('updateMousePosition and setMouseDown work', (game) async {
      final input = TestInputComponent(mockClient);
      await game.add(input);
      await game.ready();

      input.updateMousePosition(Vector2(5, 10));
      input.setMouseDown(true);

      game.update(0.2);

      final captured =
          verify(() => mockRealtime.sendMatchInput(captureAny())).captured.first
              as MatchInput;

      expect(captured.shoot, isTrue);
      expect(captured.aimX, closeTo(250, 0.001)); // 5 * 50
      expect(captured.aimY, closeTo(500, 0.001)); // 10 * 50
    });

    gameTester.test('setMouseDown false stops shooting', (game) async {
      final input = TestInputComponent(mockClient);
      await game.add(input);
      await game.ready();

      input.setMouseDown(true);
      game.update(0.2);
      verify(() => mockRealtime.sendMatchInput(any())).called(1);

      input.setMouseDown(false);
      game.update(0.2);
      // No keys and no mouse — should not send
      verifyNever(() => mockRealtime.sendMatchInput(any()));
    });
  });
}
