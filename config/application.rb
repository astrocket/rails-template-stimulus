require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsTemplateStimulus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
    # Use sidekiq to process Active Jobs (e.g. ActionMailer's deliver_later)
    config.active_job.queue_adapter = :sidekiq
    config.middleware.use ::I18n::Middleware
    config.generators do |g|
      g.assets  false
      g.stylesheets false
    end

    config.action_view.field_error_proc = Proc.new do |html_tag, instance|
      html = ''

      form_fields = ['textarea', 'input', 'select']

      elements = Nokogiri::HTML::DocumentFragment.parse(html_tag).css "label, " + form_fields.join(', ')

      elements.each do |e|
        if e.node_name.eql? 'label'
          e['class'] = %(#{e['class']} invalid_field_label)
          html = %(#{e}).html_safe
        elsif form_fields.include? e.node_name
          if instance.error_message.kind_of?(Array)
            html = %(#{e}<p class="text-sm text-red-600">#{instance.error_message.uniq.join(', ')}</p>).html_safe
          else
            html = %(#{e}<p class="text-sm text-red-600">#{instance.error_message}</p>).html_safe
          end
        end
      end
      html
    end
  end
end
