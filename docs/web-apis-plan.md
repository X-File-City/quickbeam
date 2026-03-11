# Web APIs Implementation Plan

## Current State

### Already implemented (prior)
- console.log/warn/error → Logger
- setTimeout/setInterval/clearTimeout (Zig timers)
- TextEncoder/TextDecoder (Zig native)
- URL/URLSearchParams (`:uri_string`)
- fetch/Request/Response/Headers (`:httpc`)
- SubtleCrypto: digest, sign, verify, encrypt, decrypt, generateKey, deriveBits (`:crypto`)
- crypto.getRandomValues/randomUUID (Zig `std.crypto.random`)
- CompressionStream/DecompressionStream (`:zlib`)
- Buffer encode/decode/byteLength (`Base`)
- EventTarget/Event/CustomEvent/ErrorEvent (pure TS)
- AbortController/AbortSignal (pure TS)
- ReadableStream (pure TS)
- Blob/File (pure TS)
- BroadcastChannel (`:pg`, distributed)
- WebSocket (`:gun`)
- DOMException (pure TS)
- document/DOM (lexbor)
- beam.call/callSync/send/self (NIF ↔ GenServer)
- Process.onMessage/monitor/demonitor (BEAM primitives)
- CPU timeout (JS_SetInterruptHandler)
- Runtime pools (NimblePool)
- atob/btoa (Zig base64)
- structuredClone (JS_WriteObject/JS_ReadObject)
- queueMicrotask (JS_EnqueueJob)
- performance.now (WorkerState.start_time)

### Implemented in this branch (ideas-impl)
- ✅ WritableStream / WritableStreamDefaultWriter
- ✅ TransformStream / TransformStreamDefaultController
- ✅ TextEncoderStream / TextDecoderStream
- ✅ ReadableStream.pipeThrough / pipeTo
- ✅ console.debug/trace/assert/time/timeLog/timeEnd/count/countReset/dir/group/groupEnd
- ✅ Worker (BEAM process-backed, fault-tolerant JS workers)
- ✅ navigator.locks (Web Locks API — exclusive/shared, ifAvailable, query)
- ✅ localStorage (ETS-backed, shared across runtimes)
- ✅ EventSource (SSE client via :httpc streaming)

## Remaining Tier 2

| API | Backend | Effort | Notes |
|---|---|---|---|
| `MessageChannel/MessagePort` | Linked process pairs | medium | Transfer ports between runtimes |
| `Cache` API | `:ets` | medium | Request→Response cache |
| `URLPattern` | pure TS/Zig | medium | URL pattern matching for routing |

## Tier 3 — Larger builds

| API | Backend | Effort | Why |
|---|---|---|---|
| `IndexedDB` | `:mnesia` | large | Distributed transactional DB |
| File System API | `:file` + `:filelib` | medium-large | Sandboxed per-runtime |
| `Atomics/SharedArrayBuffer` | `:atomics` / `:counters` | medium | Lock-free shared state |

## Tier 4 — QuickBEAM-only

| Concept | Backend | Why |
|---|---|---|
| `beam.spawn()` | `QuickBEAM.start/1` | JS spawning supervised JS runtimes |
| `beam.cluster` | `:pg` + `:erpc` | JS calling runtimes across the cluster |
| `beam.ets()` | `:ets` | Direct concurrent-read ETS from JS |
| `beam.telemetry` | `:telemetry` | JS emitting telemetry visible in LiveDashboard |
