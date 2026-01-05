defmodule HabitTrackerWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, live views and so on.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: HabitTrackerWeb
      import Plug.Conn
      import HabitTrackerWeb.Gettext
      alias HabitTrackerWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/habit_tracker_web/templates",
        namespace: HabitTrackerWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

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

  def live_component do
    quote do
      use Phoenix.LiveComponent

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
      use PhoenixHTMLHelpers

      import Phoenix.LiveView.Helpers
      import HabitTrackerWeb.Gettext

      alias HabitTrackerWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
