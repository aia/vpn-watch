#!/usr/bin/env ruby

require 'eventmachine'
require 'daemons'
require 'pp'

class MockOpenVPN < EventMachine::Connection
  def receive_data(data)
    case data
    when /quit/i
      close_connection
    when /pid/i
      send_data "#{Process.pid}\n"
    else
      send_data "status\n"
    end
  end
end

Daemons.daemonize(:app_name => "mock-openvpn")

EM.run do
  EM::start_server "127.0.0.1", 7500, MockOpenVPN
end