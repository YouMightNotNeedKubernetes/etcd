> [!IMPORTANT]
> This stack only provides initial bootstrapping of a cluster. 
> 
> To change cluster membership after the cluster is already running, see the runtime [reconfiguration guide][reconfiguration-guide].

# etcd
A high-availability Etcd deployment for Docker Swarm

etcd is a consistent distributed key-value store. Mainly used as a separate coordination service, in distributed systems. And designed to hold small amounts of data that can fit entirely in memory.

https://etcd.io/

## Getting Started

You should only have etcd deployed once per Docker Swarm Cluster.

You will need to create swarm-scoped overlay network called `etcd_area_lan` for the services to communicate if you haven't already.

```sh
docker network create --scope=swarm --driver=overlay --attachable etcd_area_lan
```

## How it works

The etcd cluster is deployed as a Docker Swarm service. Its leverages the `etcd_area_lan` network for forming the cluster.

### What is failure tolerance?

An etcd cluster operates so long as a member quorum can be established. If quorum is lost through transient network failures (e.g., partitions), etcd automatically and safely resumes once the network recovers and restores quorum; Raft enforces cluster consistency. For power loss, etcd persists the Raft log to disk; etcd replays the log to the point of failure and resumes cluster participation. For permanent hardware failure, the node may be removed from the cluster through [runtime reconfiguration](https://etcd.io/docs/v3.5/op-guide/runtime-configuration/).

It is recommended to have an odd number of members in a cluster. An odd-size cluster tolerates the same number of failures as an even-size cluster but with fewer nodes. The difference can be seen by comparing even and odd sized clusters:

| Cluster Size | Majority | Failure Tolerance |
| ------------ | -------- | ----------------- |
| 1            | 1        | 0                 |
| 2            | 2        | 0                 |
| 3            | 2        | 1                 |
| 4            | 3        | 1                 |
| 5            | 3        | 2                 |
| 6            | 4        | 2                 |
| 7            | 4        | 3                 |
| 8            | 5        | 3                 |
| 9            | 5        | 4                 |

Adding a member to bring the size of cluster up to an even number doesn’t buy additional fault tolerance. Likewise, during a network partition, an odd number of members guarantees that there will always be a majority partition that can continue to operate and be the source of truth when the partition ends.

> See https://etcd.io/docs/ for more information.

### Clustering Guide
Bootstrapping an etcd cluster: Static, etcd Discovery, and DNS Discovery

See: https://etcd.io/docs/v3.5/op-guide/clustering/

#### Overview

Starting an etcd cluster statically requires that each member knows another in the cluster. In a number of cases, the IPs of the cluster members may be unknown ahead of time. In these cases, the etcd cluster can be bootstrapped with the help of a discovery service.

This guide will cover the following mechanisms for bootstrapping an etcd cluster:
- Static
- etcd Discovery

#### Static

By default, the stack will bootstrap an etcd cluster with 3 members. 

Here the default cluster configuration:

| #   | Container Hostname | ETCD_NAME |
| --- | ------------------ | --------- |
| 1   | etcd-1             | etcd-1    |
| 2   | etcd-2             | etcd-2    |
| 3   | etcd-3             | etcd-3    |

As we know the cluster members, their addresses and the size of the cluster before starting, we can use an offline bootstrap configuration by setting the initial-cluster flag. Each machine will get either the following environment variables:

```sh
ETCD_INITIAL_CLUSTER=etcd-1=http://etcd-1:2380,etcd-2=http://etcd-2:2380,etcd-3=http://etcd-3:2380
```

Note that the URLs specified in initial-cluster are the advertised peer URLs, i.e. they should match the value of `ETCD_INITIAL_ADVERTISE_PEER_URLS` on the respective nodes. The default value of `ETCD_INITIAL_ADVERTISE_PEER_URLS` is `http://etcd-{{.Task.Slot}}:2380` (e.g.: `http://etcd-1:2380`).

> The `{{.Task.Slot}}` is a Docker Swarm feature that will be replaced by the task slot number. This is useful for scaling the stack to multiple nodes.
> 
> See https://docs.docker.com/engine/reference/commandline/service_create/#create-services-using-templates

If spinning up multiple clusters (or creating and destroying a single cluster) with same configuration for testing purpose, it is highly recommended that each cluster is given a unique initial-cluster-token. By doing this, etcd can generate unique cluster IDs and member IDs for the clusters even if they otherwise have the exact same configuration. This can protect etcd from cross-cluster-interaction, which might corrupt the clusters.


> See the [clustering static][clustering-static] documentation for more details.

### Discovery

In a number of cases, the IPs of the cluster peers may not be known ahead of time. This is common when utilizing cloud providers or when the network uses DHCP. In these cases, rather than specifying a static configuration, use an existing etcd cluster to bootstrap a new one. This process is called “discovery”.

There two methods that can be used for discovery:
- etcd discovery service
- DNS SRV records (Will not be covered in this guide)

#### etcd discovery
To better understand the design of the discovery service protocol, we suggest reading the [discovery service protocol][discovery-service-protocol] documentation.

##### Lifetime of a discovery URL 
A discovery URL identifies a unique etcd cluster. Instead of reusing an existing discovery URL, each etcd instance shares a new discovery URL to bootstrap the new cluster.

Moreover, discovery URLs should ONLY be used for the initial bootstrapping of a cluster. To change cluster membership after the cluster is already running, see the runtime [reconfiguration guide][reconfiguration-guide].

##### Public etcd discovery service
If no exiting cluster is available, use the public discovery service hosted at discovery.etcd.io. To create a private discovery URL using the “new” endpoint, use the command:

```sh
$ curl https://discovery.etcd.io/new?size=3
# https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
```

This will create the cluster with an initial size of 3 members. If no size is specified, a default of 3 is used.

```
ETCD_DISCOVERY=https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
```

This will cause each member to register itself with the discovery service and begin the cluster once all members have been registered.

> See the [clustering discovery][clustering-discovery] documentation for more details.

<!-- Links -->
[discovery-service-protocol]: https://etcd.io/docs/v3.5/dev-internal/discovery_protocol/
[reconfiguration-guide]: https://etcd.io/docs/v3.5/op-guide/runtime-configuration/
[clustering-static]: https://etcd.io/docs/v3.5/op-guide/clustering/#static
[clustering-discovery]: https://etcd.io/docs/v3.5/op-guide/clustering/#discovery

### Server placement

A `node.labels.etcd` label is used to determine which nodes the service can be deployed on.

The deployment uses both placement **constraints** & **preferences** to ensure that the servers are spread evenly across the Docker Swarm manager nodes and only **ALLOW** one replica per node.

![placement_prefs](https://docs.docker.com/engine/swarm/images/placement_prefs.png)

> See https://docs.docker.com/engine/swarm/services/#control-service-placement for more information.

#### List the nodes
On the manager node, run the following command to list the nodes in the cluster.

```sh
docker node ls
```

#### Add the label to the node
On the manager node, run the following command to add the label to the node.

Repeat this step for each node you want to deploy the service to. Make sure that the number of node updated matches the number of replicas you want to deploy.

**Example deploy service with 3 replicas**:
```sh
docker node update --label-add etcd=true <node-1>
docker node update --label-add etcd=true <node-2>
docker node update --label-add etcd=true <node-3>
```

## Deployment

To deploy the stack, run the following command:

```sh
$ make deploy
```

Or to deploy a self-hosted discovery server:
```sh
$ make deploy disoveryserver=true
```

## Destroy

To destroy the stack, run the following command:

```sh
$ make destroy
```
