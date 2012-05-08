#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'vpn-watch'

STDOUT.sync = true

usage = <<-USAGE
  worker.rb <configuration file>
USAGE

environment = ENV['ENV'] || "development"

if !ARGV[0].nil? && File.exists?(ARGV[0])
  config = YAML.load_file(ARGV[0])[environment]
else
  puts usage
  exit
end

VPNWatch::Worker.new(config)