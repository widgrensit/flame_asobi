# flame_asobi

Flame bridge for the [Asobi](https://github.com/widgrensit/asobi) game backend. Adds Flame-native mixins for matchmaking, input capture, and server-state sync on top of the [asobi](https://pub.dev/packages/asobi) Dart SDK.

You write plain Flame components; `flame_asobi` mixes in the multiplayer wiring.

## Run a backend first

The current Flame mixins target the *arena* match shape (WASD + aim + shoot input, players + projectiles state). The fastest way to get a compatible backend is the reference arena Lua server:

```bash
git clone https://github.com/widgrensit/asobi_arena_lua
cd asobi_arena_lua && docker compose up -d
```

That serves at `http://localhost:8085`. For just the SDK plumbing (auth + matchmake + state — no combat) you can also point at [`sdk_demo_backend`](https://github.com/widgrensit/sdk_demo_backend) on `:8084`, but the arena-shaped `MatchInput` won't be meaningful there.

## Installation

```bash
flutter pub add flame_asobi
```

## Quick Start

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

class ArenaPlayer extends CircleComponent with AsobiPlayer {
  ArenaPlayer() : super(radius: 0.32, anchor: Anchor.center);
}

class ArenaBullet extends CircleComponent with AsobiProjectile {
  ArenaBullet() : super(radius: 0.15, anchor: Anchor.center);
}

class MyGame extends FlameGame
    with HasAsobi, HasAsobiMatchmaker, HasAsobiInput, KeyboardEvents, TapCallbacks {
  @override
  AsobiClient get inputClient => asobi;
  @override
  AsobiClient get matchmakerClient => asobi;
  @override
  String get matchmakerMode => 'arena';

  @override
  Future<void> onLoad() async {
    await asobiConnect('localhost', port: 8085);
    await asobi.auth.register('player_${DateTime.now().millisecond}', 'pass');
    await connectMatchmaker();
    findMatch();
  }

  @override
  void onMatchmakerMatched(MatchmakerMatch match) {
    world.add(AsobiNetworkSync(
      client: asobi,
      pixelsPerUnit: 50,
      playerBuilder: (id, {required isLocal}) => ArenaPlayer(),
      projectileBuilder: (id, owner, {required isLocal}) => ArenaBullet(),
    ));
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    handleKeyEvent(event, keysPressed);
    return KeyEventResult.handled;
  }
}
```

See [`example/lib/main.dart`](example/lib/main.dart) for the full version with mouse aim and a camera.

## Mixins

### `HasAsobi` — client lifecycle

Adds an `AsobiClient` to your `FlameGame`. Disposed automatically when the game is removed.

```dart
class MyGame extends FlameGame with HasAsobi {
  @override
  Future<void> onLoad() async {
    await asobiConnect('my-server.com', port: 8085, useSsl: true);
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
  String get matchmakerMode => 'arena';

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

Captures WASD + mouse and ticks `match.input` to the server at 10 Hz (override `inputSendInterval`).

```dart
class MyGame extends FlameGame
    with HasAsobi, HasAsobiInput, KeyboardEvents, MouseMovementDetector, TapCallbacks {
  @override
  AsobiClient get inputClient => asobi;
  @override
  double get inputPixelsPerUnit => 50;

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
}
```

Override `keyUp`/`keyDown`/`keyLeft`/`keyRight`/`keyShoot` to remap.

### `AsobiNetworkSync` — server state → entities

Listens to `match.state` and creates / updates / removes child components per the server's authoritative entity list. You provide builders for your component types.

```dart
world.add(AsobiNetworkSync(
  client: asobi,
  pixelsPerUnit: 50,
  playerBuilder: (playerId, {required isLocal}) => ArenaPlayer(),
  projectileBuilder: (id, owner, {required isLocal}) => ArenaBullet(),
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
class ArenaPlayer extends CircleComponent with AsobiPlayer {
  ArenaPlayer() : super(radius: 0.32, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    paint.color = isDead
        ? const Color(0xFF888888)
        : isLocal
            ? const Color(0xFF00FFFF)
            : const Color(0xFFFF4444);
  }
}
```

### `AsobiProjectile` mixin

Adds networked position (no interpolation — projectiles move fast) + `owner` and `isLocal` flags.

```dart
class ArenaBullet extends CircleComponent with AsobiProjectile {
  ArenaBullet() : super(radius: 0.15, anchor: Anchor.center);
}
```

## Architecture

```
FlameGame
├── HasAsobi              — owns AsobiClient
├── HasAsobiMatchmaker    — connect → match → callbacks
├── HasAsobiInput         — WASD + mouse → match.input @ 10 Hz
└── world
    └── AsobiNetworkSync  — match.state → AsobiPlayer / AsobiProjectile children
```

## Full example

See [`asobi-flame-demo`](https://github.com/widgrensit/asobi-flame-demo) for a complete arena shooter.

## License

Apache-2.0
