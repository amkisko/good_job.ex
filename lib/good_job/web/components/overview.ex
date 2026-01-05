defmodule GoodJob.Web.Components.Overview do
  @moduledoc """
  Overview component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.Web.DataLoader

  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-lg-3 col-md-6 mb-3">
        <div class="card stat-card border-primary">
          <div class="card-body">
            <h6 class="card-subtitle mb-2 text-muted">Queued</h6>
            <h3 class="card-title text-primary"><%= @stats.queued %></h3>
          </div>
        </div>
      </div>

      <div class="col-lg-3 col-md-6 mb-3">
        <div class="card stat-card border-info">
          <div class="card-body">
            <h6 class="card-subtitle mb-2 text-muted">Running</h6>
            <h3 class="card-title text-info"><%= @stats.running %></h3>
          </div>
        </div>
      </div>

      <div class="col-lg-3 col-md-6 mb-3">
        <div class="card stat-card border-success">
          <div class="card-body">
            <h6 class="card-subtitle mb-2 text-muted">Succeeded</h6>
            <h3 class="card-title text-success"><%= @stats.succeeded %></h3>
          </div>
        </div>
      </div>

      <div class="col-lg-3 col-md-6 mb-3">
        <div class="card stat-card border-danger">
          <div class="card-body">
            <h6 class="card-subtitle mb-2 text-muted">Discarded</h6>
            <h3 class="card-title text-danger"><%= @stats.discarded %></h3>
          </div>
        </div>
      </div>
    </div>

    <div class="row mt-4">
      <div class="col-12">
        <div class="card">
          <div class="card-header">
            <h5 class="card-title mb-0">Job Activity (Last 24 Hours)</h5>
          </div>
          <div class="card-body">
            <div id="chart-container" style="position: relative; height: 300px;">
              <div
                id="job-activity-chart"
                phx-update="ignore"
                data-chart-data={encode_chart_data(@chart_data)}
                style="width: 100%; height: 300px;"
              >
              </div>
              <noscript>
                <p class="text-muted">Chart requires JavaScript. Please enable JavaScript to view job activity chart.</p>
              </noscript>
            </div>
            <script id="good-job-chart-init" phx-update="ignore">
              // Apache ECharts initialization for GoodJob dashboard
              (function() {
                let resizeHandler = null;
                let echartsLoaded = false;

                function loadECharts(callback) {
                  if (window.echarts) {
                    echartsLoaded = true;
                    callback();
                    return;
                  }

                  if (echartsLoaded) return;

                  const script = document.createElement('script');
                  script.src = '<%= GoodJob.Web.LiveDashboardPage.echarts_js_path() %>';
                  script.onload = function() {
                    echartsLoaded = true;
                    callback();
                  };
                  script.onerror = function() {
                    // Fallback to CDN if bundled version fails
                    const cdnScript = document.createElement('script');
                    cdnScript.src = 'https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js';
                    cdnScript.onload = function() {
                      echartsLoaded = true;
                      callback();
                    };
                    cdnScript.onerror = function() {
                      console.error('Failed to load ECharts library');
                    };
                    document.head.appendChild(cdnScript);
                  };
                  document.head.appendChild(script);
                }

                function createChart() {
                  const chartContainer = document.getElementById('job-activity-chart');
                  if (!chartContainer) {
                    console.warn('Chart container not found');
                    return;
                  }

                  if (!window.echarts) {
                    console.warn('ECharts not loaded yet');
                    return;
                  }

                  const chartDataAttr = chartContainer.getAttribute('data-chart-data');
                  if (!chartDataAttr || chartDataAttr === '{}') {
                    console.warn('No chart data available');
                    return;
                  }

                  try {
                    const chartData = JSON.parse(chartDataAttr);

                    // Dispose existing chart if it exists
                    if (chartContainer.goodJobChart) {
                      chartContainer.goodJobChart.dispose();
                      chartContainer.goodJobChart = null;
                    }

                    // Remove old resize handler if it exists
                    if (resizeHandler) {
                      window.removeEventListener('resize', resizeHandler);
                      resizeHandler = null;
                    }

                    // Initialize ECharts instance
                    chartContainer.goodJobChart = echarts.init(chartContainer);

                    // Configure chart options
                    const option = {
                      tooltip: {
                        trigger: 'axis',
                        axisPointer: {
                          type: 'cross'
                        }
                      },
                      legend: {
                        data: chartData.datasets.map(d => d.label),
                        top: 10
                      },
                      grid: {
                        left: '3%',
                        right: '4%',
                        bottom: '3%',
                        containLabel: true
                      },
                      xAxis: {
                        type: 'category',
                        boundaryGap: false,
                        data: chartData.labels
                      },
                      yAxis: {
                        type: 'value',
                        minInterval: 1
                      },
                      series: chartData.datasets.map(dataset => ({
                        name: dataset.label,
                        type: 'line',
                        smooth: true,
                        data: dataset.data,
                        itemStyle: {
                          color: dataset.borderColor
                        },
                        areaStyle: {
                          color: dataset.backgroundColor
                        }
                      }))
                    };

                    // Set chart option and render
                    chartContainer.goodJobChart.setOption(option);

                    // Handle window resize
                    resizeHandler = function() {
                      if (chartContainer.goodJobChart) {
                        chartContainer.goodJobChart.resize();
                      }
                    };
                    window.addEventListener('resize', resizeHandler);
                  } catch (e) {
                    console.error('Error initializing GoodJob chart:', e, chartDataAttr);
                  }
                }

                function initChart() {
                  const chartContainer = document.getElementById('job-activity-chart');
                  if (!chartContainer) {
                    // Retry after a short delay if container doesn't exist yet
                    setTimeout(initChart, 100);
                    return;
                  }

                  if (!window.echarts) {
                    loadECharts(createChart);
                  } else {
                    createChart();
                  }
                }

                // Initialize immediately and on various events
                if (document.readyState === 'loading') {
                  document.addEventListener('DOMContentLoaded', initChart);
                } else {
                  // DOM already loaded, initialize immediately
                  setTimeout(initChart, 50);
                }

                // Re-initialize on LiveView updates
                window.addEventListener('phx:update', function() {
                  setTimeout(initChart, 150);
                });

                // Also listen for LiveView mount
                window.addEventListener('phx:mounted', function() {
                  setTimeout(initChart, 150);
                });
              })();
            </script>
          </div>
        </div>
      </div>
    </div>

    <div class="row mt-4">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Queue Statistics</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="jobs"
            >
              View All Jobs →
            </button>
          </div>
          <div class="card-body">
            <div class="table-responsive">
              <table class="table table-sm table-hover">
                <thead>
                  <tr>
                    <th>Queue</th>
                    <th>Queued</th>
                    <th>Running</th>
                    <th>Succeeded</th>
                    <th>Discarded</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for queue_stat <- DataLoader.load_queue_stats() do %>
                    <tr>
                      <td><strong><%= queue_stat.queue %></strong></td>
                      <td><%= queue_stat.queued %></td>
                      <td><%= queue_stat.running %></td>
                      <td><%= queue_stat.succeeded %></td>
                      <td><%= queue_stat.discarded %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp encode_chart_data(data) do
    case Code.ensure_loaded(Jason) do
      {:module, Jason} -> Jason.encode!(data)
      _ -> "{}"
    end
  end
end
