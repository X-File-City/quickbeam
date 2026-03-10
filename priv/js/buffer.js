(() => {
  // priv/ts/buffer.ts
  function normalizeEncoding(enc) {
    if (!enc)
      return "utf8";
    switch (enc.toLowerCase()) {
      case "utf8":
      case "utf-8":
        return "utf8";
      case "ascii":
        return "ascii";
      case "latin1":
      case "binary":
        return "latin1";
      case "base64":
        return "base64";
      case "base64url":
        return "base64url";
      case "hex":
        return "hex";
      case "ucs2":
      case "ucs-2":
      case "utf16le":
      case "utf-16le":
        return "utf16le";
      default:
        throw new TypeError(`Unknown encoding: ${enc}`);
    }
  }
  var BEAM_ENCODINGS = new Set(["base64", "base64url", "hex", "utf16le"]);
  function encodeString(str, encoding) {
    switch (encoding) {
      case "utf8":
        return new TextEncoder().encode(str);
      case "ascii": {
        const bytes = new Uint8Array(str.length);
        for (let i = 0;i < str.length; i++)
          bytes[i] = str.charCodeAt(i) & 127;
        return bytes;
      }
      case "latin1": {
        const bytes = new Uint8Array(str.length);
        for (let i = 0;i < str.length; i++)
          bytes[i] = str.charCodeAt(i) & 255;
        return bytes;
      }
      default:
        return beam.callSync("__buffer_decode", str, encoding);
    }
  }
  function decodeBytes(bytes, encoding) {
    switch (encoding) {
      case "utf8":
        return new TextDecoder().decode(bytes);
      case "ascii": {
        const chars = [];
        for (const b of bytes)
          chars.push(String.fromCharCode(b & 127));
        return chars.join("");
      }
      case "latin1": {
        const chars = [];
        for (const b of bytes)
          chars.push(String.fromCharCode(b));
        return chars.join("");
      }
      default:
        return beam.callSync("__buffer_encode", bytes, encoding);
    }
  }
  function wrapBuffer(arr) {
    return new QBBuffer(arr.buffer, arr.byteOffset, arr.byteLength);
  }

  class QBBuffer extends Uint8Array {
    static from(value, encodingOrOffset, length) {
      if (typeof value === "string") {
        const bytes = encodeString(value, normalizeEncoding(encodingOrOffset));
        const buf2 = new QBBuffer(bytes.length);
        buf2.set(bytes);
        return buf2;
      }
      if (value instanceof ArrayBuffer || value instanceof SharedArrayBuffer) {
        const offset = encodingOrOffset || 0;
        const len = length ?? value.byteLength - offset;
        return new QBBuffer(value, offset, len);
      }
      if (value instanceof Uint8Array) {
        const buf2 = new QBBuffer(value.length);
        buf2.set(value);
        return buf2;
      }
      if (typeof value === "object" && "type" in value && value.type === "Buffer") {
        const data = value.data;
        if (Array.isArray(data))
          return QBBuffer.from(data);
      }
      const buf = new QBBuffer(value.length);
      for (let i = 0;i < value.length; i++)
        buf[i] = value[i] & 255;
      return buf;
    }
    static alloc(size, fill, encoding) {
      const buf = new QBBuffer(size);
      if (fill !== undefined)
        buf.fill(fill, 0, size, encoding);
      return buf;
    }
    static allocUnsafe(size) {
      return new QBBuffer(size);
    }
    static isBuffer(obj) {
      return obj instanceof QBBuffer;
    }
    static isEncoding(encoding) {
      try {
        normalizeEncoding(encoding);
        return true;
      } catch {
        return false;
      }
    }
    static byteLength(string, encoding) {
      const enc = normalizeEncoding(encoding);
      if (BEAM_ENCODINGS.has(enc))
        return beam.callSync("__buffer_byte_length", string, enc);
      return encodeString(string, enc).length;
    }
    static concat(list, totalLength) {
      let total = totalLength;
      if (total === undefined) {
        total = 0;
        for (const item of list)
          total += item.length;
      }
      const buf = QBBuffer.alloc(total);
      let offset = 0;
      for (const item of list) {
        if (offset + item.length > total) {
          buf.set(item.subarray(0, total - offset), offset);
          break;
        }
        buf.set(item, offset);
        offset += item.length;
      }
      return buf;
    }
    static compare(buf1, buf2) {
      const len = Math.min(buf1.length, buf2.length);
      for (let i = 0;i < len; i++) {
        if (buf1[i] < buf2[i])
          return -1;
        if (buf1[i] > buf2[i])
          return 1;
      }
      if (buf1.length < buf2.length)
        return -1;
      if (buf1.length > buf2.length)
        return 1;
      return 0;
    }
    toString(encoding, start, end) {
      return decodeBytes(this.subarray(start ?? 0, end ?? this.length), normalizeEncoding(encoding));
    }
    toJSON() {
      return { type: "Buffer", data: Array.from(this) };
    }
    equals(other) {
      if (this.length !== other.length)
        return false;
      for (let i = 0;i < this.length; i++)
        if (this[i] !== other[i])
          return false;
      return true;
    }
    compare(target, targetStart, targetEnd, sourceStart, sourceEnd) {
      return QBBuffer.compare(this.subarray(sourceStart ?? 0, sourceEnd ?? this.length), target.subarray(targetStart ?? 0, targetEnd ?? target.length));
    }
    copy(target, targetStart, sourceStart, sourceEnd) {
      const tStart = targetStart ?? 0;
      const src = this.subarray(sourceStart ?? 0, sourceEnd ?? this.length);
      const toCopy = Math.min(src.length, target.length - tStart);
      target.set(src.subarray(0, toCopy), tStart);
      return toCopy;
    }
    write(string, offsetOrEncoding, lengthOrEncoding, encoding) {
      let off = 0;
      let enc = "utf8";
      let len;
      if (typeof offsetOrEncoding === "string") {
        enc = normalizeEncoding(offsetOrEncoding);
      } else if (typeof offsetOrEncoding === "number") {
        off = offsetOrEncoding;
        if (typeof lengthOrEncoding === "string")
          enc = normalizeEncoding(lengthOrEncoding);
        else if (typeof lengthOrEncoding === "number") {
          len = lengthOrEncoding;
          if (encoding)
            enc = normalizeEncoding(encoding);
        }
      }
      const bytes = encodeString(string, enc);
      const maxLen = this.length - off;
      const toCopy = Math.min(len !== undefined ? Math.min(len, bytes.length) : bytes.length, maxLen);
      this.set(bytes.subarray(0, toCopy), off);
      return toCopy;
    }
    slice(start, end) {
      return wrapBuffer(super.subarray(start, end));
    }
    subarray(start, end) {
      return wrapBuffer(super.subarray(start, end));
    }
    findNeedle(needle, from, to, step) {
      for (let i = step === 1 ? from : to;step === 1 ? i <= to : i >= from; i += step) {
        let found = true;
        for (let j = 0;j < needle.length; j++) {
          if (this[i + j] !== needle[j]) {
            found = false;
            break;
          }
        }
        if (found)
          return i;
      }
      return -1;
    }
    indexOf(value, byteOffset, encoding) {
      const offset = byteOffset ?? 0;
      if (typeof value === "number") {
        for (let i = offset;i < this.length; i++)
          if (this[i] === (value & 255))
            return i;
        return -1;
      }
      const needle = typeof value === "string" ? encodeString(value, normalizeEncoding(encoding)) : value;
      if (needle.length === 0)
        return offset;
      return this.findNeedle(needle, offset, this.length - needle.length, 1);
    }
    lastIndexOf(value, byteOffset, encoding) {
      const maxOffset = byteOffset ?? this.length - 1;
      if (typeof value === "number") {
        for (let i = Math.min(maxOffset, this.length - 1);i >= 0; i--)
          if (this[i] === (value & 255))
            return i;
        return -1;
      }
      const needle = typeof value === "string" ? encodeString(value, normalizeEncoding(encoding)) : value;
      if (needle.length === 0)
        return Math.min(maxOffset, this.length);
      return this.findNeedle(needle, 0, Math.min(maxOffset, this.length - needle.length), -1);
    }
    includes(value, byteOffset, encoding) {
      return this.indexOf(value, byteOffset, encoding) !== -1;
    }
    fill(value, offset, end, encoding) {
      const off = offset ?? 0;
      const e = end ?? this.length;
      if (typeof value === "number") {
        super.fill(value & 255, off, e);
        return this;
      }
      if (typeof value === "string") {
        if (value.length === 0) {
          super.fill(0, off, e);
          return this;
        }
        const bytes = encodeString(value, normalizeEncoding(encoding));
        if (bytes.length === 1) {
          super.fill(bytes[0], off, e);
          return this;
        }
        for (let i = off;i < e; i++)
          this[i] = bytes[(i - off) % bytes.length];
        return this;
      }
      for (let i = off;i < e; i++)
        this[i] = value[(i - off) % value.length];
      return this;
    }
    swap16() {
      if (this.length % 2 !== 0)
        throw new RangeError("Buffer size must be a multiple of 16-bits");
      for (let i = 0;i < this.length; i += 2) {
        const a = this[i];
        this[i] = this[i + 1];
        this[i + 1] = a;
      }
      return this;
    }
    swap32() {
      if (this.length % 4 !== 0)
        throw new RangeError("Buffer size must be a multiple of 32-bits");
      for (let i = 0;i < this.length; i += 4) {
        const a = this[i], b = this[i + 1];
        this[i] = this[i + 3];
        this[i + 1] = this[i + 2];
        this[i + 2] = b;
        this[i + 3] = a;
      }
      return this;
    }
    swap64() {
      if (this.length % 8 !== 0)
        throw new RangeError("Buffer size must be a multiple of 64-bits");
      for (let i = 0;i < this.length; i += 8) {
        const a = this[i], b = this[i + 1], c = this[i + 2], d = this[i + 3];
        this[i] = this[i + 7];
        this[i + 1] = this[i + 6];
        this[i + 2] = this[i + 5];
        this[i + 3] = this[i + 4];
        this[i + 4] = d;
        this[i + 5] = c;
        this[i + 6] = b;
        this[i + 7] = a;
      }
      return this;
    }
    dv() {
      return new DataView(this.buffer, this.byteOffset, this.byteLength);
    }
    readUInt8(offset = 0) {
      return this[offset];
    }
    readUInt16BE(offset = 0) {
      return this[offset] << 8 | this[offset + 1];
    }
    readUInt16LE(offset = 0) {
      return this[offset] | this[offset + 1] << 8;
    }
    readUInt32BE(offset = 0) {
      return this[offset] * 16777216 + (this[offset + 1] << 16 | this[offset + 2] << 8 | this[offset + 3]) >>> 0;
    }
    readUInt32LE(offset = 0) {
      return (this[offset] | this[offset + 1] << 8 | this[offset + 2] << 16 | this[offset + 3] * 16777216) >>> 0;
    }
    readInt8(offset = 0) {
      const v = this[offset];
      return v & 128 ? v - 256 : v;
    }
    readInt16BE(offset = 0) {
      const v = this[offset] << 8 | this[offset + 1];
      return v & 32768 ? v - 65536 : v;
    }
    readInt16LE(offset = 0) {
      const v = this[offset] | this[offset + 1] << 8;
      return v & 32768 ? v - 65536 : v;
    }
    readInt32BE(offset = 0) {
      return this[offset] << 24 | this[offset + 1] << 16 | this[offset + 2] << 8 | this[offset + 3];
    }
    readInt32LE(offset = 0) {
      return this[offset] | this[offset + 1] << 8 | this[offset + 2] << 16 | this[offset + 3] << 24;
    }
    readFloatBE(offset = 0) {
      return this.dv().getFloat32(offset, false);
    }
    readFloatLE(offset = 0) {
      return this.dv().getFloat32(offset, true);
    }
    readDoubleBE(offset = 0) {
      return this.dv().getFloat64(offset, false);
    }
    readDoubleLE(offset = 0) {
      return this.dv().getFloat64(offset, true);
    }
    readBigInt64BE(offset = 0) {
      return this.dv().getBigInt64(offset, false);
    }
    readBigInt64LE(offset = 0) {
      return this.dv().getBigInt64(offset, true);
    }
    readBigUInt64BE(offset = 0) {
      return this.dv().getBigUint64(offset, false);
    }
    readBigUInt64LE(offset = 0) {
      return this.dv().getBigUint64(offset, true);
    }
    writeUInt8(value, offset = 0) {
      this[offset] = value & 255;
      return offset + 1;
    }
    writeUInt16BE(value, offset = 0) {
      this[offset] = value >>> 8 & 255;
      this[offset + 1] = value & 255;
      return offset + 2;
    }
    writeUInt16LE(value, offset = 0) {
      this[offset] = value & 255;
      this[offset + 1] = value >>> 8 & 255;
      return offset + 2;
    }
    writeUInt32BE(value, offset = 0) {
      this[offset] = value >>> 24 & 255;
      this[offset + 1] = value >>> 16 & 255;
      this[offset + 2] = value >>> 8 & 255;
      this[offset + 3] = value & 255;
      return offset + 4;
    }
    writeUInt32LE(value, offset = 0) {
      this[offset] = value & 255;
      this[offset + 1] = value >>> 8 & 255;
      this[offset + 2] = value >>> 16 & 255;
      this[offset + 3] = value >>> 24 & 255;
      return offset + 4;
    }
    writeInt8(value, offset = 0) {
      this[offset] = value & 255;
      return offset + 1;
    }
    writeInt16BE(value, offset = 0) {
      this[offset] = value >>> 8 & 255;
      this[offset + 1] = value & 255;
      return offset + 2;
    }
    writeInt16LE(value, offset = 0) {
      this[offset] = value & 255;
      this[offset + 1] = value >>> 8 & 255;
      return offset + 2;
    }
    writeInt32BE(value, offset = 0) {
      this[offset] = value >>> 24 & 255;
      this[offset + 1] = value >>> 16 & 255;
      this[offset + 2] = value >>> 8 & 255;
      this[offset + 3] = value & 255;
      return offset + 4;
    }
    writeInt32LE(value, offset = 0) {
      this[offset] = value & 255;
      this[offset + 1] = value >>> 8 & 255;
      this[offset + 2] = value >>> 16 & 255;
      this[offset + 3] = value >>> 24 & 255;
      return offset + 4;
    }
    writeFloatBE(value, offset = 0) {
      this.dv().setFloat32(offset, value, false);
      return offset + 4;
    }
    writeFloatLE(value, offset = 0) {
      this.dv().setFloat32(offset, value, true);
      return offset + 4;
    }
    writeDoubleBE(value, offset = 0) {
      this.dv().setFloat64(offset, value, false);
      return offset + 8;
    }
    writeDoubleLE(value, offset = 0) {
      this.dv().setFloat64(offset, value, true);
      return offset + 8;
    }
    writeBigInt64BE(value, offset = 0) {
      this.dv().setBigInt64(offset, value, false);
      return offset + 8;
    }
    writeBigInt64LE(value, offset = 0) {
      this.dv().setBigInt64(offset, value, true);
      return offset + 8;
    }
    writeBigUInt64BE(value, offset = 0) {
      this.dv().setBigUint64(offset, value, false);
      return offset + 8;
    }
    writeBigUInt64LE(value, offset = 0) {
      this.dv().setBigUint64(offset, value, true);
      return offset + 8;
    }
  }
  globalThis.Buffer = QBBuffer;
})();
