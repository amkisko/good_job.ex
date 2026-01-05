defmodule HabitTrackerWeb.Layouts do
  use HabitTrackerWeb, :html

  import HabitTrackerWeb.CoreComponents

  @endpoint HabitTrackerWeb.Endpoint
  @router HabitTrackerWeb.Router

  embed_templates "layouts/*"
end
