#!/usr/bin/env elixir

Mix.install([])

defmodule Analyze do
  @moduledoc """
  Analyzes library structure and lints for code quality issues.
  """

  @max_file_size_kb 20
  @max_file_lines 500
  @max_module_lines 300

  def run(root_dir \\ ".") do
    output_file = Path.join(root_dir, "tmp/analyze.log")
    File.mkdir_p!(Path.dirname(output_file))

    lib_files = find_lib_files(root_dir)
    test_files = find_test_files(root_dir)
    example_files = find_example_files(root_dir)
    migration_files = find_migration_files(root_dir)

    lib_analysis = analyze_files(lib_files, root_dir)
    test_analysis = analyze_files(test_files, root_dir)
    example_analysis = analyze_files(example_files, root_dir)
    migration_analysis = analyze_files(migration_files, root_dir)

    total_lib = calculate_totals(lib_analysis)
    total_test = calculate_totals(test_analysis)
    total_example = calculate_totals(example_analysis)
    total_migration = calculate_totals(migration_analysis)

    issues = []
    issues = issues ++ check_file_sizes(lib_analysis, "Library")
    issues = issues ++ check_file_sizes(test_analysis, "Test")
    issues = issues ++ check_file_sizes(example_analysis, "Example")
    issues = issues ++ check_file_sizes(migration_analysis, "Migration")
    issues = issues ++ check_todos(lib_analysis, "Library")
    issues = issues ++ check_todos(test_analysis, "Test")
    issues = issues ++ check_todos(example_analysis, "Example")
    issues = issues ++ check_todos(migration_analysis, "Migration")
    issues = issues ++ check_garbage(lib_analysis, "Library")
    issues = issues ++ check_garbage(test_analysis, "Test")
    issues = issues ++ check_garbage(example_analysis, "Example")
    issues = issues ++ check_garbage(migration_analysis, "Migration")

    output = format_report(lib_analysis, test_analysis, example_analysis, migration_analysis, total_lib, total_test, total_example, total_migration, issues)

    File.write!(output_file, output)

    if Enum.empty?(issues) do
      IO.puts("✓ Analysis complete - no issues found")
      IO.puts("Report written to #{output_file}")
      System.halt(0)
    else
      IO.puts("✗ Analysis found #{length(issues)} issue(s):")
      IO.puts("")
      Enum.each(issues, fn issue -> IO.puts("  #{issue}") end)
      IO.puts("")
      IO.puts("Report written to #{output_file}")
      System.halt(1)
    end
  end

  defp find_lib_files(root_dir) do
    lib_dir = Path.join(root_dir, "lib")
    find_elixir_files(lib_dir)
  end

  defp find_test_files(root_dir) do
    test_dir = Path.join(root_dir, "test")
    find_elixir_files(test_dir)
  end

  defp find_example_files(root_dir) do
    example_dir = Path.join(root_dir, "examples")
    find_elixir_files(example_dir)
  end

  defp find_migration_files(root_dir) do
    migration_dir = Path.join(root_dir, "priv/migrations")
    find_elixir_files(migration_dir)
  end

  defp find_elixir_files(dir) do
    if File.exists?(dir) do
      ex_files = dir
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.reject(&String.contains?(&1, "/_build/"))
        |> Enum.reject(&String.contains?(&1, "/deps/"))

      exs_files = dir
        |> Path.join("**/*.exs")
        |> Path.wildcard()
        |> Enum.reject(&String.contains?(&1, "/_build/"))
        |> Enum.reject(&String.contains?(&1, "/deps/"))

      (ex_files ++ exs_files)
        |> Enum.sort()
    else
      []
    end
  end

  defp analyze_files(files, root_dir) do
    files
    |> Enum.map(fn file ->
      content = File.read!(file)
      lines = String.split(content, "\n") |> length()
      size = byte_size(content)

      # Get relative path from project root
      relative_path = if String.starts_with?(file, root_dir) do
        String.slice(file, String.length(root_dir) + 1..-1)
      else
        file
      end

      %{
        path: file,
        relative_path: relative_path,
        lines: lines,
        size: size,
        size_kb: Float.round(size / 1024, 2),
        content: content
      }
    end)
  end

  defp calculate_totals(analysis) do
    total_size = Enum.sum(Enum.map(analysis, & &1.size))
    %{
      file_count: length(analysis),
      total_lines: Enum.sum(Enum.map(analysis, & &1.lines)),
      total_size: total_size,
      total_size_kb: Float.round(total_size / 1024, 2)
    }
  end

  defp check_file_sizes(analysis, category) do
    issues = []

    issues = issues ++
      Enum.flat_map(analysis, fn file ->
        if file.size_kb > @max_file_size_kb do
          ["ERROR: #{category} file #{file.relative_path} exceeds size limit (#{file.size_kb} KB > #{@max_file_size_kb} KB)"]
        else
          []
        end
      end)

    issues = issues ++
      Enum.flat_map(analysis, fn file ->
        if file.lines > @max_file_lines do
          ["ERROR: #{category} file #{file.relative_path} exceeds line limit (#{file.lines} lines > #{@max_file_lines} lines)"]
        else
          []
        end
      end)

    issues = issues ++
      Enum.flat_map(analysis, fn file ->
        if file.lines > @max_module_lines do
          ["WARNING: #{category} file #{file.relative_path} exceeds recommended module size (#{file.lines} lines > #{@max_module_lines} lines)"]
        else
          []
        end
      end)

    issues
  end

  defp check_todos(analysis, category) do
    todo_patterns = [
      {~r/\bTODO\b/i, "TODO"},
      {~r/\bFIXME\b/i, "FIXME"},
      {~r/\bXXX\b/i, "XXX"},
      {~r/\bHACK\b/i, "HACK"},
      {~r/\bNOTE\b/i, "NOTE"},
      {~r/\bBUG\b/i, "BUG"},
      {~r/\bOPTIMIZE\b/i, "OPTIMIZE"},
      {~r/\bREFACTOR\b/i, "REFACTOR"}
    ]

    Enum.flat_map(analysis, fn file ->
      lines = String.split(file.content, "\n")

      lines
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, line_num} ->
        Enum.flat_map(todo_patterns, fn {pattern, name} ->
          if Regex.match?(pattern, line) do
            ["WARNING: #{category} file #{file.relative_path}:#{line_num} contains #{name} comment"]
          else
            []
          end
        end)
      end)
    end)
  end

  defp check_garbage(analysis, category) do
    Enum.flat_map(analysis, fn file ->
      lines = String.split(file.content, "\n")

      garbage_patterns = [
        {~r/IO\.puts.*debug/i, "Debug IO.puts"},
        {~r/IO\.inspect\(/i, "IO.inspect (debug code)"},
        {~r/Logger\.debug/i, "Logger.debug"},
        {~r/^\s*#.*\b(pry|binding|debugger|byebug)\b/i, "Debugger comment"},
        {~r/^\s*#.*\b(remove|delete|cleanup|garbage|unused|deprecated)\b/i, "Cleanup comment"},
        {~r/^\s*#.*\b(temporary|temp|tmp|hack|workaround)\b/i, "Temporary code comment"}
      ]

      lines
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, line_num} ->
        Enum.flat_map(garbage_patterns, fn {pattern, description} ->
          if Regex.match?(pattern, line) do
            ["WARNING: #{category} file #{file.relative_path}:#{line_num} contains #{description}"]
          else
            []
          end
        end)
      end)
    end)
  end

  defp format_report(lib_analysis, test_analysis, example_analysis, migration_analysis, total_lib, total_test, total_example, total_migration, issues) do
    lib_by_size = Enum.sort_by(lib_analysis, & &1.size, :desc)
    lib_by_lines = Enum.sort_by(lib_analysis, & &1.lines, :desc)
    test_by_size = Enum.sort_by(test_analysis, & &1.size, :desc)
    test_by_lines = Enum.sort_by(test_analysis, & &1.lines, :desc)
    example_by_size = Enum.sort_by(example_analysis, & &1.size, :desc)
    example_by_lines = Enum.sort_by(example_analysis, & &1.lines, :desc)
    migration_by_size = Enum.sort_by(migration_analysis, & &1.size, :desc)
    migration_by_lines = Enum.sort_by(migration_analysis, & &1.lines, :desc)

    """
    ================================================================================
    GoodJob Library Structure Analysis
    ================================================================================
    Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    ================================================================================
    SUMMARY
    ================================================================================

    Library Files:
      Total files: #{total_lib.file_count}
      Total lines: #{total_lib.total_lines}
      Total size: #{total_lib.total_size_kb} KB (#{format_bytes(total_lib.total_size)})

    Test Files:
      Total files: #{total_test.file_count}
      Total lines: #{total_test.total_lines}
      Total size: #{total_test.total_size_kb} KB (#{format_bytes(total_test.total_size)})

    Example Files:
      Total files: #{total_example.file_count}
      Total lines: #{total_example.total_lines}
      Total size: #{total_example.total_size_kb} KB (#{format_bytes(total_example.total_size)})

    Migration Files:
      Total files: #{total_migration.file_count}
      Total lines: #{total_migration.total_lines}
      Total size: #{total_migration.total_size_kb} KB (#{format_bytes(total_migration.total_size)})

    Grand Total:
      Total files: #{total_lib.file_count + total_test.file_count + total_example.file_count + total_migration.file_count}
      Total lines: #{total_lib.total_lines + total_test.total_lines + total_example.total_lines + total_migration.total_lines}
      Total size: #{Float.round(total_lib.total_size_kb + total_test.total_size_kb + total_example.total_size_kb + total_migration.total_size_kb, 2)} KB (#{format_bytes(total_lib.total_size + total_test.total_size + total_example.total_size + total_migration.total_size)})

    ================================================================================
    ISSUES FOUND
    ================================================================================

    #{if Enum.empty?(issues) do
      "No issues found."
    else
      Enum.map(issues, fn issue -> "  #{issue}" end) |> Enum.join("\n")
    end}

    ================================================================================
    LIBRARY FILES - SORTED BY SIZE (LARGEST FIRST)
    ================================================================================

    #{format_file_list(lib_by_size, :size)}

    ================================================================================
    LIBRARY FILES - SORTED BY LINES (LARGEST FIRST)
    ================================================================================

    #{format_file_list(lib_by_lines, :lines)}

    ================================================================================
    TEST FILES - SORTED BY SIZE (LARGEST FIRST)
    ================================================================================

    #{format_file_list(test_by_size, :size)}

    ================================================================================
    TEST FILES - SORTED BY LINES (LARGEST FIRST)
    ================================================================================

    #{format_file_list(test_by_lines, :lines)}

    ================================================================================
    EXAMPLE FILES - SORTED BY SIZE (LARGEST FIRST)
    ================================================================================

    #{format_file_list(example_by_size, :size)}

    ================================================================================
    EXAMPLE FILES - SORTED BY LINES (LARGEST FIRST)
    ================================================================================

    #{format_file_list(example_by_lines, :lines)}

    ================================================================================
    MIGRATION FILES - SORTED BY SIZE (LARGEST FIRST)
    ================================================================================

    #{format_file_list(migration_by_size, :size)}

    ================================================================================
    MIGRATION FILES - SORTED BY LINES (LARGEST FIRST)
    ================================================================================

    #{format_file_list(migration_by_lines, :lines)}

    ================================================================================
    LIBRARY FILES - BY MODULE STRUCTURE
    ================================================================================

    #{format_by_module_structure(lib_analysis)}

    ================================================================================
    END OF REPORT
    ================================================================================
    """
  end

  defp format_file_list(files, sort_by) do
    files
    |> Enum.with_index(1)
    |> Enum.map(fn {file, index} ->
      value = if sort_by == :size, do: "#{file.size_kb} KB", else: "#{file.lines} lines"
      "#{String.pad_leading(to_string(index), 3, " ")}. #{String.pad_trailing(file.relative_path, 60)} | #{String.pad_leading(value, 12)} | #{file.lines} lines | #{format_bytes(file.size)}"
    end)
    |> Enum.join("\n")
  end

  defp format_by_module_structure(analysis) do
    analysis
    |> Enum.group_by(fn file ->
      parts = String.split(file.relative_path, "/")
      if length(parts) > 1 do
        List.first(parts)
      else
        "root"
      end
    end)
    |> Enum.map(fn {module, files} ->
      total_lines = Enum.sum(Enum.map(files, & &1.lines))
      total_size = Enum.sum(Enum.map(files, & &1.size))
      %{module: module, file_count: length(files), total_lines: total_lines, total_size: total_size}
    end)
    |> Enum.sort_by(& &1.total_size, :desc)
    |> Enum.map(fn %{module: module, file_count: file_count, total_lines: total_lines, total_size: total_size} ->
      "#{String.pad_trailing(module, 30)} | #{String.pad_leading(to_string(file_count), 3)} files | #{String.pad_leading(to_string(total_lines), 6)} lines | #{format_bytes(total_size)}"
    end)
    |> Enum.join("\n")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 2)} MB"
end

root_dir = if System.argv() != [], do: List.first(System.argv()), else: "."

Analyze.run(root_dir)
