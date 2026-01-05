defmodule MonorepoExampleWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, live views and so on.
  """

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(view_helpers())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: MonorepoExampleWeb

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.VerifiedRoutes

      unquote(view_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      import Phoenix.VerifiedRoutes

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.LiveView.Helpers

      alias MonorepoExampleWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
