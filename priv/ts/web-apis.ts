import { DOMException } from "./dom-exception";
import { Event, MessageEvent, CloseEvent, ErrorEvent } from "./event";
import { EventTarget } from "./event-target";
import { AbortSignal, AbortController } from "./abort";
import {
  ReadableStream,
  ReadableStreamDefaultReader,
  WritableStream,
  WritableStreamDefaultWriter,
  TransformStream,
  TextEncoderStream,
  TextDecoderStream,
} from "./streams";
import { Blob, File } from "./blob";
import { Headers } from "./headers";
import { Request, Response, fetch } from "./fetch";
import { BroadcastChannel } from "./broadcast-channel";
import { WebSocket } from "./websocket";
import { Worker } from "./worker";
import { EventSource } from "./event-source";

import "./console-ext";
import "./locks";
import "./storage";

Object.assign(globalThis, {
  DOMException,
  Event,
  MessageEvent,
  CloseEvent,
  ErrorEvent,
  EventTarget,
  AbortSignal,
  AbortController,
  ReadableStream,
  ReadableStreamDefaultReader,
  WritableStream,
  WritableStreamDefaultWriter,
  TransformStream,
  TextEncoderStream,
  TextDecoderStream,
  Blob,
  File,
  Headers,
  Request,
  Response,
  fetch,
  BroadcastChannel,
  WebSocket,
  Worker,
  EventSource,
});
