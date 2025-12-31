# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/named_base'

module SmartDomain
  module Generators
    # Generator for creating a complete domain structure
    #
    # Usage:
    #   rails generate smart_domain:domain User
    #   rails generate smart_domain:domain Order --skip-service --skip-policy
    #
    # Creates:
    #   app/domains/user_management/
    #     user_service.rb              # Domain service
    #     user_events.rb               # Domain events
    #     user_policy.rb               # Domain policy
    #     setup.rb                     # Event handler registration
    #   app/events/
    #     user_created_event.rb
    #     user_updated_event.rb
    #     user_deleted_event.rb
    class DomainGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      desc 'Generate a complete domain structure with service, events, and policy'

      class_option :skip_service, type: :boolean, default: false,
                                  desc: 'Skip generating domain service'
      class_option :skip_policy, type: :boolean, default: false,
                                 desc: 'Skip generating domain policy'
      class_option :skip_events, type: :boolean, default: false,
                                 desc: 'Skip generating domain events'
      class_option :skip_setup, type: :boolean, default: false,
                                desc: 'Skip generating setup file'

      # Generate domain directory structure
      def create_domain_directory
        empty_directory domain_path
      end

      # Generate domain service
      def create_service
        return if options[:skip_service]

        template 'service.rb.tt', "#{domain_path}/#{file_name}_service.rb"
      end

      # Generate domain events in app/events/
      def create_events
        return if options[:skip_events]

        template 'events/created_event.rb.tt', "app/events/#{file_name}_created_event.rb"
        template 'events/updated_event.rb.tt', "app/events/#{file_name}_updated_event.rb"
        template 'events/deleted_event.rb.tt', "app/events/#{file_name}_deleted_event.rb"
      end

      # Generate domain policy
      def create_policy
        return if options[:skip_policy]

        template 'policy.rb.tt', "app/policies/#{file_name}_policy.rb"
      end

      # Generate setup file for event registration
      def create_setup
        return if options[:skip_setup]

        template 'setup.rb.tt', "#{domain_path}/setup.rb"
      end

      # Show instructions
      def show_instructions
        return unless behavior == :invoke

        say "\nDomain '#{class_name}' created successfully!", :green
        say "\nCreated files:"
        say "  #{domain_path}/#{file_name}_service.rb" unless options[:skip_service]
        say "  app/events/#{file_name}_created_event.rb" unless options[:skip_events]
        say "  app/events/#{file_name}_updated_event.rb" unless options[:skip_events]
        say "  app/events/#{file_name}_deleted_event.rb" unless options[:skip_events]
        say "  app/policies/#{file_name}_policy.rb" unless options[:skip_policy]
        say "  #{domain_path}/setup.rb" unless options[:skip_setup]

        say "\nNext steps:"
        say '  1. Review and customize the generated files'
        say "  2. Add business logic to #{class_name}Service"
        say "  3. Customize authorization rules in #{class_name}Policy"
        say '  4. Restart your Rails server to load the domain setup'
      end

      private

      # Domain path (e.g., app/domains/user_management/)
      def domain_path
        "app/domains/#{file_name}_management"
      end

      # Domain module name (e.g., UserManagement)
      def domain_module_name
        "#{class_name}Management"
      end

      # Plural name (e.g., users)
      def plural_name
        file_name.pluralize
      end

      # Plural class name (e.g., Users)
      def plural_class_name
        class_name.pluralize
      end
    end
  end
end
