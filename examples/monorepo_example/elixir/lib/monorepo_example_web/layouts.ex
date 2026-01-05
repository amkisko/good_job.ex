defmodule MonorepoExampleWeb.Layouts do
  @moduledoc """
  Layouts for the MonorepoExample web interface.
  """
  use MonorepoExampleWeb, :html

  @doc """
  Root layout for the application.
  Uses Phlex component to handle LiveView Rendered structs properly.
  """
  def root(assigns) do
    csrf_token = Phoenix.Controller.get_csrf_token()

    # Render Phlex layout component and mark as safe HTML
    # Phoenix's layout system expects safe HTML, not a Phlex struct
    layout_html = MonorepoExampleWeb.Components.RootLayout.render(%{
      inner_content: assigns[:inner_content],
      csrf_token: csrf_token
    })

    # Mark as safe HTML to prevent escaping
    Phoenix.HTML.raw(layout_html)
  end

  @doc """
  Dashboard layout for LiveDashboard with custom CSS for GoodJob components.
  """
  def dashboard(assigns) do
    assigns = assign(assigns, :csrf_token, Phoenix.Controller.get_csrf_token())

    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={@csrf_token} />
        <title>LiveDashboard</title>
        <link phx-track-static rel="stylesheet" href={Routes.static_path(MonorepoExampleWeb.Endpoint, "/assets/css/app.css")} />
        <style>
          /* Minimal CSS for GoodJob LiveDashboard components */
          .good-job-dashboard {
            padding: 1rem;
          }

          /* Grid system */
          .row {
            display: flex;
            flex-wrap: wrap;
            margin-left: -0.5rem;
            margin-right: -0.5rem;
          }

          .col-12, .col-lg-3, .col-md-6 {
            padding-left: 0.5rem;
            padding-right: 0.5rem;
            flex: 0 0 100%;
            max-width: 100%;
          }

          @media (min-width: 768px) {
            .col-md-6 {
              flex: 0 0 50%;
              max-width: 50%;
            }
          }

          @media (min-width: 992px) {
            .col-lg-3 {
              flex: 0 0 25%;
              max-width: 25%;
            }
          }

          /* Flexbox utilities */
          .d-flex {
            display: flex;
          }

          .justify-content-between {
            justify-content: space-between;
          }

          .align-items-center {
            align-items: center;
          }

          .gap-2 {
            gap: 0.5rem;
          }

          /* Spacing */
          .mb-0 { margin-bottom: 0; }
          .mb-2 { margin-bottom: 0.5rem; }
          .mb-3 { margin-bottom: 1rem; }
          .mt-4 { margin-top: 1.5rem; }

          /* Card components */
          .card {
            background: white;
            border: 1px solid #dee2e6;
            border-radius: 0.375rem;
            box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
          }

          .card-header {
            padding: 0.75rem 1.25rem;
            background-color: rgba(0, 0, 0, 0.03);
            border-bottom: 1px solid #dee2e6;
          }

          .card-body {
            padding: 1.25rem;
          }

          .card-title {
            margin-bottom: 0.5rem;
            font-size: 1.25rem;
            font-weight: 500;
          }

          .card-subtitle {
            margin-top: -0.375rem;
            margin-bottom: 0;
            font-size: 0.875rem;
            color: #6c757d;
          }

          .stat-card {
            height: 100%;
          }

          .border-primary { border-color: #0d6efd !important; }
          .border-info { border-color: #0dcaf0 !important; }
          .border-success { border-color: #198754 !important; }
          .border-danger { border-color: #dc3545 !important; }

          /* Text utilities */
          .text-primary { color: #0d6efd; }
          .text-info { color: #0dcaf0; }
          .text-success { color: #198754; }
          .text-danger { color: #dc3545; }
          .text-muted { color: #6c757d; }

          .small {
            font-size: 0.875em;
          }

          /* Badge */
          .badge {
            display: inline-block;
            padding: 0.35em 0.65em;
            font-size: 0.75em;
            font-weight: 700;
            line-height: 1;
            text-align: center;
            white-space: nowrap;
            vertical-align: baseline;
            border-radius: 0.375rem;
          }

          .bg-success {
            background-color: #198754;
            color: white;
          }

          .bg-warning {
            background-color: #ffc107;
            color: #000;
          }

          /* Form elements */
          .form-check-label {
            margin-left: 0.5rem;
            cursor: pointer;
          }

          .form-check-input {
            cursor: pointer;
          }

          .form-select {
            display: block;
            width: 100%;
            padding: 0.375rem 2.25rem 0.375rem 0.75rem;
            font-size: 1rem;
            font-weight: 400;
            line-height: 1.5;
            color: #212529;
            background-color: #fff;
            border: 1px solid #ced4da;
            border-radius: 0.375rem;
            appearance: none;
            background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M2 5l6 6 6-6'/%3e%3c/svg%3e");
            background-repeat: no-repeat;
            background-position: right 0.75rem center;
            background-size: 16px 12px;
          }

          .form-select-sm {
            padding-top: 0.25rem;
            padding-bottom: 0.25rem;
            padding-right: 1.75rem;
            font-size: 0.875rem;
          }
        </style>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end
