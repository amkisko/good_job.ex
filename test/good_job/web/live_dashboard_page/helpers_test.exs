defmodule GoodJob.Web.LiveDashboardPage.HelpersTest do
  use ExUnit.Case, async: true

  alias GoodJob.Web.LiveDashboardPage.Helpers

  test "parse_view maps known views and falls back to overview" do
    assert Helpers.parse_view(%{"view" => "jobs"}) == :jobs
    assert Helpers.parse_view(%{"view" => "cron"}) == :cron
    assert Helpers.parse_view(%{"view" => "unknown"}) == :overview
    assert Helpers.parse_view(%{}) == :overview
  end

  test "build_uri encodes query values" do
    uri =
      Helpers.build_uri(:jobs, "id with space", %{
        current_page: 2,
        filter_state: "queued",
        filter_queue: "mail & reports"
      })

    assert String.starts_with?(uri, "/dashboard/good_job?")
    query = uri |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    assert query["view"] == "jobs"
    assert query["job_id"] == "id with space"
    assert query["page"] == "2"
    assert query["state"] == "queued"
    assert query["queue"] == "mail & reports"
  end

  test "build_uri omits default page and empty filters" do
    uri = Helpers.build_uri(:overview, nil, %{current_page: 1})
    query = uri |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    assert query == %{"view" => "overview"}
  end
end
