defmodule GoodJob.Plugins.Lifeline do
  @moduledoc """
  Built-in plugin that recovers jobs stuck in executing state.

  This plugin periodically checks for jobs that have been executing for too long and
  marks them as available for retry.

  ## Configuration

      config :good_job,
        plugins: [
          {GoodJob.Plugins.Lifeline, rescue_after: 300}
        ]

  ## Options

    * `:rescue_after` - Seconds after which to rescue stuck jobs (default: 300 = 5 minutes)
    * `:interval` - How often to check for stuck jobs in seconds (default: 60 = 1 minute)
  """

  @behaviour GoodJob.Plugin

  use GenServer

  require Logger

  alias GoodJob.{Job, Repo}
  import Ecto.Query

  @default_rescue_after 300
  @default_interval 60

  @impl GoodJob.Plugin
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GoodJob.Plugin
  def validate(opts) do
    cond do
      opts[:rescue_after] && not is_integer(opts[:rescue_after]) ->
        {:error, "expected :rescue_after to be an integer"}

      opts[:interval] && not is_integer(opts[:interval]) ->
        {:error, "expected :interval to be an integer"}

      true ->
        :ok
    end
  end

  @impl GenServer
  def init(opts) do
    conf = Keyword.fetch!(opts, :conf)
    rescue_after = Keyword.get(opts, :rescue_after, @default_rescue_after)
    interval = Keyword.get(opts, :interval, @default_interval)

    state = %{
      conf: conf,
      rescue_after: rescue_after,
      interval: interval,
      timer: nil
    }

    {:ok, schedule_rescue(state)}
  end

  @impl GenServer
  def handle_info(:rescue, state) do
    rescue_stuck_jobs(state)
    {:noreply, schedule_rescue(state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_rescue(%{interval: interval} = state) do
    timer = Process.send_after(self(), :rescue, interval * 1000)
    %{state | timer: timer}
  end

  defp rescue_stuck_jobs(%{conf: _conf, rescue_after: rescue_after}) do
    cutoff = DateTime.add(DateTime.utc_now(), -rescue_after, :second)

    # Rescue jobs that are running (performed_at is set) but unfinished
    # and have been locked for too long. This handles crashed processes.
    query =
      from(j in Job,
        where: not is_nil(j.performed_at),
        where: is_nil(j.finished_at),
        where: not is_nil(j.locked_by_id),
        where: j.locked_at < ^cutoff,
        select: j.id
      )

    stuck_jobs = Repo.repo().all(query)

    if not Enum.empty?(stuck_jobs) do
      from(j in Job, where: j.id in ^stuck_jobs)
      |> Repo.repo().update_all(set: [locked_by_id: nil, locked_at: nil, performed_at: nil])

      Logger.warning("Rescued #{length(stuck_jobs)} stuck jobs")
    end

    length(stuck_jobs)
  end
end
