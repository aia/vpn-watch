# encoding: utf-8
$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

unless ENV['ENV'] == 'production'
  require 'jeweler'
  require 'vpn-watch'
  Jeweler::Tasks.new do |gem|
    # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
    gem.name = "vpn-watch"
    gem.homepage = "http://github.com/aia/vpn-watch"
    gem.license = "Apache"
    gem.summary = %Q{VPN-Watch is a high availability management solution for EC2 deployments of OpenVPN}
    gem.description = %Q{VPN-Watch is a high availability management solution for EC2 deployments of OpenVPN}
    gem.email = "artem@veremey.net"
    gem.authors = ["Artem Veremey"]
    gem.version = VPNWatch::VERSION
  end
  Jeweler::RubygemsDotOrgTasks.new

  require 'rspec/core'
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.pattern = FileList['spec/**/*_spec.rb']
  end

  desc "Code coverage detail"
  task :simplecov do
    ENV['COVERAGE'] = "true"
    Rake::Task['spec'].execute
  end

  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)
  
  require 'yard'
  YARD::Rake::YardocTask.new

  require 'tasks/state_machine'
  
  namespace :graph do
    desc "Generate an Orchestrator state machine graph"
    task :orchestrator do
      graph("orchestrator")
    end
    
    desc "Generate a Client state machine graph"
    task :client do
      graph("client")
    end
    
    desc "Generate a Connection state machine graph"
    task :connection do
      graph("connection")
    end
    
    desc "Generate all state machine graph"
    task :all do
      Rake::Task['graphs:orchestrator'].execute
      Rake::Task['graphs:client'].execute
      Rake::Task['graphs:connection'].execute
    end
    
    def graph(component)
      ENV['FILE'] = "./lib/vpn-watch/#{component}.rb"
      ENV['CLASS'] = "VPNWatch::#{component.capitalize}"
      ENV['TARGET'] = "./docs"
      ENV['ORIENTATION'] = "landscape"
      Rake::Task['state_machine:draw'].execute
    end
  end
  
  task :default => :spec
end

namespace :bundle do
  desc "Bundle for production"
  task :prod do
    sh "bundle install --deployment --without development test"
    #rm_rf ".bundle"
  end
  
  desc "Bundle package"
  task :pack do
    sh "bundle package"
  end
  
  desc "Bundle for development (foreman)"
  task :dev do
    sh "bundle install --path vendor/bundle"
  end
end

namespace :vendor do
  desc "Clean temp in vendor"
  task :clean do
    rm_rf "vendor/tmp"
  end
end

namespace :start do
  desc "Foreman start all"
  task :all do
    sh "foreman start"
  end
  
  desc "Foreman start zookeeper"
  task :zoo do
    sh "foreman start zookeeper"
  end
  
  desc  "Foreman start beanstalk"
  task :bean do
    sh "foreman start beanstalk"
  end
  
  desc "Start client"
  task :client do
    sh "bundle exec bin/client config/client.xml"
  end
end

