require 'beanstalk-client'
require 'right_aws'

module VPNWatch
  class Worker
    attr_accessor :cluster, :server, :port, :beanstalk, :log
    
    def initialize(config)
      @cluster = config['cluster']
      @server = config['server'] || "127.0.0.1"
      @port = config['port'] || "11300"
      
      @ec2 = config['ec2']
      
      @log = Logger.new(STDOUT)
      
      @ec2['ds'] = Rightscale::Ec2.new(@ec2['key_id'], @ec2['access_key'] , :region => @ec2['region'])
      
      @log.info("ec2 config #{@ec2.inspect}")
      @log.info("cluster #{@cluster.inspect}")
      
      @beanstalk = Beanstalk::Pool.new([[@server, @port].join(":")])
      @beanstalk.watch(@cluster)
      @beanstalk.use(@cluster)
      @beanstalk.ignore('default')
      
      @log.info("connected")
      
      start_loop
    end


    def start_loop
      while true
        begin
          job = @beanstalk.reserve
          @log.info("job #{job.inspect}")
          @log.info("job #{job.body.inspect}")
          remaster(JSON.parse(job.body)['instance_id'])
          job.delete
        rescue Exception => e
          puts "Caught exception #{e.to_s}"
          exit
        end
      end
    end
    
    def remaster(instance_id)
      current_routes = @ec2['ds'].describe_route_tables(@ec2[:route_table])

      @log.info("current_routes #{current_routes.inspect}")

      route_states = {}

      current_routes.first[:route_set].each do |route|
        route_states[route[:destination_cidr_block]] = route[:instance_id].to_s
      end

      @log.info("route_states #{route_states.inspect}")

      @ec2['routes'].each do |route|
        if (route_states[route].nil?)
          @log.info("The route does not exist")
          next
        end

        if (route_states[route] == instance_id)
          @log.info("Route #{route} is correctly associated with instance #{instance_id}")
        else
          @log.info("Route #{route} is associated with a different instace #{route_states[route]}")
          @ec2['ds'].delete_route(@ec2['route_table'], route)
          @ec2['ds'].create_route(@ec2['route_table'], route, :instance_id => instance_id)
        end
      end
      
      association = @ec2['ds'].describe_addresses(:public_ip => @ec2['elastic_ip']).first

      if (association[:instance_id] == instance_id)
         @log.info("EIP #{@ec2['elastic_ip']} is correctly associated with instance #{instance_id}")
      else
         @log.info("EIP #{@ec2['elastic_ip']} is associated with a different instance #{association[:instance_id]}")
         @ec2['ds'].disassociate_address(:association_id=> association[:association_id]) unless association[:instance_id].nil?
         @log.info("allocation #{association[:allocation_id]}")
         @ec2['ds'].associate_address(instance_id, :allocation_id => association[:allocation_id])
      end      
    end
  end
end