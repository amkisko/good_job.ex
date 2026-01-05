defmodule GoodJob.Web.LiveDashboardPage.Helpers do
  @moduledoc """
  Helper functions for LiveDashboard page.
  """

  @default_poll_interval 30_000

  @doc """
  Parses view from params.
  """
  def parse_view(%{"view" => view})
      when view in ["overview", "jobs", "job_detail", "cron", "pauses", "batches", "processes"],
      do: String.to_atom(view)

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
    params = ["view=#{view}"]

    params = if job_id, do: ["job_id=#{job_id}" | params], else: params

    params =
      if assigns[:current_page] && assigns.current_page > 1,
        do: ["page=#{assigns.current_page}" | params],
        else: params

    params = if assigns[:filter_state], do: ["state=#{assigns.filter_state}" | params], else: params
    params = if assigns[:filter_queue], do: ["queue=#{assigns.filter_queue}" | params], else: params

    "/dashboard/good_job?" <> Enum.join(params, "&")
  end
end
