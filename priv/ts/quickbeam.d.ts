interface Beam {
  callSync(handler: string, ...args: unknown[]): unknown;
  call(handler: string, ...args: unknown[]): Promise<unknown>;
}

declare const beam: Beam;

type CompressionFormat = "gzip" | "deflate" | "deflate-raw";

interface CompressionAPI {
  compress(format: CompressionFormat, data: Uint8Array): Uint8Array;
  decompress(format: CompressionFormat, data: Uint8Array): Uint8Array;
}

declare const compression: CompressionAPI;

type BufferSource = ArrayBufferView | ArrayBuffer;

interface Algorithm {
  name: string;
}

type AlgorithmIdentifier = Algorithm | string;
type KeyFormat = "raw" | "pkcs8" | "spki" | "jwk";
type KeyUsage =
  | "encrypt"
  | "decrypt"
  | "sign"
  | "verify"
  | "deriveKey"
  | "deriveBits"
  | "wrapKey"
  | "unwrapKey";

interface JsonWebKey {
  alg?: string;
  crv?: string;
  d?: string;
  dp?: string;
  dq?: string;
  e?: string;
  ext?: boolean;
  k?: string;
  key_ops?: string[];
  kty?: string;
  n?: string;
  oth?: { d?: string; r?: string; t?: string }[];
  p?: string;
  q?: string;
  qi?: string;
  use?: string;
  x?: string;
  y?: string;
}

type BinaryType = "blob" | "arraybuffer";
type ResponseType = "basic" | "cors" | "default" | "error" | "opaque" | "opaqueredirect";
type QBRequestRedirect = "follow" | "error" | "manual";
