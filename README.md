# flame_asobi

Flame bridge package for the [Asobi](https://pub.dev/packages/asobi) multiplayer game backend. Provides Flame-native components and mixins for real-time multiplayer, matchmaking, and leaderboards.

Instead of manually managing WebSocket state, entity tracking, and input serialization, `flame_asobi` gives you drop-in components that handle it all.

## Installation

```bash
flutter pub add flame_asobi
```

## Quick Start

```dart
import 'package:flame/game.dart';
import 'package:flame_asobi/flame_asobi.dart';

class MyGame extends FlameGame with HasAsobi, KeyboardEvents {
  @override
  Future<void> onLoad() async {
    await asobiConnect('localhost', port: 8080);
    await asobi.auth.login('player1', 'secret');
    await asobi.realtime.connect();

    // Automatically syncs server state → Flame components
    world.add(AsobiNetworkSync(
      client: asobi,
      pixelsPerUnit: 50,
      onMatchFinished: (result) => print('Game over!'),
    ));

    // Captures WASD + mouse and sends to server
    world.add(AsobiInputSender(client: asobi, pixelsPerUnit: 50));
  }
}
```

## Components

### `HasAsobi` mixin

Adds an `AsobiClient` to your `FlameGame` with lifecycle management.

```dart
class MyGame extends FlameGame with HasAsobi {
  @override
  Future<void> onLoad() async {
    await asobiConnect('my-server.com', port: 8080, useSsl: true);
    // asobi.auth, asobi.realtime, asobi.leaderboards, etc.
  }
}
```

The client is automatically disposed when the game is removed.

### `AsobiNetworkSync`

The core component. Listens to `match.state` events from the server and automatically creates, updates, and removes `AsobiPlayer` and `AsobiProjectile` children.

```dart
world.add(AsobiNetworkSync(
  client: asobi,
  pixelsPerUnit: 50,
  onStateUpdate: (state) {
    // Update HUD with timer, kills, HP
    final player = sync.localPlayer;
    timerText.text = formatTime(sync.timeRemainingMs);
    killsText.text = 'Kills: ${player?.kills ?? 0}';
  },
  onMatchFinished: (result) {
    // Navigate to results screen
  },
));
```

**Custom entity rendering:**

```dart
world.add(AsobiNetworkSync(
  client: asobi,
  pixelsPerUnit: 50,
  playerBuilder: (playerId, isLocal) => MyCustomPlayer(
    playerId: playerId,
    isLocal: isLocal,
    sprite: myPlayerSprite,
  ),
  projectileBuilder: (id, owner, isLocal) => MyCustomBullet(
    projectileId: id,
    owner: owner,
    isLocal: isLocal,
  ),
));
```

### `AsobiPlayer`

A networked player component with automatic position interpolation and built-in rendering (circle body, HP bar, name label).

```dart
final player = AsobiPlayer(
  playerId: 'abc123',
  isLocal: true,
  size: Vector2.all(0.64),
  lerpSpeed: 0.3,  // interpolation smoothing
);
```

Properties updated from server state:
- `position` — interpolated toward server position
- `hp`, `kills`, `deaths` — from match state
- `color` — cyan (local), red (enemy), grey (dead)
- `isDead` — true when hp <= 0

### `AsobiProjectile`

A networked projectile component. Position is set directly from server state (no interpolation — projectiles move fast enough).

```dart
final bullet = AsobiProjectile(
  projectileId: 1,
  owner: 'player-uuid',
  isLocal: true,  // yellow for local, white for enemy
  radius: 0.15,
);
```

### `AsobiInputSender`

Captures keyboard and mouse input and sends it to the server as match input every frame.

```dart
world.add(AsobiInputSender(
  client: asobi,
  pixelsPerUnit: 50,
  // Default keys (override to customize):
  // keyUp: LogicalKeyboardKey.keyW,
  // keyDown: LogicalKeyboardKey.keyS,
  // keyLeft: LogicalKeyboardKey.keyA,
  // keyRight: LogicalKeyboardKey.keyD,
  // keyShoot: LogicalKeyboardKey.space,
));
```

For mouse aiming and click-to-shoot, forward events from your game:

```dart
@override
void onMouseMove(PointerHoverInfo info) {
  inputSender.updateMousePosition(
    camera.viewfinder.globalToLocal(info.eventPosition.global),
  );
}

@override
void onTapDown(TapDownEvent event) {
  inputSender.setMouseDown(true);
}

@override
void onTapUp(TapUpEvent event) {
  inputSender.setMouseDown(false);
}
```

### `AsobiMatchmaker`

Manages the matchmaking lifecycle with callbacks.

```dart
final matchmaker = AsobiMatchmaker(
  client: asobi,
  mode: 'arena',
  onConnected: () => print('Ready to play'),
  onMatched: (payload) => startGame(),
  onError: (err) => showError(err),
);

world.add(matchmaker);
await matchmaker.connect();
matchmaker.findMatch();

// Check status:
print(matchmaker.isSearching);  // true
print(matchmaker.searchTime);   // seconds elapsed
```

## Architecture

```
┌─────────────────────────────────────────┐
│              FlameGame                  │
│                                         │
│  AsobiNetworkSync                       │
│  ├── Listens to match.state (10Hz)      │
│  ├── Creates/updates AsobiPlayer        │
│  ├── Creates/updates AsobiProjectile    │
│  └── Fires onStateUpdate / onFinished   │
│                                         │
│  AsobiInputSender                       │
│  ├── Captures WASD + mouse each frame   │
│  └── Sends match.input to server        │
│                                         │
│  AsobiMatchmaker                        │
│  ├── Connects WebSocket                 │
│  ├── Queues for matchmaking             │
│  └── Fires onMatched callback           │
│                                         │
│  AsobiClient (from asobi package)       │
│  ├── HTTP: auth, leaderboards, etc.     │
│  └── WebSocket: realtime events         │
└─────────────────────────────────────────┘
```

## Full Example

See the [asobi-flame-demo](https://github.com/widgrensit/asobi-flame-demo) for a complete arena shooter using this package.

## License

Apache-2.0
