defmodule MonorepoExample.Jobs.GlobalidTestJob do
  use GoodJob.Job, queue: "ex.default"

  @impl GoodJob.Behaviour
  def perform(%{user: user, message: message}) do
    require Logger

    case user do
      %{__struct__: :global_id, app: app, model: model, id: id, gid: gid} ->
        Logger.info("GlobalID resolved: app=#{app}, model=#{model}, id=#{id}, gid=#{gid}, message=#{message}")
        IO.puts("[Elixir Worker] GlobalIDTestJob: app=#{app}, model=#{model}, id=#{id}, message=#{message}")
        :ok

      other ->
        Logger.error("Expected GlobalID struct, got: #{inspect(other)}")
        {:error, :invalid_global_id}
    end
  end

  def perform(args) when is_map(args) do
    user = Map.get(args, :user) || Map.get(args, "user")
    message = Map.get(args, :message) || Map.get(args, "message") || "No message"
    perform(%{user: user, message: message})
  end
end
