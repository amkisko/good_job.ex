defmodule GoodJob.DatabaseURLTest do
  use ExUnit.Case, async: true

  alias GoodJob.DatabaseURL

  setup do
    original_good_job_url = System.get_env("GOOD_JOB_DATABASE_URL")
    original_database_url = System.get_env("DATABASE_URL")

    on_exit(fn ->
      if original_good_job_url do
        System.put_env("GOOD_JOB_DATABASE_URL", original_good_job_url)
      else
        System.delete_env("GOOD_JOB_DATABASE_URL")
      end

      if original_database_url do
        System.put_env("DATABASE_URL", original_database_url)
      else
        System.delete_env("DATABASE_URL")
      end
    end)

    :ok
  end

  test "parses database url with userinfo, port, and query params" do
    config =
      DatabaseURL.parse(
        "postgres://user:pass@localhost:5433/mydb?pool_size=5&ssl=true&timeout=3000"
      )

    assert config[:username] == "user"
    assert config[:password] == "pass"
    assert config[:hostname] == "localhost"
    assert config[:port] == 5433
    assert config[:database] == "mydb"
    assert config[:pool_size] == 5
    assert config[:ssl] == "true"
    assert config[:timeout] == 3000
  end

  test "parses database url without userinfo" do
    config = DatabaseURL.parse("postgres://localhost/mydb")
    assert config[:username] == nil
    assert config[:password] == nil
    assert config[:database] == "mydb"
    assert config[:port] == 5432
  end

  test "from_env prefers GOOD_JOB_DATABASE_URL" do
    System.put_env("GOOD_JOB_DATABASE_URL", "postgres://goodjob@localhost/goodjob")
    System.put_env("DATABASE_URL", "postgres://fallback@localhost/fallback")

    assert DatabaseURL.from_env() == "postgres://goodjob@localhost/goodjob"
  end

  test "configure_repo_from_env returns :no_url when unset" do
    System.delete_env("GOOD_JOB_DATABASE_URL")
    System.delete_env("DATABASE_URL")

    assert DatabaseURL.configure_repo_from_env(GoodJob.Repo.repo()) == :no_url
  end
end
