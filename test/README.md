# Testing strategy

`flame_asobi` is currently exercised by the end-to-end smoke test in
`smoke_tests/smoke.dart`, which runs against `widgrensit/sdk_demo_backend` in
CI. That test covers the SDK contract surface (`AsobiClient`, realtime
matchmaking, `match.input` -> `match.state` round-trip).

The Flame-side mixins (`AsobiPlayer`, `AsobiProjectile`, `AsobiNetworkSync`,
`HasAsobiInput`, `HasAsobiMatchmaker`) currently have no automated tests. The
previous unit tests under `test/` were removed in #11 because they targeted a
deleted class-based API and a `flame_test` version that has since changed
shape.

Proper widget tests for the mixin-based components are a future task.
