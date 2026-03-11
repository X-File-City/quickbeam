defmodule QuickBEAM.Storage do
  @moduledoc false

  @table :quickbeam_local_storage

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  def get_item([key]) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def set_item([key, value]) do
    :ets.insert(@table, {key, value})
    nil
  end

  def remove_item([key]) do
    :ets.delete(@table, key)
    nil
  end

  def clear(_args) do
    :ets.delete_all_objects(@table)
    nil
  end

  def key([index]) when is_integer(index) do
    keys = :ets.select(@table, [{{:"$1", :_}, [], [:"$1"]}])
    Enum.at(Enum.sort(keys), index)
  end

  def key(_), do: nil

  def length(_args) do
    :ets.info(@table, :size)
  end
end
