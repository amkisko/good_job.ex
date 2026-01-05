defmodule HabitTrackerWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  import Phoenix.Component, except: [form: 1]

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-click="lv:clear-flash" value={:info} />

      <.flash group={:error} flash={@flash} />
  """
  attr :id, :string, default: "flash-container", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  slot :inner_block, doc: "the optional inner block that renders the flash"

  def flash(assigns) do
    ~H"""
    <div id={@id} phx-click={Phoenix.LiveView.JS.push("lv:clear-flash")} phx-value-key={assigns[:key]} role="alert">
      <%= if title = assigns[:title] do %>
        <p class="alert-title"><%= title %></p>
      <% end %>
      <%= render_slot(@inner_block) %>
      <button type="button" class="alert-close" aria-label="close">✕</button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages to display"

  def flash_group(assigns) do
    ~H"""
    <div aria-live="polite" aria-atomic="true" class="phx-flash-container mb-6">
      <%= for {kind, message} <- @flash do %>
        <div
          class={[
            "rounded-3xl shadow-xl p-4 mb-3 transition-all hover:scale-105 cursor-pointer border-3",
            "alert-#{kind}"
          ]}
          style={flash_style(kind)}
          role="alert"
          phx-click="lv:clear-flash"
          phx-value-key={kind}
        >
          <div class="flex items-center gap-3">
            <span class="text-2xl"><%= flash_emoji(kind) %></span>
            <p class="font-semibold flex-1" style="color: #2d1b2e;"><%= message %></p>
            <button type="button" class="text-xl hover:scale-125 transition-transform" aria-label="close">✕</button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp flash_style(:info), do: "background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); border-color: rgba(255,255,255,0.6);"
  defp flash_style(:error), do: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%); border-color: rgba(255,255,255,0.6);"
  defp flash_style(:success), do: "background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); border-color: rgba(255,255,255,0.6);"
  defp flash_style(_), do: "background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%); border-color: rgba(255,255,255,0.6);"

  defp flash_emoji(:info), do: "💡"
  defp flash_emoji(:error), do: "😿"
  defp flash_emoji(:success), do: "🎉"
  defp flash_emoji(_), do: "🌸"

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-submit="save">
        <.input field={@form[:email]} type="email" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <%= render_slot(@inner_block, f) %>
      <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
        <%= render_slot(action, f) %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, doc: "a form field struct retrieved from the form"
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(autocomplete cols disabled form max maxlength min minlength
                                   pattern placeholder readonly required rows size step)

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id || @name}
        value={@value}
        class={[
          "mt-2 block w-full rounded-lg border-zinc-300 py-2 px-3",
          "text-zinc-900 focus:border-zinc-400 focus:outline-none focus:ring-4 focus:ring-zinc-800/5"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <svg class="h-6 w-6 min-w-[1.5rem]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-4">
        <%= render_slot(@actions) %>
      </div>
    </header>
    """
  end

  defp form(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@for}
      as={@as}
      class={["phx-form", @class]}
      {@rest}
    >
      <%= render_slot(@inner_block, f) %>
    </.form>
    """
  end
end
