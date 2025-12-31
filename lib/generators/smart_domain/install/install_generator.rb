# frozen_string_literal: true

require 'rails/generators'

module SmartDomain
  module Generators
    # Generator for installing SmartDomain in a Rails application
    #
    # Usage:
    #   rails generate smart_domain:install
    #
    # Creates:
    #   - config/initializers/smart_domain.rb
    #   - app/domains/ directory
    #   - app/events/ directory
    #   - app/handlers/ directory
    #   - app/policies/ directory
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Install SmartDomain into your Rails application'

      # Create initializer
      def create_initializer
        template 'initializer.rb', 'config/initializers/smart_domain.rb'
      end

      # Create directory structure
      def create_directory_structure
        create_file 'app/domains/.keep'
        create_file 'app/events/.keep'
        create_file 'app/handlers/.keep'
        create_file 'app/policies/.keep'
        create_file 'app/services/.keep'
      end

      # Create base event class
      def create_application_event
        template 'application_event.rb', 'app/events/application_event.rb'
      end

      # Create base policy class
      def create_application_policy
        template 'application_policy.rb', 'app/policies/application_policy.rb'
      end

      # Create base service class
      def create_application_service
        template 'application_service.rb', 'app/services/application_service.rb'
      end

      # Show post-install message
      def show_readme
        readme 'README' if behavior == :invoke
      end
    end
  end
end
