defmodule GoodJob.Web.LiveDashboardPage.Helpers do
  @moduledoc """
  Helper functions for LiveDashboard page.
  """

  @default_poll_interval 30_000

  @views %{
    "overview" => :overview,
    "jobs" => :jobs,
    "job_detail" => :job_detail,
    "cron" => :cron,
    "pauses" => :pauses,
    "batches" => :batches,
    "processes" => :processes
  }

  @doc """
  Parses view from params.
  """
  def parse_view(%{"view" => view}) when is_binary(view) do
    Map.get(@views, view, :overview)
  end

  def parse_view(_), do: :overview

  @doc """
  Parses poll interval from params.
  """
  def parse_poll_interval(%{"poll" => poll_str}) do
    case Integer.parse(poll_str) do
      {seconds, _} -> seconds * 1000
      _ -> @default_poll_interval
    end
  end

  def parse_poll_interval(_), do: @default_poll_interval

  @doc """
  Parses page number from params.
  """
  def parse_page(%{"page" => page_str}) when is_binary(page_str) do
    case Integer.parse(page_str) do
      {page, _} -> max(1, page)
      _ -> 1
    end
  end

  def parse_page(_), do: 1

  @doc """
  Schedules a refresh.
  """
  def schedule_refresh(socket) do
    interval = socket.assigns.poll_interval
    Process.send_after(self(), :refresh, interval)
  end

  @doc """
  Builds URI for navigation.
  """
  def build_uri(view, job_id, assigns) do
    query =
      [view: to_string(view)]
      |> maybe_add_query(:job_id, job_id)
      |> maybe_add_query(:page, page_query_value(assigns))
      |> maybe_add_query(:state, assigns[:filter_state])
      |> maybe_add_query(:queue, assigns[:filter_queue])

    "/dashboard/good_job?" <> URI.encode_query(query)
  end

  defp page_query_value(assigns) do
    page = assigns[:current_page]

    if is_integer(page) and page > 1 do
      page
    end
  end

  defp maybe_add_query(query, _key, nil), do: query
  defp maybe_add_query(query, _key, ""), do: query
  defp maybe_add_query(query, key, value), do: query ++ [{key, to_string(value)}]
end
