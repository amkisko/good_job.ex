defmodule GoodJob.Registry do
  @moduledoc """
  Registry for GoodJob processes.

  Used to register and lookup schedulers, task supervisors, etc.
  """

  def start_link(_opts \\ []) do
    Registry.start_link(keys: :unique, name: __MODULE__, partitions: System.schedulers_online())
  end
end
