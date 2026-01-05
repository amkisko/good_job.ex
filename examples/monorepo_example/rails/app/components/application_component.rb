class ApplicationComponent < Phlex::HTML
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::T
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptIncludeTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags
  include Phlex::Rails::Helpers::Translate
  include Phlex::Rails::Helpers::ContentFor
  include Phlex::Rails::Helpers::Request
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::Debug
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect
  include Phlex::Rails::Helpers::Sanitize
  include Phlex::Rails::Helpers::FormFor
  include Phlex::Rails::Helpers::FormTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::SubmitTag
  include Phlex::Rails::Helpers::LabelTag
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::ContentTag
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::CSRFMetaTags

  include StyleCapsule::PhlexHelper
  # include ApplicationHelper

  # Delegate form_authenticity_token to view_context for CSRF protection
  def form_authenticity_token(**options)
    view_context.form_authenticity_token(**options)
  end

  if Rails.env.development?
    def before_template
      comment { "phlex:before_template #{self.class.name}" }
      super
    end

    def after_template
      comment { "phlex:after_template #{self.class.name}" }
      super
    end
  end
end
