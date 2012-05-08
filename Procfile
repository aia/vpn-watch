zookeeper: java -jar vendor/bin/zookeeper-3.3.5-fatjar.jar server 2181 vendor/tmp
beanstalk: vendor/bin/beanstalkd -l 127.0.0.1 -p 11300 -V -V -V
orchestrator: bundle exec bin/orchestrator.rb config/orchestrator.yml
worker: bundle exec bin/worker.rb config/worker.yml