# Web APIs Implementation Plan

## Current State

Already implemented:
- console.log/warn/error → Logger
- setTimeout/setInterval/clearTimeout (Zig timers)
- TextEncoder/TextDecoder (Zig native)
- URL/URLSearchParams (`:uri_string`)
- fetch/Request/Response/Headers (`:httpc`)
- SubtleCrypto: digest, sign, verify, encrypt, decrypt, generateKey, deriveBits (`:crypto`)
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

## Tier 1 — Quick wins

| API | Backend | Effort |
|---|---|---|
| `crypto.getRandomValues()` | `:crypto.strong_rand_bytes/1` | tiny |
| `crypto.randomUUID()` | `:crypto.strong_rand_bytes/1` | tiny |
| `atob()/btoa()` | `:base64` | tiny |
| `structuredClone()` | `JS_WriteObject` + `JS_ReadObject` in Zig | small |
| `queueMicrotask()` | `JS_EnqueueJob` in Zig | tiny |
| `performance.now()` | WorkerState.start_time already exists | tiny |
| `WritableStream/TransformStream` | pure TS | small-medium |
| `TextEncoderStream/TextDecoderStream` | pure TS over existing | small |
| `console.time/timeEnd/count/assert/table` | Logger + JS-side state | small |

## Tier 2 — BEAM superpowers

| API | Backend | Effort | Why |
|---|---|---|---|
| `Worker` | BEAM processes | medium | Fault-tolerant supervised JS workers. Crash → restart. No other runtime has this. |
| `MessageChannel/MessagePort` | Linked process pairs | medium | Transfer ports between runtimes. |
| `navigator.locks` | `:global.set_lock/1` | small-medium | Advisory locks across the BEAM cluster. |
| `EventSource` (SSE) | `:httpc` streaming | small-medium | Server-Sent Events client. |
| `Cache` API | `:ets` | medium | Request→Response cache shared across runtimes. |
| `localStorage` | `:dets` or `:persistent_term` | small | Disk-persisted KV. Survives runtime restarts. |
| `URLPattern` | pure TS/Zig | medium | URL pattern matching for routing. |

## Tier 3 — Larger builds

| API | Backend | Effort | Why |
|---|---|---|---|
| `IndexedDB` | `:mnesia` | large | Distributed transactional DB with replication. Maps well to IndexedDB's object stores + transactions + cursors. |
| File System API | `:file` + `:filelib` | medium-large | FileSystemFileHandle, sandboxed per-runtime. |
| `Atomics/SharedArrayBuffer` | `:atomics` / `:counters` | medium | Lock-free shared state across runtimes. |

## Tier 4 — QuickBEAM-only (no Web API equivalent)

| Concept | Backend | Why |
|---|---|---|
| `beam.spawn()` | `QuickBEAM.start/1` | JS spawning supervised JS runtimes. |
| `beam.cluster` | `:pg` + `:erpc` | JS calling runtimes across the cluster. |
| `beam.ets()` | `:ets` | Direct concurrent-read ETS from JS. |
| `beam.telemetry` | `:telemetry` | JS emitting telemetry visible in LiveDashboard. |

## Implementation Order

1. Tier 1 quick wins (all at once — round out the standard surface)
2. `Worker` (the killer feature)
3. `navigator.locks` (unique distributed primitive)
4. Remaining Tier 2
5. Tier 3 as demand appears
