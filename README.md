# QuickBEAM

QuickJS-NG JavaScript engine embedded in the BEAM via Zig NIFs.

JS runtimes are GenServers. They live in supervision trees, send and
receive messages, and call into Erlang/OTP libraries — all without
leaving the BEAM.

## Quick start

```elixir
{:ok, rt} = QuickBEAM.start()
{:ok, 3} = QuickBEAM.eval(rt, "1 + 2")
{:ok, "HELLO"} = QuickBEAM.eval(rt, "'hello'.toUpperCase()")

# State persists across calls
QuickBEAM.eval(rt, "function greet(name) { return 'hi ' + name }")
{:ok, "hi world"} = QuickBEAM.call(rt, "greet", ["world"])

QuickBEAM.stop(rt)
```

## BEAM integration

JS can call Elixir functions and access OTP libraries:

```elixir
{:ok, rt} = QuickBEAM.start(handlers: %{
  "db.query" => fn [sql] -> MyRepo.query!(sql).rows end,
  "cache.get" => fn [key] -> Cachex.get!(:app, key) end,
})

{:ok, rows} = QuickBEAM.eval(rt, """
  const rows = await beam.call("db.query", "SELECT * FROM users LIMIT 5");
  rows.map(r => r.name);
""")
```

JS can also send messages to any BEAM process:

```javascript
// Get the runtime's own PID
const self = beam.self();

// Send to any PID
beam.send(somePid, {type: "update", data: result});

// Receive BEAM messages
Process.onMessage((msg) => {
  console.log("got:", msg);
});
```

## Supervision

Runtimes are OTP children with crash recovery:

```elixir
children = [
  {QuickBEAM,
   name: :renderer,
   id: :renderer,
   script: "priv/js/app.js",
   handlers: %{
     "db.query" => fn [sql, params] -> Repo.query!(sql, params).rows end,
   }},
  {QuickBEAM, name: :worker, id: :worker},
]

Supervisor.start_link(children, strategy: :one_for_one)

{:ok, html} = QuickBEAM.call(:renderer, "render", [%{page: "home"}])
```

The `:script` option loads a JS file at startup. If the runtime crashes,
the supervisor restarts it with a fresh context and re-evaluates the script.

## Web APIs

Standard browser APIs backed by BEAM primitives, not JS polyfills:

| JS API | BEAM backend |
|---|---|
| `URL`, `URLSearchParams` | `:uri_string` |
| `crypto.subtle` | `:crypto` |
| `compression.compress/decompress` | `:zlib` |
| `TextEncoder`, `TextDecoder` | Native Zig (UTF-8) |
| `crypto.getRandomValues` | `std.crypto.random` |
| `atob`, `btoa` | Native Zig |
| `setTimeout`, `setInterval` | Timer heap in worker thread |
| `console.log/warn/error` | Erlang logger |
| `performance.now` | `std.time.nanoTimestamp` |
| `structuredClone` | QuickJS serialization |
| `queueMicrotask` | `JS_EnqueueJob` |

## Data conversion

No JSON in the data path. JS values map directly to BEAM terms:

| JS | Elixir |
|---|---|
| `number` (integer) | `integer` |
| `number` (float) | `float` |
| `string` | `String.t()` |
| `boolean` | `boolean` |
| `null` | `nil` |
| `undefined` | `nil` |
| `Array` | `list` |
| `Object` | `map` (string keys) |
| `Uint8Array` | `binary` |
| `Symbol("name")` | `:name` (atom) |
| `Infinity` / `NaN` | `:Infinity` / `:NaN` |
| PID / Ref / Port | Opaque JS object (round-trips) |

## TypeScript

Type definitions for the BEAM-specific JS API:

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "types": ["./path/to/quickbeam.d.ts"]
  }
}
```

The `.d.ts` file covers `beam`, `Process`, `BeamPid`, and `compression`.
Standard Web APIs are typed by TypeScript's `lib.dom.d.ts`.

## Performance

vs QuickJSEx 0.3.1 (Rust/Rustler, JSON serialization):

| Benchmark | Speedup |
|---|---|
| Function call — small map | **2.5x faster** |
| Function call — large data | **4.1x faster** |
| Concurrent JS execution | **1.35x faster** |
| `beam.callSync` (JS→BEAM) | 5 μs overhead (unique to QuickBEAM) |
| Startup | ~600 μs (parity) |

See [`bench/`](bench/README.md) for details.

## Installation

```elixir
def deps do
  [{:quickbeam, "~> 0.1.0"}]
end
```

Requires Zig 0.15+ (installed automatically by Zigler, or use system Zig).

## Examples

- [`examples/content_pipeline/`](examples/content_pipeline/) — three
  supervised JS runtimes forming a content moderation pipeline, with tests.

## License

MIT
