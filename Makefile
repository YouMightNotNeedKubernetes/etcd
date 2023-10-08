docker_stack_name := etcd
service_replicas := 3

deploy:
	docker stack deploy -c docker-compose.yml $(docker_stack_name)

destroy:
	docker stack rm $(docker_stack_name)

scale:
	docker service scale $(docker_stack_name)_etcd=$(service_replicas)
