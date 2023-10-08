deploy:
	docker stack deploy -c docker-compose.yml etcd

destroy:
	docker stack rm etcd
