require 'eventmachine'
require 'state_machine'

module VPNWatch
  class Connection < EventMachine::Connection
    attr_accessor :parent, :log
    
    state_machine :initial => :connecting do
      after_transition :connecting => :greeting, :do => :greet
      after_transition :waiting => :greeting, :do => :greet
      after_transition :waiting => :responding, :do => :respond
      #after_transition any => :disconnecting, :do => :disconnect
    
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
      
      event :disconnected do
        transition any => :disconnecting
      end
    end
    
    def initialize(parent, log)
      super()
      @parent = parent
      @log = log
    end
  
    def post_init
      #send_data "test\n"
      #pp ["sent", "test"]
      #EM.add_timer(10) { post_init }
      @log.info("state #{state.inspect}")
      connected
      @log.info("state #{state.inspect}")
    end
  
    def receive_data(data)
      @buffer = data
      @log.info("received #{@buffer.chomp.inspect}")
      received_data
    end
  
    def greet
      @log.info("state #{state.inspect}")
      send_data "status\n"
      @log.info("sent status")
      greeting_sent
    end
  
    def respond
      @log.info("state #{state.inspect}")
      @log.info("set timer")
      EM.add_timer(10) { wake_up }
      response_sent
      @log.info("state #{state.inspect}")
    end
    
    def unbind
      @log.info("connection died")
      @parent.notify
      disconnected
    end
  end
end
