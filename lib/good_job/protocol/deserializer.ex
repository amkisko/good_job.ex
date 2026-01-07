defmodule GoodJob.Protocol.Deserializer do
  @moduledoc """
  Deserializes jobs from ActiveJob format for execution.

  This is part of the GoodJob/ActiveJob protocol implementation for cross-language
  job execution. Handles reading jobs from the database and preparing them for execution.
  """

  @doc """
  Deserializes the job module from job_class and serialized_params.
  """
  def deserialize_job_module(job_class, serialized_params) when is_binary(job_class) do
    case GoodJob.Protocol.Serialization.from_active_job(serialized_params) do
      {:ok, active_job_class, _args, _executions, _metadata} ->
        resolve_job_module(active_job_class)

      {:error, _} ->
        resolve_job_module(job_class)
    end
  end

  @doc """
  Deserializes arguments from serialized_params.
  """
  def deserialize_args(serialized_params) when is_map(serialized_params) do
    case GoodJob.Protocol.Serialization.from_active_job(serialized_params) do
      {:ok, _job_class, arguments, _executions, _metadata} ->
        arguments

      {:error, _} ->
        Map.get(serialized_params, "arguments", [])
    end
  end

  def deserialize_args(nil), do: []

  @doc """
  Normalizes arguments to be Elixir-friendly.
  Converts ActiveJob keyword arguments to maps for better Elixir ergonomics.
  """
  def normalize_args_for_elixir(_module, args, _job) do
    case args do
      [single_map] when is_map(single_map) ->
        cond do
          Map.has_key?(single_map, "_aj_symbol_keys") or
              Map.has_key?(single_map, "_aj_ruby2_keywords") ->
            extract_keyword_args_from_map(single_map)

          Map.has_key?(single_map, "_aj_hash_with_indifferent_access") ->
            extract_keyword_args_from_map(single_map)

          true ->
            normalize_map_keys(single_map)
        end

      list when is_list(list) and list != [] ->
        if Enum.all?(list, &is_map/1) do
          merged = Enum.reduce(list, %{}, fn map, acc -> Map.merge(acc, map) end)
          extract_keyword_args_from_map(merged)
        else
          list
        end

      map when is_map(map) ->
        normalize_map_keys(map)

      other ->
        other
    end
  end

  # Private functions

  defp extract_keyword_args_from_map(map) do
    symbol_keys =
      cond do
        Map.has_key?(map, "_aj_symbol_keys") ->
          Map.get(map, "_aj_symbol_keys", [])

        Map.has_key?(map, "_aj_ruby2_keywords") ->
          Map.get(map, "_aj_ruby2_keywords", [])

        true ->
          []
      end

    cleaned =
      map
      |> Map.delete("_aj_symbol_keys")
      |> Map.delete("_aj_ruby2_keywords")
      |> Map.delete("_aj_hash_with_indifferent_access")
      # Note: _aj_globalid is handled in Serialization.deserialize_argument, not deleted here
      |> Map.delete("_aj_serialized")

    Enum.into(cleaned, %{}, fn
      {k, v} when is_binary(k) ->
        key =
          if k in symbol_keys do
            try do
              String.to_existing_atom(k)
            rescue
              ArgumentError ->
                k
            end
          else
            try_convert_key_to_atom(k)
          end

        {key, normalize_value(v)}

      {k, v} ->
        {k, normalize_value(v)}
    end)
  end

  defp normalize_map_keys(map) when is_map(map) do
    # Check if it's a struct (structs have __struct__ key and shouldn't be normalized)
    case Map.get(map, :__struct__) do
      nil ->
        # Regular map, normalize keys
        Enum.into(map, %{}, fn
          {k, v} when is_binary(k) ->
            atom_key = try_convert_key_to_atom(k)
            {atom_key, normalize_value(v)}

          {k, v} ->
            {k, normalize_value(v)}
        end)

      _struct ->
        map
    end
  end

  defp normalize_value(v) when is_map(v) do
    if map_size(v) == 1 && Map.has_key?(v, "_aj_globalid") do
      gid_string = Map.get(v, "_aj_globalid")

      case parse_global_id_string(gid_string) do
        {:ok, %{app: app, model: model, id: id}} ->
          %{
            __struct__: :global_id,
            app: app,
            model: model,
            id: id,
            gid: gid_string
          }

        {:error, _} ->
          normalize_map_keys(v)
      end
    else
      normalize_map_keys(v)
    end
  end

  defp normalize_value(v), do: v

  defp parse_global_id_string("gid://" <> rest) do
    case String.split(rest, "/") do
      [app, model, id] ->
        {:ok, %{app: app, model: model, id: id}}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_global_id_string(_), do: {:error, :invalid_format}

  defp try_convert_key_to_atom(string) when is_binary(string) do
    cond do
      String.match?(string, ~r/^[a-z_][a-z0-9_]*$/i) and not String.starts_with?(string, "_aj_") ->
        String.to_existing_atom(string)

      true ->
        string
    end
  rescue
    ArgumentError ->
      string
  end

  defp resolve_job_module(job_class_string) when is_binary(job_class_string) do
    # First, check explicit configuration mapping (for cross-language jobs from external languages)
    mappings = GoodJob.Config.external_jobs()

    case Map.get(mappings, job_class_string) do
      nil ->
        # Not in config mapping, try automatic resolution (works for Elixir-native jobs)
        resolve_job_module_automatic(job_class_string)

      module when is_atom(module) ->
        # Found in config mapping, verify module exists
        case Code.ensure_loaded(module) do
          {:module, ^module} ->
            module

          {:error, reason} ->
            raise "Job module configured in external_jobs not found: #{inspect(module)} " <>
                    "for external class #{job_class_string}. Error: #{inspect(reason)}"
        end
    end
  end

  defp resolve_job_module_automatic(job_class_string) do
    # For Elixir-native jobs, try direct module name resolution first
    # This handles cases where job_class is "MyApp.MyJob" or "Elixir.MyApp.MyJob"
    atom_string =
      if String.starts_with?(job_class_string, "Elixir."),
        do: job_class_string,
        else: "Elixir.#{job_class_string}"

    case try_load_module(atom_string) do
      {:ok, module} ->
        module

      {:error, _} ->
        # Not a direct Elixir module match, try protocol fallbacks
        resolve_job_module_protocol(job_class_string)
    end
  end

  defp resolve_job_module_protocol(job_class_string) do
    # Protocol fallbacks (for external jobs not in external_jobs)
    # Try converting Ruby format to Elixir format
    elixir_module_string = GoodJob.Protocol.Serialization.external_class_to_module(job_class_string)

    # Try loading the converted module name
    atom_string =
      if String.starts_with?(elixir_module_string, "Elixir."),
        do: elixir_module_string,
        else: "Elixir.#{elixir_module_string}"

    case try_load_module(atom_string) do
      {:ok, module} ->
        module

      {:error, _} ->
        # If job_class_string already looks like an Elixir module name
        # (starts with "Elixir."), allow it to fall through so that later
        # checks (in perform_job/3) can raise a consistent
        # "does not implement perform/1" error. This is used by
        # JobExecutor tests that build jobs with an explicit Elixir module
        # string like "Elixir.NonExistentModule".
        if String.starts_with?(job_class_string, "Elixir.") do
          String.to_atom(atom_string)
        else
          # For true unknown Rails/Elixir jobs (e.g. "Rails::UnknownJob" or
          # "NonExistent.Module.Job"), raise a helpful error message as
          # expected by the deserializer tests.
          raise "Job module not found: #{job_class_string}. " <>
                  "For external jobs, configure it in external_jobs. " <>
                  "For Elixir jobs, ensure the module name matches the job_class."
        end
    end
  end

  defp try_load_module(atom_string) do
    atom = String.to_existing_atom(atom_string)

    case Code.ensure_loaded(atom) do
      {:module, module} -> {:ok, module}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end
end
