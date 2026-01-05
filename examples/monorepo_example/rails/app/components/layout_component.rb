class LayoutComponent < ApplicationComponent
  include StyleCapsule::Component

  def view_template
    html do
      head do
        title { @title }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        csrf_meta_tags
        stylesheet_link_tag "tailwind", "data-turbo-track": "reload"
        stylesheet_registry_tags(namespace: :default)
        javascript_importmap_tags
      end
      body do
        div(class: "container") do
          render_header
          render_flash_messages
          raw(safe(@content.to_s)) if @content
          render_footer
        end
      end
    end
  end

  def component_styles
    <<~CSS
      * {
        box-sizing: border-box;
      }
      html, body {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        background-attachment: fixed;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        margin: 0;
        padding: 0;
        min-height: 100vh;
        color: #1d1d1f;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
      }
      .container {
        max-width: 72rem; /* max-w-6xl */
        margin: 0 auto;
        padding: 1rem 1.25rem; /* p-4 sm:p-5 */
        min-height: 100vh;
        width: 100%;
      }
      @media (min-width: 640px) {
        .container {
          padding: 1.25rem; /* p-5 */
        }
      }
      .header {
        text-align: center;
        margin-bottom: 2rem; /* mb-8 */
      }
      .header h1 {
        font-size: 1.5rem; /* text-2xl */
        color: white;
        margin-bottom: 0.5rem;
        font-weight: 700;
        text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
      }
      @media (min-width: 640px) {
        .header h1 {
          font-size: 1.875rem; /* text-3xl */
        }
      }
      @media (min-width: 1024px) {
        .header h1 {
          font-size: 2.5rem; /* text-4xl */
        }
      }
      .header p {
        font-size: 1rem; /* text-base */
        color: rgba(255, 255, 255, 0.9); /* opacity-90 */
        margin: 0;
      }
      @media (min-width: 640px) {
        .header p {
          font-size: 1.125rem; /* text-lg */
        }
      }
      .alert {
        padding: 1rem; /* p-4 */
        border-radius: 0.5rem; /* rounded-lg */
        margin-bottom: 1rem; /* mb-4 */
        border: 1px solid;
      }
      .alert-success {
        background: #dcfce7; /* bg-green-100 */
        color: #166534; /* text-green-800 */
        border-color: #86efac; /* border-green-300 */
      }
      .alert-error {
        background: #fee2e2; /* bg-red-100 */
        color: #991b1b; /* text-red-800 */
        border-color: #fca5a5; /* border-red-300 */
      }
      .footer {
        text-align: center;
        margin-top: 2rem; /* mt-8 */
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.8); /* opacity-80 */
      }
      .footer a {
        color: white;
        text-decoration: underline;
      }
      .footer a:hover {
        text-decoration: none;
      }
    CSS
  end

  def initialize(title: "Monorepo Example - GoodJob", notice: nil, alert: nil, content: nil, &block)
    @title = title
    @notice = notice
    @alert = alert
    @content = content
    @block = block if block_given?
  end

  private

  def render_header
    div(class: "header") do
      h1 { "🚀 Monorepo Example - Rails Side" }
      p { "GoodJob Interactive Dashboard" }
    end
  end

  def render_flash_messages
    if @notice
      div(class: "alert alert-success") { @notice }
    end
    if @alert
      div(class: "alert alert-error") { @alert }
    end
  end

  def render_footer
    div(class: "footer") do
      p do
        plain "Auto-refreshing every 5 seconds | "
        a(href: "http://localhost:4000") { "Elixir Interface" }
        plain " | "
        a(href: "/good_job") { "GoodJob Dashboard" }
      end
    end
  end

end

