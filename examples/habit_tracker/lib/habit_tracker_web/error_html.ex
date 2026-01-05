defmodule HabitTrackerWeb.ErrorHTML do
  use HabitTrackerWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates line below and add the
  # templates to `lib/habit_tracker_web/controllers/error_html/`
  # to get 404 and 500 handling automatically, or copy
  # the templates from the priv/static directory.
  #
  # embed_templates "error_html/*"

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
