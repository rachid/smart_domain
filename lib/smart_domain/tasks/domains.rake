# frozen_string_literal: true

namespace :active_domain do
  desc "List all registered domains"
  task domains: :environment do
    setup_files = Dir[Rails.root.join("app/domains/**/setup.rb")]

    if setup_files.empty?
      puts "No domains found in app/domains/"
      puts "Generate your first domain with: rails generate active_domain:domain User"
    else
      puts "Registered domains:"
      setup_files.each do |setup_file|
        domain_path = setup_file.gsub(Rails.root.join("app/domains/").to_s, "")
        domain_name = domain_path.split("/").first
        puts "  - #{domain_name}"
      end
      puts "\nTotal: #{setup_files.size} domain(s)"
    end
  end

  desc "Reload all domain setups"
  task reload: :environment do
    setup_files = Dir[Rails.root.join("app/domains/**/setup.rb")]

    puts "Reloading #{setup_files.size} domain(s)..."

    setup_files.each do |setup_file|
      load setup_file

      domain_path = setup_file.gsub(Rails.root.join("app/domains/").to_s, "")
      domain_name = domain_path.split("/").first.camelize

      domain_module = domain_name.constantize rescue nil
      if domain_module && domain_module.respond_to?(:setup!)
        domain_module.setup!
        puts "  ✓ #{domain_name}"
      end
    end

    puts "Done!"
  end
end
