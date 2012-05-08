## VPN-Watch ##

VPN-Watch is a high availability management solution for Amazon EC2/VPC deployments of OpenVPN.

### Quick Start ###

1. Deploy VPN-Watch on the orchestrator server clients will connect to (copy & bundle install)
  + Copy or install [Apache Zookeeper](http://zookeeper.apache.org/) on the orchestrator server
  + Copy or install [Beanstalkd](http://github.com/aia/beanstalkd) on the orchestrator server
  + Update orchestrator configuration in config/orchestrator.yml
      * Update Zookeeper server (most likely localhost)
      * Update Beanstalkd server (most likely localhost)
      * Update cluster name (client and orchestrator need to use the same cluster name)
  + Update worker configuration in config/worker.yml
      * Update Beanstalk server (same server that you configured for the orchestrator)
      * Update EC2 settings - API keys and routing blocks setup for your VPC
  + Start zookeeper, beanstalk, orchestrator and worker on the orchestrator server (e.g. foreman start)
2. Deploy VPN-Watch on client nodes
  + Copy or install [OpenVPN](http://openvpn.net)
  + Create a working OpenVPN configuration
  + Update client configuration in config/client.yml
      * Update Zookeeper server (the address of your orchestrator server)
      * Update OpenVPN configuration with the command used to start OpenVPN
3. Watch logs
  + Orchestrator and Worker will report when then came up
  + Client will report when it comes up
  + One of the Clients will become a leader and start the OpenVPN process
  + Orchestrator will recognize the leader and post a job to a Beanstalkd queue
  + Worker will pick up a job and run EC2 commands to adjust routes

## VPN-Watch Components ##

- [Zookeeper](http://zookeeper.apache.org/)
- [Beanstalkd](http://github.com/aia/beanstalkd)
- Orchestrator
- Worker
- Client
- [OpenVPN](http://openvpn.net)

### Zookeeper ###

VPN-Watch uses Zookeeper to keep track of VPN-Watch Clients.
Zookeeper accepts client connections, creates ephemeral nodes upon client requests, and sends state updates when cluster state changes.

### Beanstalkd ###

Beanstalkd serves as a communication channel between VPN-Watch Orchestrator and Worker. When cluster state changes Orchestrator posts a job to a Beanstalkd tube. Worker picks up a job from Beanstalkd tube and runs it.

### Orchestrator ###

Orchestrator connects to a Zookeeper server and subscribes to cluster state change event notifications. Orchestrator uses evented code to poll Zookeeper and can potentially monitor multiple clusters. To serialize execution of commands necessary to change AWS configuration according to cluster state changes, Orchestrator posts a job to a queue. A non-evented worker will pick up a job from the queue and run the necessary commands to adjust configuration.

### Worker ###

Worker executes Amazon AWS API commands to adjust configuration according to cluster state changes. In a typical Amazon EC2/VPC setup, OpenVPN servers are configured in routing tables as gateways for specific subnets. During the failover, the IP of an active OpenVPN server changes. Elastic IP associations and routing table entries need to be changed to direct traffic to a new active OpenVPN server.

### Client ###

VPN-Watch Client connects to Zookeeper and finds a current leader - an active node running OpenVPN. If a client becomes a leader itself, it starts OpenVPN and connects to OpenVPN on a management port to monitor OpenVPN state. If either a Zookeeper server becomes unavailable or OpenVPN dies/stalls, a leader kills/shuts down OpenVPN and passes the lead.

### Orchestrator state machine ###

See docs/VPNWatch::Orchestrator_state.png or run

```rake graph:orchestrator```

### Client state machine ###

See docs/VPNWatch::Client_state.png or run

```rake graph:client```

### Client OpenVPN Connection state machine ###

See docs/VPNWatch::Connection_state.png or run

```rake graph:connection```


## Contributing to VPN-Watch ##
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright ##

Copyright (c) 2012 Artem Veremey. See LICENSE.txt for further details.

