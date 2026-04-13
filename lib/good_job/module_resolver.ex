defmodule GoodJob.ModuleResolver do
  @moduledoc false

  @doc """
  Resolves a module name string to a loaded module.

  Strips a leading `"Elixir."` segment before `Module.safe_concat/1`, matching how
  `Atom.to_string(MyApp.Foo)` is represented. Path segments use `String.to_existing_atom/1`
  so only atoms that already exist in the VM are created.
  """
  @spec resolve(String.t()) :: {:ok, module()} | {:error, :invalid | :not_loaded}
  def resolve(str) when is_binary(str) do
    str = String.trim(str)

    if str == "" do
      {:error, :invalid}
    else
      resolve_path(str)
    end
  end

  defp resolve_path(str) do
    parts = String.split(str, ".")

    parts =
      case parts do
        ["Elixir" | rest] when rest != [] -> rest
        _ -> parts
      end

    if parts == [] do
      {:error, :invalid}
    else
      with {:ok, atoms} <- safe_atom_segments(parts) do
        safe_concat_module(atoms)
      end
    end
  end

  defp safe_concat_module(atoms) do
    module = Module.safe_concat(atoms)
    ensure_module(module)
  rescue
    ArgumentError -> {:error, :invalid}
  end

  defp safe_atom_segments(parts) do
    {:ok, Enum.map(parts, &String.to_existing_atom/1)}
  rescue
    ArgumentError -> {:error, :invalid}
  end

  defp ensure_module(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, _} -> {:ok, module}
      {:error, _} -> {:error, :not_loaded}
    end
  end
end
