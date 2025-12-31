# frozen_string_literal: true

module SmartDomain
  # Rails integration via Railtie
  #
  # This Railtie automatically integrates SmartDomain with Rails:
  # - Adds lib/generators to generator paths
  # - Auto-loads domain setup files on boot
  # - Provides rake tasks
  class Railtie < Rails::Railtie
    railtie_name :smart_domain

    # Add generators to load path
    generators do
      require_relative 'generators/install_generator'
      require_relative 'generators/domain_generator'
    end

    # Configuration hook
    config.smart_domain = SmartDomain.configuration

    # Initialize SmartDomain after Rails is loaded
    config.after_initialize do
      # Auto-load domain setup files from app/domains/**/setup.rb
      load_domain_setups if defined?(Rails.root)
    end

    # Rake tasks
    rake_tasks do
      load 'smart_domain/tasks/domains.rake'
    end

    # Load all domain setup files
    def self.load_domain_setups
      setup_files = Dir[Rails.root.join('app/domains/**/setup.rb')]

      setup_files.each do |setup_file|
        require setup_file

        # Extract domain module name from path
        # e.g., app/domains/user_management/setup.rb -> UserManagement
        domain_path = setup_file.gsub(Rails.root.join('app/domains/').to_s, '')
        domain_name = domain_path.split('/').first.camelize

        # Call setup! method if defined
        domain_module = begin
          domain_name.constantize
        rescue StandardError
          nil
        end
        if domain_module.respond_to?(:setup!)
          domain_module.setup!
          Rails.logger.info "[SmartDomain] Loaded domain: #{domain_name}"
        end
      rescue StandardError => e
        Rails.logger.error "[SmartDomain] Failed to load domain setup: #{setup_file}"
        Rails.logger.error e.message
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
