defmodule GoodJob.SettingManagerTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.SettingManager
  alias GoodJob.SettingSchema
  alias GoodJob.Repo

  setup do
    repo = Repo.repo()
    Ecto.Adapters.SQL.Sandbox.checkout(repo)
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    :ok
  end

  test "pause and unpause by queue" do
    assert SettingManager.paused?(queue: "default") == false
    SettingManager.pause(queue: "default")
    assert SettingManager.paused?(queue: "default") == true

    SettingManager.unpause(queue: "default")
    assert SettingManager.paused?(queue: "default") == false
  end

  test "pause and unpause by job_class" do
    assert SettingManager.paused?(job_class: "MyJob") == false
    SettingManager.pause(job_class: "MyJob")
    assert SettingManager.paused?(job_class: "MyJob") == true

    SettingManager.unpause(job_class: "MyJob")
    assert SettingManager.paused?(job_class: "MyJob") == false
  end

  test "pause/unpause return errors for invalid options" do
    assert SettingManager.pause() == {:error, :invalid_options}
    assert SettingManager.unpause() == {:error, :invalid_options}
  end

  test "enable and disable cron keys" do
    SettingManager.enable_cron("cron-1")
    assert SettingManager.cron_key_enabled?("cron-1") == true

    SettingManager.disable_cron("cron-1")
    assert SettingManager.cron_key_enabled?("cron-1") == false
  end

  test "cron_key_enabled? respects default false" do
    repo = Repo.repo()
    repo.insert!(
      SettingSchema.changeset(%SettingSchema{}, %{key: "cron_keys_enabled", value: %{keys: ["cron-2"]}})
    )

    assert SettingManager.cron_key_enabled?("cron-2", false) == true
    assert SettingManager.cron_key_enabled?("cron-3", false) == false
  end

  test "unpause_by_key deletes setting" do
    repo = Repo.repo()
    setting =
      %SettingSchema{}
      |> SettingSchema.changeset(%{key: "pause:queue:default", value: %{paused: true}})
      |> repo.insert!()

    SettingManager.unpause_by_key(setting.key)
    assert repo.get_by(SettingSchema, key: setting.key) == nil
  end
end
