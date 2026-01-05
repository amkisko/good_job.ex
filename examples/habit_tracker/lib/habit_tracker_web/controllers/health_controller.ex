defmodule HabitTrackerWeb.HealthController do
  @moduledoc """
  Health check controller for monitoring GoodJob status.
  """
  use HabitTrackerWeb, :controller

  def check(conn, _params) do
    status = GoodJob.HealthCheck.status()
    code = if status == "healthy", do: 200, else: 503

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(code, status)
  end

  def status(conn, _params) do
    case GoodJob.HealthCheck.check() do
      {:ok, details} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "healthy", details: details}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{status: "unhealthy", error: reason}))
    end
  end
end
