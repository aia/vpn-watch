#!/usr/bin/env ruby

require 'eventmachine'
require 'state_machine'
require 'pp'

class MockClient < EventMachine::Connection
  state_machine :initial => :connecting do
    after_transition :connecting => :greeting, :do => :greet
    after_transition :waiting => :greeting, :do => :greet
    after_transition :waiting => :responding, :do => :respond
    
    event :connected do
      transition :connecting => :greeting
    end
    
    event :greeting_sent do
      transition :greeting => :waiting
    end
    
    event :received_data do
      transition :waiting => :responding
    end
    
    event :response_sent do
      transition :responding => :waiting
    end
    
    event :wake_up do
      transition :waiting => :greeting
    end
  end
  
  def post_init
    #send_data "test\n"
    #pp ["sent", "test"]
    #EM.add_timer(10) { post_init }
    pp ["state", state]
    connected
    pp ["state", state]
  end
  
  def receive_data(data)
    @buffer = data
    pp ["received", @buffer.chomp]
    received_data
  end
  
  def greet
    pp ["state", state]
    send_data "test\n"
    pp ["sent", "test"]
    greeting_sent
  end
  
  def respond
    pp ["state", state]
    pp ["set timer"]
    EM.add_timer(10) { wake_up }
    response_sent
    pp ["state", state]
  end
end

EM.run do
  EM::connect "127.0.0.1", 7500, MockClient
end