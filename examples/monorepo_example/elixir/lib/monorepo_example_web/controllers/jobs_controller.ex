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

  def enqueue(conn, %{"job_type" => "globalid"}) do
    # Test GlobalID resolution - enqueue a job with a GlobalID
    # This simulates what Rails would send
    case GoodJob.enqueue("GlobalIDTestJob", %{
           user: %{
             "_aj_globalid" => "gid://myapp/User/#{Enum.random(1..100)}"
           },
           message: "GlobalID test from Elixir UI at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "GlobalID test job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue GlobalID test job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, %{"job_type" => "concurrency"}) do
    # Test concurrency limits
    resource_id = Enum.random(1..10) |> to_string()
    case GoodJob.enqueue("ConcurrencyTestJob", %{
           key: resource_id,
           message: "Concurrency test from Elixir UI at #{DateTime.utc_now()}"
         }, concurrency_key: resource_id) do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Concurrency test job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue concurrency test job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, %{"job_type" => "cross_language_concurrency"}) do
    # Test cross-language concurrency
    resource_id = Enum.random(1..5) |> to_string()
    case GoodJob.enqueue("CrossLanguageConcurrencyJob", %{
           resource_id: resource_id,
           action: "process"
         }, concurrency_key: "resource:#{resource_id}") do
      {:ok, _job} ->
        conn
        |> put_flash(:info, "Cross-language concurrency test job enqueued successfully!")
        |> redirect(to: "/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to enqueue cross-language concurrency test job: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  def enqueue(conn, _params) do
    conn
    |> put_flash(:error, "Invalid job type")
    |> redirect(to: "/")
  end
end
