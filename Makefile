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

it: env
	@echo "make [build|deploy|destroy|scale]"

env:
	@test -f .env || cp .env.example .env

deploy:
	@env \
		ETCD_REPLICAS=$(service_replicas) \
		DISC_REPLICAS=$(service_replicas) \
	docker stack deploy $(compose_files) $(docker_stack_name)

destroy:
	docker stack rm $(docker_stack_name)

scale:
	docker service scale $(docker_stack_name)_etcd=$(service_replicas)
