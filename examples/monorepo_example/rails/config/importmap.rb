# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.4/dist/turbo.es2017-esm.js", preload: true
pin "@rails/actioncable", to: "https://cdn.jsdelivr.net/npm/@rails/actioncable@7.1.3/app/assets/javascripts/actioncable.esm.js"
pin "channels", to: "channels/index.js"
pin "channels/jobs_channel", to: "channels/jobs_channel.js"
