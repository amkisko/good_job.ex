defmodule GoodJob.Web.ChartFormatter do
  @moduledoc """
  Formats time series data for charting with UI concerns (labels, colors, etc.).
  This module handles presentation concerns and should be used by view/controller layers.
  """

  @doc """
  Formats raw time series data for chart display.
  Adds UI concerns like labels, colors, and chart configuration.
  """
  @spec format_activity_chart(map()) :: map()
  def format_activity_chart(%{labels: labels, created: created, completed: completed, failed: failed}) do
    %{
      labels: labels,
      datasets: [
        %{
          label: "Created",
          data: created,
          borderColor: "rgb(13, 110, 253)",
          backgroundColor: "rgba(13, 110, 253, 0.1)",
          tension: 0.4
        },
        %{
          label: "Completed",
          data: completed,
          borderColor: "rgb(25, 135, 84)",
          backgroundColor: "rgba(25, 135, 84, 0.1)",
          tension: 0.4
        },
        %{
          label: "Failed",
          data: failed,
          borderColor: "rgb(220, 53, 69)",
          backgroundColor: "rgba(220, 53, 69, 0.1)",
          tension: 0.4
        }
      ]
    }
  end
end
