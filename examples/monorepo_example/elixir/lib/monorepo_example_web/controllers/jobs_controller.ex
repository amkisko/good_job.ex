defmodule MonorepoExampleWeb.JobsController do
  @moduledoc """
  Controller for handling job enqueueing requests.
  """
  use MonorepoExampleWeb, :controller

  def enqueue(conn, %{"job_type" => "elixir"}) do
    # Enqueue an Elixir job
    case MonorepoExample.Jobs.ScheduledElixirJob.perform_later(%{
           message: "Enqueued from Elixir web interface at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Elixir job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, %{"job_type" => "ruby"}) do
    # Enqueue a Ruby job using the descriptor module
    case MonorepoExample.Jobs.ExampleRubyJob.perform_later(%{
           message: "Enqueued from Elixir web interface at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Ruby job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue Ruby job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, %{"job_type" => "zig"}) do
    # Enqueue a Zig job - will be processed by Zig worker
    case GoodJob.enqueue(MonorepoExample.Jobs.ZigJob, %{
           message: "Enqueued from Elixir web interface at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Zig job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue Zig job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, _params) do
    conn
    |> put_flash(:error, "Invalid job type")
    |> redirect(to: "/")
  end
end
