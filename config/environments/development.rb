require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :redis_cache_store, {
      url: "redis://localhost:6379/2",
      pool_size: 5, # https://guides.rubyonrails.org/caching_with_rails.html#connection-pool-options
      pool_timeout: 3,
      connect_timeout: 10, # Defaults to 20 seconds
      read_timeout: 1, # Defaults to 1 second
      write_timeout: 1, # Defaults to 1 second
      reconnect_attempts: 3, # Defaults to 0
      reconnect_delay: 0.1,
      reconnect_delay_max: 0.2,
      error_handler: ->(method:, returning:, exception:) {
        Sentry.capture_exception exception, level: "warning",
                                 tags: {method: method, returning: returning}
      }
    }

    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true
  config.kredis.connector = ->(config) { ConnectionPool::Wrapper.new(size: 5, timeout: 3) { Redis.new(config) } } # redis from shared.yml

  config.action_mailer.default_url_options = {host: "http://localhost:3000"}
  config.action_mailer.asset_host = 'http://localhost:3000'
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
end
