defmodule HabitTrackerTest do
  use ExUnit.Case, async: true

  test "example app loads" do
    assert Application.spec(:habit_tracker, :vsn)
  end
end
