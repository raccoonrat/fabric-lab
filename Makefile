# Makefile to bootup the network, and do operations (channel, chaincode)

# mode of the network: solo, kafka, couchdb, event, dev
HLF_MODE ?= kafka
HLF_VERSION ?= 1.0.2

CODE_BUILD_WAIT=40 # time to wait to build peer/orderer from local code
NETWORK_INIT_WAIT=2 # time to wait the fabric network finish initialization

COMPOSE_FILE="docker-compose-2orgs-4peers-kafka.yaml"
LOG_PATH=kafka/logs

all: test

test:
	@echo "Run test with $(COMPOSE_FILE)"
	@echo "Please make sure u have setup Docker and pulled images by 'make setup'."

	make ready  # Finish all testing
	make stop clean

ready: # create/join channel, install/instantiate cc
#	make stop
	make gen_config  # Will ignore if local config path exists
	make start

	if [ "$(HLF_MODE)" = "dev" ]; then \
			sleep ${CODE_BUILD_WAIT}; \
	else \
			sleep ${NETWORK_INIT_WAIT}; \
	fi

	make test_channel_create
	make test_channel_join
	make update_anchors

	make test_cc_install
	make test_cc_instantiate
	make test_cc_invoke_query

	make test_lscc # test lscc operations
	make test_qscc # test qscc operations

	make test_fetch_blocks # fetch block files

	#make test_config_update # not work with this version
	#make test_channel_update # not work with this version

	make logs_save
	make test_fetch_blocks # fetch block files again
	make test_configtxlator

	@echo "Now the fabric network is ready to play"
	@echo "run 'make cli' to enter into the fabric-cli container."
	@echo "run 'make stop' when done."

restart: stop start

start: # bootup the fabric network
	@echo "Start a fabric network with ${COMPOSE_FILE}..."
	@make clean
	@docker-compose -f ${COMPOSE_FILE} up -d  # Start a fabric network

stop: # stop the fabric network
	@echo "Stop the fabric network with ${COMPOSE_FILE}..."
	@docker-compose -f ${COMPOSE_FILE} down >& /tmp/docker-compose.log  # Stop a fabric network

chaincode_dev: restart chaincode_init test_cc_peer0 stop

################## Channel testing operations ################

test_channel_create: # Init the channel
	@echo "Create channel on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_create.sh"

test_channel_join: # Init the channel
	@echo "Join channel"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_join.sh"

update_anchors: # Update the anchor peer
	@echo "Update anchors on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_update_anchors.sh"

test_channel_update: # send the channel update transaction
	@echo "Test channel update with adding new org"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_update.sh"

################## Configtxlator testing operations ################
test_configtxlator: # Test change config using configtxlator
	if [ "$(HLF_MODE)" = "kafka" ]; then \
		bash scripts/test_configtxlator.sh kafka; \
	else \
		bash scripts/test_configtxlator.sh solo; \
	fi

test_config_update: # Test change config to add new org
	if [ "$(HLF_MODE)" = "kafka" ]; then \
		bash scripts/test_config_update.sh kafka; \
	else \
		bash scripts/test_config_update.sh solo; \
	fi

################## Chaincode testing operations ################
test_cc: # test chaincode, deprecated
	if [ "$(HLF_MODE)" = "dev" ]; then \
			make test_cc_peer0; \
	else \
			make test_cc_invoke_query; \
	fi

test_cc_install: # Install the chaincode
	@echo "Install chaincode on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_install.sh"

test_cc_instantiate: # Instantiate the chaincode
	@echo "Instantiate chaincode on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_instantiate.sh"

test_cc_upgrade: # Upgrade the chaincode
	@echo "Upgrade chaincode on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_upgrade.sh"

test_cc_invoke_query: # test user chaincode on all peers
	@echo "Invoke and query cc example02 on all peers"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_invoke_query.sh"

test_qscc: # test qscc queries
	@echo "Test QSCC query"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_qscc.sh"

test_lscc: # test lscc quries
	@echo "Test LSCC query"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_lscc.sh"

# FIXME: docker doesn't support wildcard in cp right now
test_fetch_blocks: # test fetching channel blocks fetch
	@echo "Test fetching block files"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_fetch_blocks.sh"

################## Env setup related, no need to see usually ################

setup: # setup the environment
	bash scripts/env_setup.sh # Installing Docker and Docker-Compose
	bash scripts/download_images.sh # Pull required Docker images

check: # Check shell scripts grammar
	@echo "Check shell scripts grammar"
	[ `which shellcheck` ] && shellcheck scripts/*.sh

clean: # clean up containers
	@echo "Clean all HLF containers and chaincode images"
	@-docker ps -a | awk '{ print $$1,$$2 }' | grep "hyperledger/fabric" | awk '{ print $$1 }' | xargs -r -I {} docker rm -f {}
	@-docker ps -a | awk '$$2 ~ /dev-peer/ { print $$1 }' | xargs -r -I {} docker rm -f {}
	@-docker images | awk '$$1 ~ /dev-peer/ { print $$3 }' | xargs -r -I {} docker rmi -f {}

env_clean: # clean up environment
	@echo "Clean all images and containers"
	bash scripts/env_clean.sh

cli: # enter the cli container
	docker exec -it fabric-cli bash

orderer: # enter the orderer container
	docker exec -it orderer.example.com bash

peer: # enter the peer container
	docker exec -it peer0.org1.example.com bash

ps: # show existing docker images
	docker ps -a

logs: # show logs
	docker-compose -f ${COMPOSE_FILE} logs -f --tail 200

logs_check: logs_save logs_view

logs_save: # save logs
	[ -d $(LOG_PATH) ] || mkdir -p $(LOG_PATH)
	docker logs peer0.org1.example.com >& $(LOG_PATH)/dev_peer0.log
	docker logs orderer.example.com >& $(LOG_PATH)/dev_orderer.log
	docker-compose -f ${COMPOSE_FILE} logs >& $(LOG_PATH)/dev_all.log

logs_view: # view logs
	less $(LOG_PATH)/dev_peer.log

gen_config: # generate config artifacts
	if [ "$(HLF_MODE)" = "kafka" ]; then \
			bash scripts/gen_config.sh kafka; \
	else \
			bash scripts/gen_config.sh solo; \
	fi


download: # download required images
	@echo "Download Docker images"
	docker pull hyperledger/fabric-baseos:x86_64-0.3.2
	docker pull hyperledger/fabric-zookeeper:x86_64-$(HLF_VERSION)
	docker pull hyperledger/fabric-kafka:x86_64-$(HLF_VERSION)
	docker pull hyperledger/fabric-couchdb:x86_64-$(HLF_VERSION)
	docker pull hyperledger/fabric-ccenv:x86_64-$(HLF_VERSION)

################## chaincode dev mode ################
chaincode_init: # start chaincode in dev mode and do install/instantiate
	@echo "Install and instantiate cc example02 on the fabric dev network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/init_chaincode_dev.sh"

