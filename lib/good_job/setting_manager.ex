defmodule GoodJob.SettingManager do
  @moduledoc """
  Manages job execution settings like pausing/unpausing queues.
  """

  import Ecto.Query
  alias GoodJob.{Repo, SettingSchema}

  @doc """
  Pauses job execution for a given queue or job class.
  """
  def pause(opts \\ []) do
    queue = Keyword.get(opts, :queue)
    job_class = Keyword.get(opts, :job_class)

    repo = Repo.repo()

    cond do
      queue ->
        key = "pause:queue:#{queue}"
        upsert_setting(repo, key, %{paused: true, queue: queue})

      job_class ->
        key = "pause:job_class:#{job_class}"
        upsert_setting(repo, key, %{paused: true, job_class: job_class})

      true ->
        {:error, :invalid_options}
    end
  end

  @doc """
  Unpauses job execution for a given queue or job class.
  """
  def unpause(opts \\ []) do
    queue = Keyword.get(opts, :queue)
    job_class = Keyword.get(opts, :job_class)

    repo = Repo.repo()

    cond do
      queue ->
        key = "pause:queue:#{queue}"
        delete_setting(repo, key)

      job_class ->
        key = "pause:job_class:#{job_class}"
        delete_setting(repo, key)

      true ->
        {:error, :invalid_options}
    end
  end

  @doc """
  Returns paused queue names and job class names from `good_job_settings`.

  Used by dequeue queries when `:enable_pauses` is true.
  """
  @spec list_paused_filters() :: {[String.t()], [String.t()]}
  def list_paused_filters do
    repo = Repo.repo()

    queues =
      from(s in SettingSchema,
        where: like(s.key, "pause:queue:%"),
        select: {s.key, s.value}
      )
      |> repo.all()
      |> Enum.map(&paused_queue_from_row/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    classes =
      from(s in SettingSchema,
        where: like(s.key, "pause:job_class:%"),
        select: {s.key, s.value}
      )
      |> repo.all()
      |> Enum.map(&paused_job_class_from_row/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    {queues, classes}
  end

  defp paused_queue_from_row({_key, value}) when is_map(value) do
    Map.get(value, :queue) || Map.get(value, "queue")
  end

  defp paused_queue_from_row({key, _}) when is_binary(key) do
    String.replace_prefix(key, "pause:queue:", "")
  end

  defp paused_job_class_from_row({_key, value}) when is_map(value) do
    Map.get(value, :job_class) || Map.get(value, "job_class")
  end

  defp paused_job_class_from_row({key, _}) when is_binary(key) do
    String.replace_prefix(key, "pause:job_class:", "")
  end

  @doc """
  Checks if job execution is paused.
  """
  def paused?(opts \\ []) do
    queue = Keyword.get(opts, :queue)
    job_class = Keyword.get(opts, :job_class)

    repo = Repo.repo()

    cond do
      queue ->
        key = "pause:queue:#{queue}"
        get_setting(repo, key) != nil

      job_class ->
        key = "pause:job_class:#{job_class}"
        get_setting(repo, key) != nil

      true ->
        false
    end
  end

  defp upsert_setting(repo, key, value) do
    case repo.get_by(SettingSchema, key: key) do
      nil ->
        %SettingSchema{}
        |> SettingSchema.changeset(%{key: key, value: value})
        |> repo.insert!()

      setting ->
        setting
        |> SettingSchema.changeset(%{value: value})
        |> repo.update!()
    end
  end

  defp delete_setting(repo, key) do
    case repo.get_by(SettingSchema, key: key) do
      nil -> :ok
      setting -> repo.delete!(setting)
    end
  end

  defp get_setting(repo, key) do
    repo.get_by(SettingSchema, key: key)
  end

  @doc """
  Enables a cron entry by key.
  """
  def enable_cron(cron_key) do
    repo = Repo.repo()
    key = "cron_keys_enabled"
    setting = repo.get_by(SettingSchema, key: key) || %SettingSchema{key: key, value: %{}}

    enabled_list = cron_keys_from_value(setting.value)
    cron_key_str = to_string(cron_key)

    if cron_key_str not in enabled_list do
      updated_value = [cron_key_str | enabled_list] |> Enum.uniq()
      persist_setting(repo, setting, %{keys: updated_value})
    end

    # Remove from disabled list if present
    disabled_setting = repo.get_by(SettingSchema, key: "cron_keys_disabled")

    if disabled_setting do
      disabled_list = cron_keys_from_value(disabled_setting.value)

      if cron_key_str in disabled_list do
        updated_disabled = List.delete(disabled_list, cron_key_str)
        persist_setting(repo, disabled_setting, %{keys: updated_disabled})
      end
    end

    :ok
  end

  @doc """
  Disables a cron entry by key.
  """
  def disable_cron(cron_key) do
    repo = Repo.repo()
    key = "cron_keys_disabled"
    setting = repo.get_by(SettingSchema, key: key) || %SettingSchema{key: key, value: %{}}

    disabled_list = cron_keys_from_value(setting.value)
    cron_key_str = to_string(cron_key)

    if cron_key_str not in disabled_list do
      updated_value = [cron_key_str | disabled_list] |> Enum.uniq()
      persist_setting(repo, setting, %{keys: updated_value})
    end

    # Remove from enabled list if present
    enabled_setting = repo.get_by(SettingSchema, key: "cron_keys_enabled")

    if enabled_setting do
      enabled_list = cron_keys_from_value(enabled_setting.value)

      if cron_key_str in enabled_list do
        updated_enabled = List.delete(enabled_list, cron_key_str)
        persist_setting(repo, enabled_setting, %{keys: updated_enabled})
      end
    end

    :ok
  end

  @doc """
  Checks if a cron entry is enabled.
  """
  def cron_key_enabled?(cron_key, default \\ true) do
    repo = Repo.repo()
    cron_key_str = to_string(cron_key)

    disabled_setting = repo.get_by(SettingSchema, key: "cron_keys_disabled")
    disabled_list = if disabled_setting, do: cron_keys_from_value(disabled_setting.value), else: []

    if default do
      cron_key_str not in disabled_list
    else
      enabled_setting = repo.get_by(SettingSchema, key: "cron_keys_enabled")
      enabled_list = if enabled_setting, do: cron_keys_from_value(enabled_setting.value), else: []
      cron_key_str in enabled_list
    end
  end

  @doc """
  Unpauses by setting key.
  """
  def unpause_by_key(pause_key) do
    repo = Repo.repo()
    delete_setting(repo, pause_key)
  end

  defp cron_keys_from_value(value) do
    cond do
      is_map(value) and Map.has_key?(value, :keys) -> Map.get(value, :keys) || []
      is_map(value) and Map.has_key?(value, "keys") -> Map.get(value, "keys") || []
      is_list(value) -> value
      true -> []
    end
  end

  defp persist_setting(repo, setting, value) do
    changeset = SettingSchema.changeset(setting, %{value: value})

    if setting.id do
      repo.update!(changeset)
    else
      repo.insert!(changeset)
    end
  end
end
