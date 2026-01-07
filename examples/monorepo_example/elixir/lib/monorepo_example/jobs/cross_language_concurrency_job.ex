defmodule MonorepoExample.Jobs.CrossLanguageConcurrencyJob do
  use GoodJob.Job, queue: "ex.default"

  @impl GoodJob.Behaviour
  def perform(%{resource_id: resource_id, action: action}) do
    require Logger
    Logger.info("CrossLanguageConcurrencyJob: resource_id=#{resource_id}, action=#{action}")
    Process.sleep(2000)

    Logger.info("CrossLanguageConcurrencyJob: Completed resource_id=#{resource_id}")
    :ok
  end

  def perform(args) when is_map(args) do
    resource_id = Map.get(args, :resource_id) || Map.get(args, "resource_id") || "unknown"
    action = Map.get(args, :action) || Map.get(args, "action") || "process"
    perform(%{resource_id: resource_id, action: action})
  end

  def good_job_concurrency_config do
    [total_limit: 2]
  end
end
