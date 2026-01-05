defmodule GoodJob.Protocol.Serialization do
  @moduledoc """
  Low-level serialization compatibility layer for ActiveJob format.

  This module handles conversion between ActiveJob's serialization format
  (used by Ruby GoodJob) and our internal format, enabling cross-language
  job execution. This is part of the GoodJob/ActiveJob protocol implementation.

  ## ActiveJob Serialization Format

  ActiveJob serializes jobs as a JSON object with the following structure:

      %{
        "job_class" => "MyApp::MyJob",  # String, not module
        "job_id" => "uuid",              # ActiveJob's job ID
        "queue_name" => "default",       # Queue name
        "priority" => 0,                 # Priority
        "arguments" => [...],            # Array of serialized arguments
        "executions" => 0,               # Execution count (in serialized_params)
        "locale" => "en",                # Locale (optional)
        "timezone" => "UTC",             # Timezone (optional)
        "provider_job_id" => "uuid",     # GoodJob's internal ID (added by GoodJob)
        "good_job_concurrency_key" => "...",  # Concurrency key (if present)
        "good_job_labels" => [...],      # Labels (if present)
        "good_job_notify" => true        # Notify flag (if present)
      }

  ## Usage

      # Serialize for ActiveJob compatibility
      serialized = GoodJob.Protocol.Serialization.to_active_job(
        job_class: "MyApp::MyJob",
        arguments: [1, 2, 3],
        queue_name: "default",
        priority: 0,
        executions: 0
      )

      # Deserialize from ActiveJob format
      {:ok, job_class, arguments, executions} =
        GoodJob.Protocol.Serialization.from_active_job(serialized)
  """

  @doc """
  Serializes job data in ActiveJob format.

  ## Options

    * `:job_class` - Job class name (string, e.g., "MyApp::MyJob" or "MyApp.MyJob")
    * `:arguments` - Array of job arguments
    * `:queue_name` - Queue name
    * `:priority` - Priority (default: 0)
    * `:executions` - Execution count (default: 0)
    * `:job_id` - ActiveJob job ID (optional, will be generated if not provided)
    * `:locale` - Locale (optional, default: "en")
    * `:timezone` - Timezone (optional, default: "UTC")
    * `:concurrency_key` - Concurrency key (optional)
    * `:labels` - Labels array (optional)
    * `:notify` - Notify flag (optional)

  ## Examples

      GoodJob.Protocol.Serialization.to_active_job(
        job_class: "MyApp::MyJob",
        arguments: [%{id: 1}, "hello"],
        queue_name: "default"
      )
  """
  @spec to_active_job(keyword()) :: map()
  def to_active_job(opts) do
    job_class = Keyword.fetch!(opts, :job_class)
    arguments = Keyword.fetch!(opts, :arguments)
    queue_name = Keyword.fetch!(opts, :queue_name)
    priority = Keyword.get(opts, :priority, 0)
    executions = Keyword.get(opts, :executions, 0)
    job_id = Keyword.get(opts, :job_id) || Ecto.UUID.generate()
    locale = Keyword.get(opts, :locale, "en")
    timezone = Keyword.get(opts, :timezone, "UTC")
    concurrency_key = Keyword.get(opts, :concurrency_key)
    labels = Keyword.get(opts, :labels)
    notify = Keyword.get(opts, :notify)

    serialized = %{
      "job_class" => to_string(job_class),
      "job_id" => to_string(job_id),
      "queue_name" => to_string(queue_name),
      "priority" => priority,
      "arguments" => serialize_arguments(arguments),
      "executions" => executions,
      "locale" => locale,
      "timezone" => timezone
    }

    serialized =
      if concurrency_key do
        Map.put(serialized, "good_job_concurrency_key", to_string(concurrency_key))
      else
        serialized
      end

    serialized =
      if labels && not Enum.empty?(labels) do
        Map.put(serialized, "good_job_labels", Enum.map(labels, &to_string/1))
      else
        serialized
      end

    serialized =
      if is_nil(notify) do
        serialized
      else
        Map.put(serialized, "good_job_notify", notify)
      end

    serialized
  end

  @doc """
  Deserializes ActiveJob format and extracts key fields.

  Returns `{:ok, job_class, arguments, executions, metadata}` where:
    * `job_class` - Job class name (string)
    * `arguments` - Array of deserialized arguments
    * `executions` - Execution count
    * `metadata` - Map with additional fields (queue_name, priority, etc.)

  ## Examples

      {:ok, "MyApp::MyJob", [1, 2, 3], 0, %{queue_name: "default"}} =
        GoodJob.Protocol.Serialization.from_active_job(serialized_params)
  """
  @spec from_active_job(map()) ::
          {:ok, String.t(), list(), non_neg_integer(), map()} | {:error, term()}
  def from_active_job(serialized_params) when is_map(serialized_params) do
    job_class = Map.get(serialized_params, "job_class") || Map.get(serialized_params, :job_class)
    arguments = Map.get(serialized_params, "arguments", [])
    executions = Map.get(serialized_params, "executions", 0) || 0
    queue_name = Map.get(serialized_params, "queue_name")
    priority = Map.get(serialized_params, "priority", 0)
    concurrency_key = Map.get(serialized_params, "good_job_concurrency_key")
    labels = Map.get(serialized_params, "good_job_labels")
    notify = Map.get(serialized_params, "good_job_notify")

    if is_nil(job_class) do
      {:error, "Missing 'job_class' in serialized_params"}
    else
      metadata = %{
        queue_name: queue_name,
        priority: priority,
        concurrency_key: concurrency_key,
        labels: labels,
        notify: notify
      }

      {:ok, to_string(job_class), deserialize_arguments(arguments), executions, metadata}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def from_active_job(_), do: {:error, "serialized_params must be a map"}

  @doc """
  Updates the executions count in serialized_params.

  This is needed because ActiveJob stores executions in serialized_params,
  not just in the executions_count column.
  """
  @spec update_executions(map(), non_neg_integer()) :: map()
  def update_executions(serialized_params, executions) when is_map(serialized_params) do
    Map.put(serialized_params, "executions", executions)
  end

  @doc """
  Converts Elixir module name to external class name format.

  ## Examples

      GoodJob.Protocol.Serialization.module_to_external_class(MyApp.MyJob)
      # => "MyApp::MyJob"

      GoodJob.Protocol.Serialization.module_to_external_class("MyApp.MyJob")
      # => "MyApp::MyJob"
  """
  @spec module_to_external_class(module() | String.t()) :: String.t()
  def module_to_external_class(module) when is_atom(module) do
    str = Atom.to_string(module)
    str = if String.starts_with?(str, "Elixir."), do: String.slice(str, 7..-1//1), else: str
    String.replace(str, ".", "::")
  end

  def module_to_external_class(module) when is_binary(module) do
    String.replace(module, ".", "::")
  end

  @doc """
  Converts external class name to Elixir module name format.

  ## Examples

      GoodJob.Protocol.Serialization.external_class_to_module("MyApp::MyJob")
      # => "MyApp.MyJob"
  """
  @spec external_class_to_module(String.t()) :: String.t()
  def external_class_to_module(external_class) when is_binary(external_class) do
    String.replace(external_class, "::", ".")
  end

  # Private functions

  defp serialize_arguments(arguments) when is_list(arguments) do
    Enum.map(arguments, &serialize_argument/1)
  end

  defp serialize_arguments(arguments) do
    # If arguments is not a list (e.g., a map), wrap it in an array
    # ActiveJob format always uses an array for arguments
    [serialize_argument(arguments)]
  end

  defp serialize_argument(arg) when is_atom(arg) do
    # ActiveJob uses SymbolSerializer for symbols
    %{"_aj_serialized" => "ActiveJob::Serializers::SymbolSerializer", "value" => to_string(arg)}
  end

  defp serialize_argument(arg) when is_binary(arg), do: arg
  defp serialize_argument(arg) when is_number(arg), do: arg
  defp serialize_argument(arg) when is_boolean(arg), do: arg
  defp serialize_argument(arg) when is_nil(arg), do: nil

  # Handle Date structs - use ActiveJob DateSerializer format
  defp serialize_argument(%Date{} = date) do
    %{"_aj_serialized" => "ActiveJob::Serializers::DateSerializer", "value" => Date.to_iso8601(date)}
  end

  # Handle DateTime structs - use ActiveJob DateTimeSerializer format
  defp serialize_argument(%DateTime{} = dt) do
    %{"_aj_serialized" => "ActiveJob::Serializers::DateTimeSerializer", "value" => DateTime.to_iso8601(dt)}
  end

  # Handle NaiveDateTime structs - convert to DateTime format
  defp serialize_argument(%NaiveDateTime{} = dt) do
    # Convert NaiveDateTime to DateTime (assume UTC)
    dt_with_zone = DateTime.from_naive!(dt, "Etc/UTC")
    %{"_aj_serialized" => "ActiveJob::Serializers::DateTimeSerializer", "value" => DateTime.to_iso8601(dt_with_zone)}
  end

  defp serialize_argument(arg) when is_map(arg) do
    # For maps, serialize keys as strings (JSON-compatible)
    # Check if it's a struct first (structs are maps but have __struct__ key)
    case Map.get(arg, :__struct__) do
      nil ->
        # Regular map, serialize recursively
        serialized =
          Enum.into(arg, %{}, fn
            {k, v} when is_atom(k) -> {to_string(k), serialize_argument(v)}
            {k, v} -> {k, serialize_argument(v)}
          end)

        # Add _aj_ruby2_keywords marker for ActiveJob keyword arguments
        # This tells Rails to treat the hash as keyword arguments when deserializing
        # Extract all string keys that were originally atoms (keyword arguments)
        keyword_keys =
          arg
          |> Map.keys()
          |> Enum.filter(&is_atom/1)
          |> Enum.map(&to_string/1)

        if keyword_keys != [] do
          Map.put(serialized, "_aj_ruby2_keywords", keyword_keys)
        else
          serialized
        end

      _struct ->
        # It's a struct but not one we handle above, convert to string
        inspect(arg)
    end
  end

  defp serialize_argument(arg) when is_list(arg) do
    Enum.map(arg, &serialize_argument/1)
  end

  defp serialize_argument(arg) do
    # For other types (tuples, etc.), convert to string representation
    # In production, you might want to use GlobalID or similar
    inspect(arg)
  end

  defp deserialize_arguments(arguments) when is_list(arguments) do
    Enum.map(arguments, &deserialize_argument/1)
  end

  defp deserialize_arguments(arguments), do: arguments

  defp deserialize_argument(arg) when is_binary(arg) do
    # Try to detect if it's a serialized atom
    case String.starts_with?(arg, ":") do
      true -> String.slice(arg, 1..-1//1) |> String.to_atom()
      false -> arg
    end
  end

  defp deserialize_argument(arg) when is_number(arg), do: arg
  defp deserialize_argument(arg) when is_boolean(arg), do: arg
  defp deserialize_argument(arg) when is_nil(arg), do: nil

  defp deserialize_argument(arg) when is_map(arg) do
    # Check if this is an ActiveJob serialized object (e.g., Date, DateTime, etc.)
    case Map.get(arg, "_aj_serialized") do
      nil ->
        # Regular map, convert string keys to atoms where appropriate
        # Strip out _aj_ruby2_keywords marker (Rails-specific, not needed in Elixir)
        arg
        |> Enum.reject(fn {k, _v} -> k == "_aj_ruby2_keywords" end)
        |> Enum.into(%{}, fn
          {k, v} when is_binary(k) ->
            # Try to convert to atom if it looks like one
            atom_key = try_convert_to_atom(k)
            {atom_key, deserialize_argument(v)}

          {k, v} ->
            {k, deserialize_argument(v)}
        end)

      serializer_name ->
        # This is an ActiveJob serialized object, deserialize it
        deserialize_aj_object(arg, serializer_name)
    end
  end

  defp deserialize_argument(arg) when is_list(arg) do
    Enum.map(arg, &deserialize_argument/1)
  end

  defp deserialize_argument(arg), do: arg

  defp try_convert_to_atom(string) do
    # Only convert if it looks like a valid atom (alphanumeric + underscore)
    if String.match?(string, ~r/^[a-z_][a-z0-9_]*$/i) do
      try do
        String.to_existing_atom(string)
      rescue
        ArgumentError -> string
      end
    else
      string
    end
  end

  # Deserializes ActiveJob serialized objects (Date, DateTime, Time, Symbol, etc.)
  defp deserialize_aj_object(arg, serializer_name) do
    value = Map.get(arg, "value")

    case serializer_name do
      "ActiveJob::Serializers::DateSerializer" ->
        # Date is serialized as ISO8601 string: "2026-01-05"
        if is_binary(value) do
          case Date.from_iso8601(value) do
            {:ok, date} -> date
            {:error, _} -> value
          end
        else
          value
        end

      "ActiveJob::Serializers::DateTimeSerializer" ->
        # DateTime is serialized as ISO8601 string
        if is_binary(value) do
          case DateTime.from_iso8601(value) do
            {:ok, dt, _} -> dt
            {:error, _} -> value
          end
        else
          value
        end

      "ActiveJob::Serializers::TimeSerializer" ->
        # Time is serialized as ISO8601 string
        if is_binary(value) do
          case DateTime.from_iso8601(value) do
            {:ok, dt, _} -> dt
            {:error, _} -> value
          end
        else
          value
        end

      "ActiveJob::Serializers::TimeWithZoneSerializer" ->
        # TimeWithZone is serialized as ISO8601 string with time_zone
        if is_binary(value) do
          case DateTime.from_iso8601(value) do
            {:ok, dt, _} ->
              # Elixir DateTime doesn't have time zones like Rails TimeWithZone
              # We return DateTime with the timezone info if available
              time_zone = Map.get(arg, "time_zone")

              if time_zone do
                # Try to set timezone (though Elixir DateTime doesn't support this natively)
                # For now, just return the DateTime
                dt
              else
                dt
              end

            {:error, _} ->
              value
          end
        else
          value
        end

      "ActiveJob::Serializers::SymbolSerializer" ->
        # Symbol is serialized as string, convert back to atom
        if is_binary(value) do
          try do
            String.to_existing_atom(value)
          rescue
            ArgumentError ->
              # Atom doesn't exist, create it (safe for job arguments)
              String.to_atom(value)
          end
        else
          value
        end

      "ActiveJob::Serializers::BigDecimalSerializer" ->
        # BigDecimal is serialized as string
        # Try to use Decimal if available, otherwise return as string or float
        if is_binary(value) do
          case Code.ensure_loaded(Decimal) do
            {:module, Decimal} ->
              case Decimal.parse(value) do
                {%Decimal{} = decimal, _} -> decimal
                _ -> value
              end

            {:error, _} ->
              # Decimal not available, try to convert to float
              case Float.parse(value) do
                {float, _} -> float
                :error -> value
              end
          end
        else
          value
        end

      "ActiveJob::Serializers::DurationSerializer" ->
        # Duration is serialized as value and parts
        # Elixir doesn't have ActiveSupport::Duration, so we return a map representation
        parts = Map.get(arg, "parts", [])
        %{value: value, parts: deserialize_arguments(parts)}

      "ActiveJob::Serializers::RangeSerializer" ->
        # Range is serialized as begin, end, exclude_end
        begin_val = deserialize_argument(Map.get(arg, "begin"))
        end_val = deserialize_argument(Map.get(arg, "end"))
        exclude_end = Map.get(arg, "exclude_end", false)

        # Elixir doesn't have Range like Ruby, so we return a map representation
        %{begin: begin_val, end: end_val, exclude_end: exclude_end}

      "ActiveJob::Serializers::ModuleSerializer" ->
        # Module is serialized as string name
        if is_binary(value) do
          # Try to resolve the module
          module_string = "Elixir.#{value}"

          try do
            String.to_existing_atom(module_string)
            |> Code.ensure_loaded()
            |> case do
              {:module, module} -> module
              _ -> value
            end
          rescue
            _ -> value
          end
        else
          value
        end

      _ ->
        # Unknown serializer, return the value as-is
        value
    end
  end
end
