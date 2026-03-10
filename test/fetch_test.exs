defmodule QuickBEAM.FetchTest do
  use ExUnit.Case, async: false

  @moduletag :fetch

  setup do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)

    {:ok, rt} = QuickBEAM.start()

    on_exit(fn ->
      :gen_tcp.close(listen)
      if Process.alive?(rt), do: QuickBEAM.stop(rt)
    end)

    %{rt: rt, listen: listen, port: port}
  end

  defp serve_once(listen, response) do
    Task.start(fn ->
      {:ok, sock} = :gen_tcp.accept(listen, 5000)
      {:ok, _data} = recv_request(sock)
      :gen_tcp.send(sock, response)
      :gen_tcp.close(sock)
    end)
  end

  defp serve_once_with_request(listen, response) do
    parent = self()

    Task.start(fn ->
      {:ok, sock} = :gen_tcp.accept(listen, 5000)
      {:ok, data} = recv_request(sock)
      send(parent, {:request_data, data})
      :gen_tcp.send(sock, response)
      :gen_tcp.close(sock)
    end)
  end

  defp recv_request(sock) do
    recv_request(sock, <<>>)
  end

  defp recv_request(sock, acc) do
    case :gen_tcp.recv(sock, 0, 2000) do
      {:ok, data} ->
        acc = acc <> data

        if String.contains?(acc, "\r\n\r\n") do
          {:ok, acc}
        else
          recv_request(sock, acc)
        end

      {:error, :closed} ->
        {:ok, acc}
    end
  end

  describe "basic fetch" do
    test "GET request returns status and body", ctx do
      serve_once(ctx.listen, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello!")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/test");
          ({ status: r.status, ok: r.ok, body: await r.text() })
        """)

      assert result == %{"status" => 200, "ok" => true, "body" => "Hello!"}
    end

    test "GET request parses JSON", ctx do
      body = ~s|{"name":"beam","version":27}|

      serve_once(
        ctx.listen,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n#{body}"
      )

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/json");
          await r.json()
        """)

      assert result == %{"name" => "beam", "version" => 27}
    end

    test "non-200 status", ctx do
      serve_once(ctx.listen, "HTTP/1.1 404 Not Found\r\n\r\nNope")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/missing");
          ({ status: r.status, ok: r.ok, statusText: r.statusText })
        """)

      assert result["status"] == 404
      assert result["ok"] == false
      assert result["statusText"] == "Not Found"
    end

    test "response headers accessible", ctx do
      serve_once(
        ctx.listen,
        "HTTP/1.1 200 OK\r\nX-Custom: hello\r\nContent-Type: text/plain\r\n\r\nok"
      )

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/");
          r.headers.get("x-custom")
        """)

      assert result == "hello"
    end

    test "response body as bytes", ctx do
      serve_once(ctx.listen, "HTTP/1.1 200 OK\r\n\r\n\x00\x01\x02\x03")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/");
          const buf = await r.bytes();
          Array.from(buf)
        """)

      assert result == [0, 1, 2, 3]
    end

    test "response body as arrayBuffer", ctx do
      serve_once(ctx.listen, "HTTP/1.1 200 OK\r\n\r\nABCD")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/");
          const ab = await r.arrayBuffer();
          ab.byteLength
        """)

      assert result == 4
    end
  end

  describe "request methods and body" do
    test "POST with string body", ctx do
      serve_once_with_request(
        ctx.listen,
        "HTTP/1.1 200 OK\r\n\r\nok"
      )

      {:ok, _} =
        QuickBEAM.eval(ctx.rt, """
          await fetch("http://127.0.0.1:#{ctx.port}/post", {
            method: "POST",
            body: "hello world"
          })
        """)

      assert_receive {:request_data, data}, 2000
      assert data =~ "POST /post"
      assert data =~ "hello world"
      assert data =~ "text/plain"
    end

    test "POST with JSON body and custom headers", ctx do
      serve_once_with_request(
        ctx.listen,
        "HTTP/1.1 201 Created\r\n\r\nok"
      )

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/api", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ key: "value" })
          });
          r.status
        """)

      assert result == 201

      assert_receive {:request_data, data}, 2000
      assert data =~ "application/json"
      assert data =~ ~s|{"key":"value"}|
    end

    test "PUT method", ctx do
      serve_once_with_request(ctx.listen, "HTTP/1.1 200 OK\r\n\r\n")

      {:ok, _} =
        QuickBEAM.eval(ctx.rt, """
          await fetch("http://127.0.0.1:#{ctx.port}/", { method: "PUT", body: "data" })
        """)

      assert_receive {:request_data, data}, 2000
      assert data =~ "PUT /"
    end

    test "DELETE method", ctx do
      serve_once_with_request(ctx.listen, "HTTP/1.1 204 No Content\r\n\r\n")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const r = await fetch("http://127.0.0.1:#{ctx.port}/item/1", { method: "DELETE" });
          r.status
        """)

      assert result == 204
      assert_receive {:request_data, data}, 2000
      assert data =~ "DELETE /item/1"
    end
  end

  describe "Request object" do
    test "construct with URL string", ctx do
      serve_once(ctx.listen, "HTTP/1.1 200 OK\r\n\r\nok")

      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const req = new Request("http://127.0.0.1:#{ctx.port}/");
          const r = await fetch(req);
          r.status
        """)

      assert result == 200
    end

    test "clone a request", ctx do
      {:ok, result} =
        QuickBEAM.eval(ctx.rt, """
          const req = new Request("http://example.com", { method: "POST" });
          const clone = req.clone();
          clone.method
        """)

      assert result == "POST"
    end
  end

  describe "Response object" do
    test "Response.json() static method", _ctx do
      {:ok, rt} = QuickBEAM.start()

      {:ok, result} =
        QuickBEAM.eval(rt, """
          const r = Response.json({ hello: "world" });
          ({ status: r.status, type: r.headers.get("content-type"), body: await r.json() })
        """)

      assert result["status"] == 200
      assert result["type"] == "application/json"
      assert result["body"] == %{"hello" => "world"}
      QuickBEAM.stop(rt)
    end

    test "Response.error() static method", _ctx do
      {:ok, rt} = QuickBEAM.start()

      {:ok, result} =
        QuickBEAM.eval(rt, """
          const r = Response.error();
          r.status
        """)

      assert result == 0
      QuickBEAM.stop(rt)
    end

    test "Response.redirect() static method", _ctx do
      {:ok, rt} = QuickBEAM.start()

      {:ok, result} =
        QuickBEAM.eval(rt, """
          const r = Response.redirect("http://example.com", 301);
          ({ status: r.status, location: r.headers.get("location") })
        """)

      assert result == %{"status" => 301, "location" => "http://example.com"}
      QuickBEAM.stop(rt)
    end

    test "body can only be consumed once", _ctx do
      {:ok, rt} = QuickBEAM.start()

      {:ok, result} =
        QuickBEAM.eval(rt, """
          const r = Response.json({ a: 1 });
          await r.text();
          try { await r.text(); "no error" } catch(e) { e.message }
        """)

      assert result =~ "consumed"
      QuickBEAM.stop(rt)
    end

    test "clone preserves body", _ctx do
      {:ok, rt} = QuickBEAM.start()

      {:ok, result} =
        QuickBEAM.eval(rt, """
          const r = Response.json({ a: 1 });
          const r2 = r.clone();
          const t1 = await r.text();
          const t2 = await r2.text();
          t1 === t2
        """)

      assert result == true
      QuickBEAM.stop(rt)
    end
  end

  describe "error handling" do
    test "connection refused", ctx do
      :gen_tcp.close(ctx.listen)

      {:error, error} =
        QuickBEAM.eval(ctx.rt, """
          await fetch("http://127.0.0.1:#{ctx.port}/")
        """)

      assert error.message =~ "fetch failed"
    end
  end
end
