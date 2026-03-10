defmodule QuickBEAM.MemoryTest do
  use ExUnit.Case

  @tag :memory
  describe "memory stability" do
    test "eval cycle does not leak" do
      {:ok, rt} = QuickBEAM.start()

      # Warm up
      for _ <- 1..10, do: QuickBEAM.eval(rt, "1 + 1")
      :erlang.garbage_collect()
      Process.sleep(50)

      mem_before = :erlang.memory(:total)

      for _ <- 1..1000 do
        QuickBEAM.eval(rt, "1 + 1")
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before
      # Allow up to 512KB growth (BEAM overhead, caches, etc.)
      assert growth < 512 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 1000 evals"

      QuickBEAM.stop(rt)
    end

    test "TextEncoder cycle does not leak" do
      {:ok, rt} = QuickBEAM.start()

      for _ <- 1..10, do: QuickBEAM.eval(rt, "new TextEncoder().encode('warmup')")
      :erlang.garbage_collect()
      Process.sleep(50)

      mem_before = :erlang.memory(:total)

      for _ <- 1..1000 do
        QuickBEAM.eval(rt, "new TextEncoder().encode('hello world test string')")
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before

      assert growth < 512 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 1000 TextEncoder evals"

      QuickBEAM.stop(rt)
    end

    test "btoa/atob cycle does not leak" do
      {:ok, rt} = QuickBEAM.start()

      for _ <- 1..10, do: QuickBEAM.eval(rt, "atob(btoa('warmup'))")
      :erlang.garbage_collect()
      Process.sleep(50)

      mem_before = :erlang.memory(:total)

      for _ <- 1..1000 do
        QuickBEAM.eval(rt, "atob(btoa('The quick brown fox jumps over the lazy dog'))")
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before

      assert growth < 512 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 1000 atob/btoa evals"

      QuickBEAM.stop(rt)
    end

    test "beam.call cycle does not leak" do
      {:ok, rt} = QuickBEAM.start(handlers: %{"test" => fn args -> {:ok, args} end})

      for _ <- 1..10, do: QuickBEAM.eval(rt, "await beam.call('test', 42)")
      :erlang.garbage_collect()
      Process.sleep(50)

      mem_before = :erlang.memory(:total)

      for _ <- 1..1000 do
        QuickBEAM.eval(rt, "await beam.call('test', 'hello')")
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before

      assert growth < 1024 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 1000 beam.call evals"

      QuickBEAM.stop(rt)
    end

    test "reset cycle does not leak" do
      {:ok, rt} = QuickBEAM.start()

      for _ <- 1..3, do: QuickBEAM.reset(rt)
      :erlang.garbage_collect()
      Process.sleep(50)

      mem_before = :erlang.memory(:total)

      for _ <- 1..50 do
        QuickBEAM.eval(rt, "globalThis.x = 'some data'.repeat(100)")
        QuickBEAM.reset(rt)
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before

      assert growth < 1024 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 50 reset cycles"

      QuickBEAM.stop(rt)
    end

    test "runtime start/stop cycle does not leak" do
      for _ <- 1..5 do
        {:ok, rt} = QuickBEAM.start()
        QuickBEAM.eval(rt, "1 + 1")
        QuickBEAM.stop(rt)
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      mem_before = :erlang.memory(:total)

      for _ <- 1..20 do
        {:ok, rt} = QuickBEAM.start()
        QuickBEAM.eval(rt, "globalThis.data = 'x'.repeat(10000)")
        QuickBEAM.stop(rt)
      end

      :erlang.garbage_collect()
      Process.sleep(100)
      mem_after = :erlang.memory(:total)

      growth = mem_after - mem_before

      assert growth < 2 * 1024 * 1024,
             "Memory grew by #{div(growth, 1024)}KB over 20 start/stop cycles"
    end
  end
end
