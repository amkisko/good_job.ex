defmodule HabitTrackerWeb.Components.Base do
  @moduledoc """
  Base module for Phlex components with automatic StyleCapsule integration.
  """
  defmacro __using__(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :app)
    strategy = Keyword.get(opts, :strategy, :nesting)
    cache_strategy = Keyword.get(opts, :cache_strategy, :compile_time)

    quote do
      use StyleCapsule.PhlexComponent,
        namespace: unquote(namespace),
        strategy: unquote(strategy),
        cache_strategy: unquote(cache_strategy)
    end
  end
end
