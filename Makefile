docker_stack_name := etcd
service_replicas := 3

discoveryserver := false
compose_files := -c docker-compose.yml

ifeq ($(discoveryserver),true)
	compose_files += -c docker-compose.discoveryserver.yml
endif

ifneq ("$(wildcard docker-compose.override.yml)","")
	compose_files += -c docker-compose.override.yml
endif

it: env network
	@echo "make [deploy|destroy|scale]"

env:
	@test -f .env || cp .env.example .env

network:
	@docker network create --scope=swarm --driver=overlay --attachable etcd_area_lan || true

deploy: network
	@env \
		ETCD_REPLICAS=$(service_replicas) \
		DISC_REPLICAS=$(service_replicas) \
	docker stack deploy $(compose_files) $(docker_stack_name)

destroy:
	docker stack rm $(docker_stack_name)

scale:
	docker service scale $(docker_stack_name)_etcd=$(service_replicas)
