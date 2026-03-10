defmodule QuickBEAM.ProcessTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, rt} = QuickBEAM.start()
    on_exit(fn -> if Process.alive?(rt), do: QuickBEAM.stop(rt) end)
    %{rt: rt}
  end

  describe "beam.self()" do
    test "returns the owner GenServer PID", %{rt: rt} do
      {:ok, result} = QuickBEAM.eval(rt, "beam.self()")
      assert is_pid(result)
      assert result == rt
    end
  end

  describe "Process.onMessage" do
    test "receives messages from Elixir", %{rt: rt} do
      QuickBEAM.eval(rt, """
      globalThis.messages = [];
      Process.onMessage((msg) => {
        globalThis.messages.push(msg);
      });
      """)

      QuickBEAM.send_message(rt, "hello")
      QuickBEAM.send_message(rt, 42)
      QuickBEAM.send_message(rt, %{key: "value"})
      Process.sleep(50)

      {:ok, messages} = QuickBEAM.eval(rt, "globalThis.messages")
      assert messages == ["hello", 42, %{"key" => "value"}]
    end

    test "replaces previous handler", %{rt: rt} do
      QuickBEAM.eval(rt, """
      globalThis.result = [];
      Process.onMessage((msg) => { globalThis.result.push("first:" + msg); });
      """)

      QuickBEAM.send_message(rt, "a")
      Process.sleep(30)

      QuickBEAM.eval(rt, """
      Process.onMessage((msg) => { globalThis.result.push("second:" + msg); });
      """)

      QuickBEAM.send_message(rt, "b")
      Process.sleep(30)

      {:ok, result} = QuickBEAM.eval(rt, "globalThis.result")
      assert result == ["first:a", "second:b"]
    end

    test "receives messages during await", _ctx do
      {:ok, rt} =
        QuickBEAM.start(
          handlers: %{
            "slow_call" => fn _ ->
              Process.sleep(100)
              "done"
            end
          }
        )

      QuickBEAM.eval(rt, """
      globalThis.received = [];
      Process.onMessage((msg) => {
        globalThis.received.push(msg);
      });
      """)

      task =
        Task.async(fn ->
          QuickBEAM.eval(rt, """
          const result = await beam.call("slow_call");
          result;
          """)
        end)

      Process.sleep(30)
      QuickBEAM.send_message(rt, "during_await")
      {:ok, result} = Task.await(task)
      assert result == "done"

      {:ok, received} = QuickBEAM.eval(rt, "globalThis.received")
      assert received == ["during_await"]

      QuickBEAM.stop(rt)
    end

    test "discards messages when no handler is set", %{rt: rt} do
      QuickBEAM.send_message(rt, "dropped")
      Process.sleep(30)
      {:ok, result} = QuickBEAM.eval(rt, "typeof globalThis.lastMessage")
      assert result == "undefined"
    end

    test "handler errors don't crash the runtime", %{rt: rt} do
      QuickBEAM.eval(rt, """
      Process.onMessage((msg) => {
        throw new Error("handler error");
      });
      """)

      QuickBEAM.send_message(rt, "trigger_error")
      Process.sleep(30)

      {:ok, result} = QuickBEAM.eval(rt, "1 + 1")
      assert result == 2
    end

    test "requires a function argument", %{rt: rt} do
      {:error, error} = QuickBEAM.eval(rt, "Process.onMessage('not a function')")
      assert error.message =~ "function"
    end
  end

  describe "beam.send" do
    test "sends a message to a BEAM process", %{rt: rt} do
      QuickBEAM.eval(rt, """
      globalThis.targetPid = null;
      Process.onMessage((msg) => {
        globalThis.targetPid = msg;
      });
      """)

      # Send our PID to the JS runtime
      QuickBEAM.send_message(rt, self())
      Process.sleep(30)

      # Now JS sends a message back to us
      QuickBEAM.eval(rt, "beam.send(globalThis.targetPid, {from: 'js', value: 42})")

      assert_receive %{"from" => "js", "value" => 42}, 1000
    end

    test "sends complex data types", %{rt: rt} do
      QuickBEAM.eval(rt, """
      Process.onMessage((pid) => {
        beam.send(pid, [1, "hello", true, null, {nested: "value"}]);
      });
      """)

      QuickBEAM.send_message(rt, self())
      assert_receive [1, "hello", true, nil, %{"nested" => "value"}], 1000
    end

    test "requires pid and message arguments", %{rt: rt} do
      {:error, error} = QuickBEAM.eval(rt, "beam.send()")
      assert error.message =~ "pid and a message"
    end

    test "throws on invalid PID", %{rt: rt} do
      {:error, error} = QuickBEAM.eval(rt, "beam.send('not_a_pid', 'hello')")
      assert error.message =~ "PID"
    end
  end

  describe "PID round-trip" do
    test "PID survives Elixir→JS→Elixir conversion", %{rt: rt} do
      original_pid = self()

      {:ok, _} =
        QuickBEAM.start(
          handlers: %{
            "echo" => fn [val] -> val end
          }
        )

      QuickBEAM.eval(rt, """
      globalThis.storedPid = null;
      Process.onMessage((msg) => {
        globalThis.storedPid = msg;
      });
      """)

      QuickBEAM.send_message(rt, original_pid)
      Process.sleep(30)

      {:ok, returned_pid} = QuickBEAM.eval(rt, "globalThis.storedPid")
      assert returned_pid == original_pid
    end
  end
end
