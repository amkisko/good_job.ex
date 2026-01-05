defmodule MonorepoExampleWeb.Components.JobsPage do
  @moduledoc """
  Phlex component for the jobs page wrapper with flash messages.
  """
  use MonorepoExampleWeb.Components.Base

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    flash = Map.get(original_assigns, :flash, %{})

    div(state, [
      class: "min-h-screen p-4 sm:p-5",
      style: "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;"
    ], fn state ->
      state
      |> div([class: "max-w-6xl mx-auto w-full"], fn state ->
        state
        |> render_flash_messages(flash)
        |> render_jobs_component(assigns)
      end)
    end)
  end

  defp render_flash_messages(state, flash) do
    info_msg = Phoenix.Flash.get(flash, :info)
    error_msg = Phoenix.Flash.get(flash, :error)

    state
    |> render_if(info_msg, fn state ->
      div(state, [
        class: "bg-green-100 text-green-800 p-4 rounded-lg mb-4 border border-green-300"
      ], info_msg)
    end)
    |> render_if(error_msg, fn state ->
      div(state, [
        class: "bg-red-100 text-red-800 p-4 rounded-lg mb-4 border border-red-300"
      ], error_msg)
    end)
  end

  defp render_jobs_component(state, assigns) do
    # Render the Jobs component and inject the HTML string into state
    # Phlex components return a string (HTML), so we use unsafe_raw to inject it
    jobs_html = MonorepoExampleWeb.Components.Jobs.render(assigns)
    Phlex.SGML.unsafe_raw(state, jobs_html)
  end

  defp render_if(state, condition, _fun) when condition in [nil, false], do: state
  defp render_if(state, _condition, fun), do: fun.(state)
end
