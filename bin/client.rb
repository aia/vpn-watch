#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'vpn-watch'
require 'ohai'

STDOUT.sync = true

usage = <<-USAGE
  client.rb <configuration file>
USAGE

environment = ENV['ENV'] || "development"

if !ARGV[0].nil? && File.exists?(ARGV[0])
  config = YAML.load_file(ARGV[0])[environment]
else
  puts usage
  exit
end

@ohai_config = Ohai::System.new
@ohai_config.all_plugins

config['node_config'] = @ohai_config[:ec2]

#Zookeeper.set_debug_level(4)

@watch_client = VPNWatch::Client.new(config)

EM.run do
  #VPNWatch::Client.new(config)
  @watch_client.run
end