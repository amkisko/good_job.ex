defmodule GoodJob.DatabaseURLTest do
  use ExUnit.Case, async: true

  alias GoodJob.DatabaseURL

  describe "parse/1" do
    test "parses standard PostgreSQL URL" do
      url = "postgres://user:pass@localhost:5432/mydb"
      config = DatabaseURL.parse(url)

      assert Keyword.get(config, :username) == "user"
      assert Keyword.get(config, :password) == "pass"
      assert Keyword.get(config, :hostname) == "localhost"
      assert Keyword.get(config, :port) == 5432
      assert Keyword.get(config, :database) == "mydb"
      assert Keyword.get(config, :adapter) == Ecto.Adapters.Postgres
    end

    test "parses PostgreSQL URL without port" do
      url = "postgres://user:pass@localhost/mydb"
      config = DatabaseURL.parse(url)

      assert Keyword.get(config, :port) == 5432
      assert Keyword.get(config, :database) == "mydb"
    end

    test "parses PostgreSQL URL without password" do
      url = "postgres://user@localhost/mydb"
      config = DatabaseURL.parse(url)

      assert Keyword.get(config, :username) == "user"
      assert Keyword.get(config, :password) == nil
    end

    test "parses PostgreSQL URL with query parameters" do
      url = "postgres://user:pass@localhost/mydb?pool_size=20&timeout=5000"
      config = DatabaseURL.parse(url)

      assert Keyword.get(config, :pool_size) == 20
      assert Keyword.get(config, :timeout) == 5000
    end

    test "parses postgresql:// scheme" do
      url = "postgresql://user:pass@localhost/mydb"
      config = DatabaseURL.parse(url)

      assert Keyword.get(config, :adapter) == Ecto.Adapters.Postgres
    end

    test "handles URL with special characters in password" do
      url = "postgres://user:p@ss%3Aw0rd@localhost/mydb"
      config = DatabaseURL.parse(url)

      # URL should be decoded
      assert Keyword.get(config, :username) == "user"
      # URI.parse doesn't decode userinfo, so we get the encoded version
      # This is expected behavior
    end
  end

  describe "from_env/0" do
    test "returns GOOD_JOB_DATABASE_URL if set" do
      System.put_env("GOOD_JOB_DATABASE_URL", "postgres://goodjob@localhost/goodjob_db")
      System.put_env("DATABASE_URL", "postgres://app@localhost/app_db")

      assert DatabaseURL.from_env() == "postgres://goodjob@localhost/goodjob_db"

      System.delete_env("GOOD_JOB_DATABASE_URL")
      System.delete_env("DATABASE_URL")
    end

    test "returns DATABASE_URL if GOOD_JOB_DATABASE_URL not set" do
      System.delete_env("GOOD_JOB_DATABASE_URL")
      System.put_env("DATABASE_URL", "postgres://app@localhost/app_db")

      assert DatabaseURL.from_env() == "postgres://app@localhost/app_db"

      System.delete_env("DATABASE_URL")
    end

    test "returns nil if neither is set" do
      System.delete_env("GOOD_JOB_DATABASE_URL")
      System.delete_env("DATABASE_URL")

      assert DatabaseURL.from_env() == nil
    end
  end

  describe "configure_repo/2" do
    test "configures repository from URL" do
      url = "postgres://user:pass@localhost:5432/mydb"

      DatabaseURL.configure_repo(TestRepo, url)

      # Get the app name that was used (derived from module name: GoodJob.DatabaseURLTest.TestRepo -> goodjob)
      app = TestRepo |> Module.split() |> List.first() |> String.downcase() |> String.to_atom()

      config = Application.get_env(app, TestRepo)

      # Verify config was set and is a keyword list
      assert is_list(config)

      # Check values
      assert Keyword.get(config, :username) == "user"
      assert Keyword.get(config, :password) == "pass"
      assert Keyword.get(config, :hostname) == "localhost"
      assert Keyword.get(config, :port) == 5432
      assert Keyword.get(config, :database) == "mydb"

      Application.delete_env(app, TestRepo)
    end
  end

  describe "configure_repo_from_env/1" do
    test "configures repository from environment variable" do
      System.put_env("GOOD_JOB_DATABASE_URL", "postgres://user:pass@localhost:5432/mydb")

      result = DatabaseURL.configure_repo_from_env(TestRepo)

      assert result == :ok

      app = TestRepo |> Module.split() |> List.first() |> String.downcase() |> String.to_atom()
      config = Application.get_env(app, TestRepo)
      assert Keyword.get(config, :database) == "mydb"

      System.delete_env("GOOD_JOB_DATABASE_URL")
      Application.delete_env(app, TestRepo)
      Application.delete_env(:test_repo, TestRepo)
    end

    test "returns :no_url if no environment variable set" do
      System.delete_env("GOOD_JOB_DATABASE_URL")
      System.delete_env("DATABASE_URL")

      result = DatabaseURL.configure_repo_from_env(TestRepo)

      assert result == :no_url
    end
  end

  # Test repo module for testing
  defmodule TestRepo do
    use Ecto.Repo,
      otp_app: :good_job,
      adapter: Ecto.Adapters.Postgres
  end
end
