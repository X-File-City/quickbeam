defmodule QuickBEAM.WorkerAPI do
  @moduledoc false

  @worker_bootstrap """
  globalThis.self = globalThis;
  self.postMessage = function(data) {
    beam.call("__worker_post_to_parent", data);
  };
  Object.defineProperty(self, "onmessage", {
    set(handler) { Process.onMessage(msg => {
      if (Array.isArray(msg) && msg[0] === "__worker_msg") {
        handler({ data: msg[1] });
      }
    }); },
    configurable: true,
  });
  """

  def spawn_worker([script], parent_pid) do
    {:ok, child} =
      QuickBEAM.start(
        handlers: %{
          "__worker_post_to_parent" =>
            {:with_caller, fn [message], child_pid ->
              send(parent_pid, {:worker_message_from_child, child_pid, message})
              nil
            end}
        }
      )

    send(parent_pid, {:worker_monitor, child})

    QuickBEAM.eval(child, @worker_bootstrap)

    Task.start(fn ->
      case QuickBEAM.eval(child, script) do
        {:ok, _} -> :ok
        {:error, err} -> send(parent_pid, {:worker_error_from_child, child, err})
      end
    end)

    child
  end

  def post_to_worker([worker_pid, message]) do
    QuickBEAM.send_message(worker_pid, ["__worker_msg", message])
    nil
  end

  def terminate_worker([worker_pid]) do
    Task.start(fn -> QuickBEAM.stop(worker_pid) end)
    nil
  end
end
