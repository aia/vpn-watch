require 'eventmachine'
require 'zk-eventmachine'
require 'state_machine'
require 'em-jack'
require 'json'

module VPNWatch
  class Orchestrator
    attr_accessor :zookeeper, :bean, :cluster, :leader, :leader_data
    
    state_machine :initial => :starting do
      after_transition any => :connecting, :do => :connect
      after_transition any => :configuring, :do => :configure
      after_transition :configuring => :node_creating, :do => :node_create
      after_transition :configuring => :watching, :do => :watch
      after_transition :watching => :remastering, :do => :remaster
      after_transition any => :disconnecting, :do => :disconnect
      
      event :started do
        transition :starting => :connecting
      end
      
      event :connected do
        transition :connecting => :configuring
      end
      
      event :node_needed do
        transition :configuring => :node_creating
      end
      
      event :node_created do
        transition :node_creating => :configuring
      end
      
      event :configured do
        transition :configuring => :watching
      end
      
      event :leader_updated do
        transition :watching => :remastering
      end
      
      event :resume_watching do
        transition :remastering => :watching
        transition :watching => :watching
      end
      
      event :zookeeper_disconnected do
        transition :configuring => :disconnecting
        transition :node_creating => :disconnecting
        transition :watching => :disconnecting
        transition :remastering => :disconnecting
      end
    end
    
    
    def initialize(config)
      super()
      @log = Logger.new(STDOUT)
      
      config_zookeeper(config)
      config_beanstalk(config)
      
      @cluster = config['cluster']
      
      @zookeeper['ds'] = ZK::ZKEventMachine::Client.new([@zookeeper['server'], @zookeeper['port']].join(":"))
      
      @zookeeper['ds'].on_disconnection do |evt|
        @log.info("zookeeper disconnected")
        zookeeper_disconnected
      end
      
      #connect
      started
    end
    
    def config_zookeeper(config)      
      @zookeeper = {
        'server' => "127.0.0.1",
        'port' => "2181",
        'node' => nil
      }
      
      @zookeeper.merge!(config['zookeeper']) if config && config['zookeeper']
    end
    
    def config_beanstalk(config)
      @bean = {
        'server' => "127.0.0.1",
        'port' => "11300"
      }
      
      @bean.merge!(config['bean']) if config && config['bean']
    end
  
    def connect
      @log.info("state #{state.inspect}")
      
      @bean['ds'] = EMJack::Connection.new("beanstalk://#{@bean['server']}:#{@bean['port']}/#{@cluster}")
      @log.info("beanstalk #{@bean['ds'].inspect}")
      
      @zookeeper['ds'].connect do
        @log.info("connected")
        start_watch
        connected
      end
    end
  
    def start_watch
      @zookeeper['ds'].event_handler.register("/#{@cluster}") do |evt|
        watch
      end
    end
    
    def configure
      @log.info("state #{state.inspect}")
      exists_call = @zookeeper['ds'].exists?("/#{@cluster}")

      exists_call.callback do |ret|
        if ret
          @log.info("node already exists")
          configured
        else
          @log.info("node create")
          node_needed
        end
      end
    end
    
    def node_create
      @log.info("state #{state.inspect}")
      
      make_call = @zookeeper['ds'].mkdir_p("/#{@cluster}")
      make_call.callback do |ret|
        node_created
      end
    end
    
    def watch
      @log.info("state #{state.inspect}")
      children_call = @zookeeper['ds'].children("/#{@cluster}", :watch => true)
    
      children_call.callback do |ret|
        @log.info("children_callback #{ret.inspect}")
        @new_leader = ret.sort.first
        @log.info("current leader #{@new_leader.inspect}")
        
        if @new_leader.nil?
          @log.info("no machines online")
          @leader = nil
          next
        end
        
        if (@new_leader != @leader)
          @log.info("master changed")
          @leader = @new_leader
          leader_updated
        else
          @log.info("master is the same")
        end
      end
    end
    
    def remaster
      @log.info("state #{state.inspect}")
      
      get_call = @zookeeper['ds'].get("/#{@cluster}/#{@leader}")

      get_call.callback do |ret|
        if (ret == "null")
          @leader_data = "not_ec2"
          @log.info("not an ec2 master")
        else
          @leader_data = JSON.parse(ret)
          @log.info("new_master #{@leader_data['instance_id']} #{@leader_data['local_ipv4']} #{@leader_data['public_ipv4']}")
        end
        
        @bean['ds'].put("new master", :ttr => 300) { |jobid|
          @log.info("job posted #{jobid}")
        }
        
        resume_watching
      end
    end
    
    def disconnect
      EM.stop
    end
  end
end