# fabric-lab

docker logs zookeeper0 | grep -i binding
2018-01-30 05:55:18,197 [myid:1] - INFO  [main:NIOServerCnxnFactory@89] - binding to port 0.0.0.0/0.0.0.0:2181
[yunhwang@localhost lab]$ docker logs zookeeper1 | grep -i binding
2018-01-30 05:55:17,009 [myid:2] - INFO  [main:NIOServerCnxnFactory@89] - binding to port 0.0.0.0/0.0.0.0:2181
[yunhwang@localhost lab]$ docker logs zookeeper2 | grep -i binding
2018-01-30 05:55:17,931 [myid:3] - INFO  [main:NIOServerCnxnFactory@89] - binding to port 0.0.0.0/0.0.0.0:2181

docker-compose -f docker-compose-2orgs-4peers-kafka.yaml logs kafka0 | grep -i started


kafka0                    | [2018-01-30 05:55:31,348] INFO [Socket Server on Broker 0], Started 1 acceptor threads (kafka.network.SocketServer)
kafka0                    | [2018-01-30 05:55:31,702] INFO [Kafka Server 0], started (kafka.server.KafkaServer)



+++++++++++
Create a topic named foo and keep things simple by just giving it one partition and one replica. For a production environment you would have many more broker nodes, partitions, and replicas for scalability and resiliency.

#docker-compose -f docker-compose-2orgs-4peers-kafka.yaml exec kafka0 /opt/kafka/bin/kafka-topics.sh --create --topic foo --partitions 1 --replication-factor 3 


export PATH=$PATH:/opt/kafka/bin
kafka-topics.sh --create --topic foo --partitions 1 --replication-factor 3 --zookeeper zookeeper0



+++++++++++++
Verify that the topic was created successfully:

docker-compose -f docker-compose-2orgs-4peers-kafka.yaml exec kafka0   \
	 /opt/kafka/bin/kafka-topics.sh --describe --topic foo --zookeeper zookeeper0:2181

You should see the following:

Topic:foo       PartitionCount:1        ReplicationFactor:3     Configs:
Topic: foo      Partition: 0    Leader: 3       Replicas: 3,2,0 Isr: 3,2,0


++++++++++++++
Publish some data to your new topic. This command uses the built-in Kafka Console Producer to produce 42 simple messages to the topic.

docker-compose -f docker-compose-2orgs-4peers-kafka.yaml exec kafka0 \
  bash -c "seq 42 | /opt/kafka/bin/kafka-console-producer.sh --request-required-acks 1 --broker-list kafka0:9092 --topic foo && echo 'Produced 42 messages.'"
After running the command, you should see the following:

Produced 42 messages.


++++++
Read back the message using the built-in Console consumer:

docker-compose -f docker-compose-2orgs-4peers-kafka.yaml exec kafka0 \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka0:9092 --topic foo --from-beginning --max-messages 42 --zookeeper zookeeper0


  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka0:9092 --topic foo --from-beginning --max-messages 42 --zookeeper zookeeper0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
Processed a total of 42 messages

