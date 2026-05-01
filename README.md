# flame_asobi

Flame bridge for the [Asobi](https://github.com/widgrensit/asobi) game backend. Adds Flame-native mixins for matchmaking, input capture, and server-state sync on top of the [asobi](https://pub.dev/packages/asobi) Dart SDK.

You write plain Flame components; `flame_asobi` mixes in the multiplayer wiring.

## Run a backend first

The fastest way to try the SDK is the canonical SDK demo backend:

```bash
git clone https://github.com/widgrensit/sdk_demo_backend
cd sdk_demo_backend && docker compose up -d
```

That serves at `http://localhost:8084` with a 2-player `demo` mode. For the full reference game (arena shooter — boons, modifiers, voting, bots) see [`asobi_arena_lua`](https://github.com/widgrensit/asobi_arena_lua) on `:8085`.

## Installation

```bash
flutter pub add flame_asobi
```

## Quick Start

Connect, matchmake, and tick `move_x` / `move_y` at 10 Hz against the demo backend:

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

class DemoPlayer extends CircleComponent with AsobiPlayer {
  DemoPlayer() : super(radius: 0.32, anchor: Anchor.center);
}

class MyGame extends FlameGame
    with HasAsobi, HasAsobiMatchmaker, HasAsobiInput, KeyboardEvents {
  @override
  AsobiClient get inputClient => asobi;
  @override
  AsobiClient get matchmakerClient => asobi;
  @override
  String get matchmakerMode => 'demo';

  @override
  Future<void> onLoad() async {
    await asobiConnect('localhost', port: 8084);
    await asobi.auth.register('player_${DateTime.now().millisecond}', 'pass');
    await connectMatchmaker();
    findMatch();
  }

  @override
  void onMatchmakerMatched(MatchmakerMatch match) {
    world.add(AsobiNetworkSync(
      client: asobi,
      pixelsPerUnit: 50,
      playerBuilder: (id, {required isLocal}) => DemoPlayer(),
      projectileBuilder: (id, owner, {required isLocal}) =>
          CircleComponent(radius: 0.15),
    ));
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    handleKeyEvent(event, keysPressed);
    return KeyEventResult.handled;
  }
}
```

See [`example/lib/main.dart`](example/lib/main.dart) for the runnable version with mouse aim + camera.

## Mixins

### `HasAsobi` — client lifecycle

Adds an `AsobiClient` to your `FlameGame`. Disposed automatically when the game is removed.

```dart
class MyGame extends FlameGame with HasAsobi {
  @override
  Future<void> onLoad() async {
    await asobiConnect('my-server.com', port: 8084, useSsl: true);
    // asobi.auth, asobi.realtime, asobi.leaderboards, asobi.matchmaker, ...
  }
}
```

### `HasAsobiMatchmaker` — matchmaking lifecycle

Mix into a `Component` (typically your `FlameGame`) for matchmaking with callbacks.

```dart
class MyGame extends FlameGame with HasAsobi, HasAsobiMatchmaker {
  @override
  AsobiClient get matchmakerClient => asobi;
  @override
  String get matchmakerMode => 'demo';

  @override
  void onMatchmakerConnected() => findMatch();

  @override
  void onMatchmakerMatched(MatchmakerMatch match) {
    // start the round
  }
}
```

`isConnected`, `isSearching`, `searchTime` are available as state, plus `cancelSearch()`.

### `HasAsobiInput` — keyboard + mouse capture

Captures WASD + mouse and ticks `match.input` at 10 Hz (override `inputSendInterval`).

**Default payload** matches `sdk_demo_backend`:
`{move_x: -1|0|1, move_y: -1|0|1, shoot: bool, aim_x, aim_y}`.

Override `buildMatchInput` for your game's shape. Example for `asobi_arena` (boolean WASD flags):

```dart
class ArenaGame extends FlameGame with HasAsobi, HasAsobiInput {
  @override
  Map<String, dynamic>? buildMatchInput({
    required Set<LogicalKeyboardKey> keysPressed,
    required Vector2 mouseWorld,
    required bool mouseDown,
  }) {
    final up = keysPressed.contains(keyUp);
    final down = keysPressed.contains(keyDown);
    final left = keysPressed.contains(keyLeft);
    final right = keysPressed.contains(keyRight);
    final shoot = mouseDown || keysPressed.contains(keyShoot);
    if (!(up || down || left || right || shoot)) return null;
    return {
      'up': up, 'down': down, 'left': left, 'right': right, 'shoot': shoot,
      'aim_x': mouseWorld.x * inputPixelsPerUnit,
      'aim_y': mouseWorld.y * inputPixelsPerUnit,
    };
  }
}
```

Forward Flame events to the mixin:

```dart
@override
KeyEventResult onKeyEvent(KeyEvent e, Set<LogicalKeyboardKey> keys) {
  handleKeyEvent(e, keys);
  return KeyEventResult.handled;
}

@override
void onMouseMove(PointerHoverInfo info) =>
    updateMousePosition(camera.viewfinder.globalToLocal(info.eventPosition.global));

@override
void onTapDown(TapDownEvent e) => setMouseDown(down: true);
@override
void onTapUp(TapUpEvent e) => setMouseDown(down: false);
```

### `AsobiNetworkSync` — server state → entities

Listens to `match.state` and creates / updates / removes child components per the server's authoritative entity list. You provide builders for your component types.

```dart
world.add(AsobiNetworkSync(
  client: asobi,
  pixelsPerUnit: 50,
  playerBuilder: (id, {required isLocal}) => DemoPlayer(),
  projectileBuilder: (id, owner, {required isLocal}) => DemoBullet(),
  onStateUpdate: (state) {
    // update HUD
  },
  onMatchFinished: (result) {
    // navigate to results
  },
));
```

### `AsobiPlayer` mixin

Adds networked position interpolation + match-state fields (`hp`, `kills`, `deaths`, `isLocal`, `isDead`) to any `PositionComponent`.

```dart
class DemoPlayer extends CircleComponent with AsobiPlayer {
  DemoPlayer() : super(radius: 0.32, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    paint.color = isLocal ? const Color(0xFF00FFFF) : const Color(0xFFFF4444);
  }
}
```

### `AsobiProjectile` mixin

Adds networked position (no interpolation — projectiles move fast) + `owner` and `isLocal` flags.

## Architecture

```
FlameGame
├── HasAsobi              — owns AsobiClient
├── HasAsobiMatchmaker    — connect → match → callbacks
├── HasAsobiInput         — WASD + mouse → match.input @ 10 Hz (override buildMatchInput for shape)
└── world
    └── AsobiNetworkSync  — match.state → AsobiPlayer / AsobiProjectile children
```

## Full example

See [`asobi-flame-demo`](https://github.com/widgrensit/asobi-flame-demo) for a complete arena shooter (boons, modifiers, voting) — uses `buildMatchInput` to emit the arena-shaped input.

## Dispatch testing

flame_asobi delegates all WebSocket dispatch to `package:asobi`. Protocol dispatch coverage lives there (see asobi-dart's `test/dispatch_test.dart`). flame_asobi's tests focus on the Flame component integration (`AsobiNetworkSync`, `AsobiPlayer`, `AsobiProjectile`, mixins) on top of those already-dispatched typed event streams.

## License

Apache-2.0
