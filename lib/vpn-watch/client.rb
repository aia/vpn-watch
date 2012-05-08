require 'eventmachine'
require 'zk-eventmachine'
require 'state_machine'
require 'json'

module VPNWatch
  class Client
    attr_accessor :zookeeper, :cluster, :base_name, :node_name, :node_config, :zn_node, :log, :leader
    
    state_machine :initial => :starting do
      after_transition any => :connecting, :do => :connect
      after_transition any => :configuring, :do => :configure
      after_transition :configuring => :node_creating, :do => :node_create
      after_transition :configuring => :watching, :do => :watch
      after_transition any => :remastering, :do => :remaster
      after_transition any => :leading, :do => :lead
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
      
      event :znode_created do
        transition :configuring => :watching
      end
      
      event :node_updated do
        transition :watching => :remastering
      end
      
      event :leader_acquired do
        transition :remastering => :leading
      end
      
      event :resume_watching do
        transition :remastering => :watching
        transition :leading => :watching
        transition :watching => :watching
      end
      
      event :zookeeper_disconnected do
        transition :configuring => :disconnecting
        transition :node_creating => :disconnecting
        transition :watching => :disconnecting
        transition :remastering => :disconnecting
        transition :leading => :disconnecting
      end
    end

    def initialize(config)
      super()
      @log = Logger.new(STDOUT)
      
      config_zookeeper(config)
      
      @cluster = config['cluster']
      @base_name = config['base_name']
      @node_name = config['node_name']
      @node_config = config['node_config']
      @openvpn = config['openvpn']
      @leader = false

      @log.info("node_config #{@node_config.inspect}")
      @log.info("state #{state.inspect}")
      
      @zookeeper['ds'] = ZK::ZKEventMachine::Client.new([@zookeeper['server'], @zookeeper['port']].join(":"))
      
      @zookeeper['ds'].on_disconnection do |evt|
        @log.info("zookeeper disconnected")
        zookeeper_disconnected
      end
      
      #started
    end
    
    def config_zookeeper(config)
      @zookeeper = {
        'server' => "127.0.0.1",
        'port' => "2181",
        'node' => nil
      }
      
      @zookeeper.merge!(config['zookeeper']) if config && config['zookeeper']
    end
    
    def run
      started
    end

    def connect
      @log.info("state #{state.inspect}")
      
      @zookeeper['ds'].on_connected do |event|
        @log.info("zookeeper connected")
      end
      
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
          @log.info("znode create")
          znode_create
        else
          @log.info("node create")
          node_needed
        end
      end
    end

    def znode_create
      @log.info("state #{state.inspect}")
      
      create_call =  @zookeeper['ds'].create(
        "/#{@cluster}/#{@base_name}", 
        @node_config.to_json,
        :mode => :ephemeral,
        :sequence => true
      )
      
      create_call.callback do |ret|
        @log.info("create_call #{ret.inspect}")
        zk_match = /^\/#{@cluster}\/#{@base_name}(?<id>\w+)/.match(ret)
        @zookeeper['node'] = zk_match['id']
        @log.info("current znode #{@zookeeper['node'].inspect}")
        znode_created
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
        if (@leader)
          @log.info("resume watching")
          resume_watching
        else
          node_updated
        end
      end
    end
    
    def remaster
      @log.info("state #{state.inspect}")
      
      zk_match = /^#{@base_name}(?<id>\w+)/.match(@new_leader)
      if zk_match['id'] == @zookeeper['node']
        @log.info("this node now the leader!")
        leader_acquired
      else
        @log.info("this node is not the leader")
        resume_watching
      end
    end
    
    def lead
      @log.info("state #{state.inspect}")
      @log.info("taking leader")
      @leader = true
      @log.info("openvpn: #{@openvpn.inspect}")
      EM.system("#{@openvpn['bin']}")
      @log.info("openvpn started")
      EM.add_timer(1) { @openvpn[:ds] = EM.connect("127.0.0.1", 7500, VPNWatch::Connection, self, @log) }
      resume_watching
    end
    
    def notify
      @log.info("heard about a dead connection")
    end
    
    def disconnect
      EM.stop
    end
  end
end