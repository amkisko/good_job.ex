defmodule MonorepoExampleWeb.Components.RootLayout do
  @moduledoc """
  Root layout component using Phlex.
  """
  use MonorepoExampleWeb.Components.Base

  def render(assigns) do
    inner_content = normalize_content(Map.get(assigns, :inner_content, ""))
    csrf_token = Map.get(assigns, :csrf_token, "")

    super(%{
      inner_content: inner_content,
      csrf_token: csrf_token
    })
  end

  defp render_template(assigns, _attrs, state) do
    inner_content = Map.get(assigns, :inner_content, "")
    csrf_token = Map.get(assigns, :csrf_token, "")

    state
    |> doctype()
    |> html([lang: "en"], fn state ->
      state
      |> head([], fn state ->
        state
        |> meta([charset: "utf-8"])
        |> meta([name: "viewport", content: "width=device-width, initial-scale=1"])
        |> meta([name: "csrf-token", content: csrf_token])
        |> title([], "Monorepo Example - GoodJob")
        |> link([rel: "stylesheet", href: "/assets/css/app.css", phx_track_static: true])
      end)
      |> body([class: "text-gray-900"], fn state ->
        Phlex.SGML.unsafe_raw(state, inner_content)
      end)
    end)
  end

  defp normalize_content({:safe, iodata}), do: IO.iodata_to_binary(iodata)
  defp normalize_content(iodata) when is_list(iodata), do: IO.iodata_to_binary(iodata)
  defp normalize_content(binary) when is_binary(binary), do: binary
  defp normalize_content(%Phoenix.LiveView.Rendered{} = rendered) do
    static = rendered.static || []
    dynamic_result = rendered.dynamic.(false)
    IO.iodata_to_binary([static, dynamic_result])
  end
  defp normalize_content(other) do
    try do
      IO.iodata_to_binary(other)
    rescue
      _ -> to_string(other)
    end
  end
end
