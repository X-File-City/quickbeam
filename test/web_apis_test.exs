defmodule QuickBEAM.WebAPIsTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, rt} = QuickBEAM.start()
    {:ok, rt: rt}
  end

  describe "TextEncoder" do
    test "encoding property is utf-8", %{rt: rt} do
      assert {:ok, "utf-8"} = QuickBEAM.eval(rt, "new TextEncoder().encoding")
    end

    test "encode ASCII", %{rt: rt} do
      assert {:ok, [72, 101, 108, 108, 111]} =
               QuickBEAM.eval(rt, "[...new TextEncoder().encode('Hello')]")
    end

    test "encode empty string", %{rt: rt} do
      assert {:ok, []} = QuickBEAM.eval(rt, "[...new TextEncoder().encode('')]")
    end

    test "encode undefined returns empty", %{rt: rt} do
      assert {:ok, []} = QuickBEAM.eval(rt, "[...new TextEncoder().encode()]")
      assert {:ok, []} = QuickBEAM.eval(rt, "[...new TextEncoder().encode(undefined)]")
    end

    test "encode multibyte UTF-8", %{rt: rt} do
      # ¢ = U+00A2 = [0xC2, 0xA2]
      assert {:ok, [0xC2, 0xA2]} = QuickBEAM.eval(rt, "[...new TextEncoder().encode('¢')]")

      # 水 = U+6C34 = [0xE6, 0xB0, 0xB4]
      assert {:ok, [0xE6, 0xB0, 0xB4]} =
               QuickBEAM.eval(rt, "[...new TextEncoder().encode('水')]")

      # 𝄞 = U+1D11E = [0xF0, 0x9D, 0x84, 0x9E]
      assert {:ok, [0xF0, 0x9D, 0x84, 0x9E]} =
               QuickBEAM.eval(rt, "[...new TextEncoder().encode('𝄞')]")
    end

    test "encode returns Uint8Array", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, "new TextEncoder().encode('test') instanceof Uint8Array")
    end

    test "encodeInto basic", %{rt: rt} do
      assert {:ok, %{"read" => 2, "written" => 2}} =
               QuickBEAM.eval(rt, """
               const enc = new TextEncoder();
               const buf = new Uint8Array(10);
               enc.encodeInto('Hi', buf);
               """)
    end

    test "encodeInto with insufficient buffer", %{rt: rt} do
      assert {:ok, %{"read" => 0, "written" => 0}} =
               QuickBEAM.eval(rt, """
               const enc = new TextEncoder();
               const buf = new Uint8Array(0);
               enc.encodeInto('Hi', buf);
               """)
    end

    test "encodeInto with multibyte char that doesn't fit", %{rt: rt} do
      # 𝌆 is 4 bytes in UTF-8, buffer has only 3 bytes
      assert {:ok, %{"read" => 0, "written" => 0}} =
               QuickBEAM.eval(rt, """
               const enc = new TextEncoder();
               const buf = new Uint8Array(3);
               enc.encodeInto('\\u{1D306}', buf);
               """)
    end

    test "encodeInto surrogate pair counts as 2 read chars", %{rt: rt} do
      assert {:ok, %{"read" => 2, "written" => 4}} =
               QuickBEAM.eval(rt, """
               const enc = new TextEncoder();
               const buf = new Uint8Array(4);
               enc.encodeInto('\\u{1D306}', buf);
               """)
    end
  end

  describe "TextDecoder" do
    test "encoding property is utf-8", %{rt: rt} do
      assert {:ok, "utf-8"} = QuickBEAM.eval(rt, "new TextDecoder().encoding")
    end

    test "decode ASCII bytes", %{rt: rt} do
      assert {:ok, "Hello"} =
               QuickBEAM.eval(
                 rt,
                 "new TextDecoder().decode(new Uint8Array([72, 101, 108, 108, 111]))"
               )
    end

    test "decode empty", %{rt: rt} do
      assert {:ok, ""} = QuickBEAM.eval(rt, "new TextDecoder().decode()")
      assert {:ok, ""} = QuickBEAM.eval(rt, "new TextDecoder().decode(undefined)")
    end

    test "decode multibyte UTF-8", %{rt: rt} do
      assert {:ok, "¢"} =
               QuickBEAM.eval(rt, "new TextDecoder().decode(new Uint8Array([0xC2, 0xA2]))")

      assert {:ok, "水"} =
               QuickBEAM.eval(rt, "new TextDecoder().decode(new Uint8Array([0xE6, 0xB0, 0xB4]))")
    end

    test "decode ArrayBuffer directly", %{rt: rt} do
      assert {:ok, "AB"} =
               QuickBEAM.eval(rt, "new TextDecoder().decode(new Uint8Array([65, 66]).buffer)")
    end

    test "round-trip encode/decode", %{rt: rt} do
      assert {:ok, "Hello, 世界!"} =
               QuickBEAM.eval(rt, """
               const text = 'Hello, 世界!';
               const encoded = new TextEncoder().encode(text);
               new TextDecoder().decode(encoded);
               """)
    end

    test "constructor with utf-8 label", %{rt: rt} do
      assert {:ok, "utf-8"} = QuickBEAM.eval(rt, "new TextDecoder('utf-8').encoding")
      assert {:ok, "utf-8"} = QuickBEAM.eval(rt, "new TextDecoder('UTF-8').encoding")
      assert {:ok, "utf-8"} = QuickBEAM.eval(rt, "new TextDecoder('utf8').encoding")
    end

    test "constructor with unsupported encoding throws", %{rt: rt} do
      assert {:error, _} = QuickBEAM.eval(rt, "new TextDecoder('windows-1252')")
    end
  end

  describe "btoa" do
    test "encode ASCII", %{rt: rt} do
      assert {:ok, "SGVsbG8="} = QuickBEAM.eval(rt, "btoa('Hello')")
    end

    test "encode empty string", %{rt: rt} do
      assert {:ok, ""} = QuickBEAM.eval(rt, "btoa('')")
    end

    test "encode various lengths", %{rt: rt} do
      assert {:ok, "YQ=="} = QuickBEAM.eval(rt, "btoa('a')")
      assert {:ok, "YWI="} = QuickBEAM.eval(rt, "btoa('ab')")
      assert {:ok, "YWJj"} = QuickBEAM.eval(rt, "btoa('abc')")
      assert {:ok, "YWJjZA=="} = QuickBEAM.eval(rt, "btoa('abcd')")
    end

    test "encode all Latin-1 chars", %{rt: rt} do
      # First 256 code points should all work
      assert {:ok, _} =
               QuickBEAM.eval(rt, """
               let s = '';
               for (let i = 0; i < 256; i++) s += String.fromCharCode(i);
               btoa(s);
               """)
    end

    test "throw on non-Latin-1 chars", %{rt: rt} do
      assert {:error, _} = QuickBEAM.eval(rt, "btoa('\\u0100')")
      assert {:error, _} = QuickBEAM.eval(rt, "btoa('\\u{1F600}')")
    end

    test "WebIDL type coercion", %{rt: rt} do
      assert {:ok, _} = QuickBEAM.eval(rt, "btoa(undefined)")
      assert {:ok, _} = QuickBEAM.eval(rt, "btoa(null)")
      assert {:ok, _} = QuickBEAM.eval(rt, "btoa(12)")
    end
  end

  describe "atob" do
    test "decode basic", %{rt: rt} do
      assert {:ok, "Hello"} = QuickBEAM.eval(rt, "atob('SGVsbG8=')")
    end

    test "round-trip", %{rt: rt} do
      assert {:ok, "Hello, World!"} = QuickBEAM.eval(rt, "atob(btoa('Hello, World!'))")
    end

    test "decode without padding", %{rt: rt} do
      assert {:ok, "Hello"} = QuickBEAM.eval(rt, "atob('SGVsbG8')")
    end

    test "decode with whitespace", %{rt: rt} do
      assert {:ok, "Hello"} = QuickBEAM.eval(rt, "atob(' SGVs bG8= ')")
    end

    test "throw on invalid input", %{rt: rt} do
      assert {:error, _} = QuickBEAM.eval(rt, "atob('!')")
    end

    test "binary string round-trip", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               let s = '';
               for (let i = 0; i < 256; i++) s += String.fromCharCode(i);
               atob(btoa(s)) === s;
               """)
    end
  end

  describe "crypto.getRandomValues" do
    test "fills Uint8Array", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const arr = new Uint8Array(16);
               const result = crypto.getRandomValues(arr);
               result === arr && arr.some(x => x !== 0);
               """)
    end

    test "fills Uint32Array", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const arr = new Uint32Array(4);
               crypto.getRandomValues(arr);
               arr.some(x => x !== 0);
               """)
    end

    test "returns the same array", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const arr = new Uint8Array(8);
               crypto.getRandomValues(arr) === arr;
               """)
    end

    test "throws for too large buffer", %{rt: rt} do
      assert {:error, _} =
               QuickBEAM.eval(rt, "crypto.getRandomValues(new Uint8Array(65537))")
    end
  end

  describe "performance.now" do
    test "returns a number", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, "typeof performance.now() === 'number'")
    end

    test "is monotonically increasing", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const a = performance.now();
               let x = 0;
               for (let i = 0; i < 10000; i++) x += i;
               const b = performance.now();
               b > a;
               """)
    end

    test "returns milliseconds (not too large)", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const t = performance.now();
               t >= 0 && t < 60000;
               """)
    end
  end

  describe "queueMicrotask" do
    test "executes callback", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               await new Promise(resolve => {
                 let called = false;
                 queueMicrotask(() => { called = true; });
                 // Microtask runs before the next macrotask
                 Promise.resolve().then(() => resolve(called));
               });
               """)
    end

    test "executes in order", %{rt: rt} do
      assert {:ok, [1, 2, 3]} =
               QuickBEAM.eval(rt, """
               await new Promise(resolve => {
                 const order = [];
                 queueMicrotask(() => order.push(1));
                 queueMicrotask(() => order.push(2));
                 queueMicrotask(() => order.push(3));
                 Promise.resolve().then(() => resolve(order));
               });
               """)
    end
  end

  describe "structuredClone" do
    test "clones objects", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const orig = { a: 1, b: [2, 3] };
               const clone = structuredClone(orig);
               clone.a === 1 && clone.b[0] === 2 && clone.b[1] === 3 && clone !== orig && clone.b !== orig.b;
               """)
    end

    test "clones nested structures", %{rt: rt} do
      assert {:ok, true} =
               QuickBEAM.eval(rt, """
               const orig = { x: { y: { z: 42 } } };
               const clone = structuredClone(orig);
               clone.x.y.z === 42 && clone.x !== orig.x;
               """)
    end

    test "clones arrays", %{rt: rt} do
      assert {:ok, [1, 2, 3]} = QuickBEAM.eval(rt, "structuredClone([1, 2, 3])")
    end

    test "clones primitives", %{rt: rt} do
      assert {:ok, 42} = QuickBEAM.eval(rt, "structuredClone(42)")
      assert {:ok, "hello"} = QuickBEAM.eval(rt, "structuredClone('hello')")
      assert {:ok, true} = QuickBEAM.eval(rt, "structuredClone(true)")
      assert {:ok, nil} = QuickBEAM.eval(rt, "structuredClone(null)")
    end
  end
end
