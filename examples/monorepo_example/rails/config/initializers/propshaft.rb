# Propshaft configuration
# Add JavaScript directories to asset paths for Propshaft
Rails.application.config.assets.paths << Rails.root.join("app/javascript") unless Rails.application.config.assets.paths.include?(Rails.root.join("app/javascript"))
Rails.application.config.assets.paths << Rails.root.join("vendor/javascript") unless Rails.application.config.assets.paths.include?(Rails.root.join("vendor/javascript"))
# Add Tailwind CSS builds directory
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds") unless Rails.application.config.assets.paths.include?(Rails.root.join("app/assets/builds"))

