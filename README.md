> [!IMPORTANT]
> This stack only provides initial bootstrapping of a cluster. 
> 
> To change cluster membership after the cluster is already running, see the runtime [reconfiguration guide][reconfiguration-guide].

# etcd
A high-availability Etcd deployment for Docker Swarm

## Clustering Guide
Bootstrapping an etcd cluster: Static, etcd Discovery, and DNS Discovery

See: https://etcd.io/docs/v3.5/op-guide/clustering/

### Overview

Starting an etcd cluster statically requires that each member knows another in the cluster. In a number of cases, the IPs of the cluster members may be unknown ahead of time. In these cases, the etcd cluster can be bootstrapped with the help of a discovery service.

This guide will cover the following mechanisms for bootstrapping an etcd cluster:
- Static
- etcd Discovery

### Static

Each of the bootstrapping mechanisms will be used to create a three machine etcd cluster with the following details:
Name	Address	Hostname
infra0	10.0.1.10	infra0.example.com
infra1	10.0.1.11	infra1.example.com
infra2	10.0.1.12	infra2.example.com

As we know the cluster members, their addresses and the size of the cluster before starting, we can use an offline bootstrap configuration by setting the initial-cluster flag. Each machine will get either the following environment variables or command line:

```
ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380"
ETCD_INITIAL_CLUSTER_STATE=new
```
```
--initial-cluster infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380 \
--initial-cluster-state new
```

Note that the URLs specified in initial-cluster are the advertised peer URLs, i.e. they should match the value of initial-advertise-peer-urls on the respective nodes.

If spinning up multiple clusters (or creating and destroying a single cluster) with same configuration for testing purpose, it is highly recommended that each cluster is given a unique initial-cluster-token. By doing this, etcd can generate unique cluster IDs and member IDs for the clusters even if they otherwise have the exact same configuration. This can protect etcd from cross-cluster-interaction, which might corrupt the clusters.

> See the [clustering static][clustering-static] documentation for more details.

## Discovery

In a number of cases, the IPs of the cluster peers may not be known ahead of time. This is common when utilizing cloud providers or when the network uses DHCP. In these cases, rather than specifying a static configuration, use an existing etcd cluster to bootstrap a new one. This process is called “discovery”.

There two methods that can be used for discovery:
- etcd discovery service
- DNS SRV records (Will not be covered in this guide)

### etcd discovery
To better understand the design of the discovery service protocol, we suggest reading the [discovery service protocol][discovery-service-protocol] documentation.

#### Lifetime of a discovery URL 
A discovery URL identifies a unique etcd cluster. Instead of reusing an existing discovery URL, each etcd instance shares a new discovery URL to bootstrap the new cluster.

Moreover, discovery URLs should ONLY be used for the initial bootstrapping of a cluster. To change cluster membership after the cluster is already running, see the runtime [reconfiguration guide][reconfiguration-guide].

#### Public etcd discovery service
If no exiting cluster is available, use the public discovery service hosted at discovery.etcd.io. To create a private discovery URL using the “new” endpoint, use the command:

```sh
$ curl https://discovery.etcd.io/new?size=3
# https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
```

This will create the cluster with an initial size of 3 members. If no size is specified, a default of 3 is used.

```
ETCD_DISCOVERY=https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
```

```
--discovery https://discovery.etcd.io/3e86b59982e49066c5d813af1c2e2579cbf573de
```

Each member must have a different name flag specified or else discovery will fail due to duplicated names. Hostname or machine-id can be a good choice.

This will cause each member to register itself with the discovery service and begin the cluster once all members have been registered.

> See the [clustering discovery][clustering-discovery] documentation for more details.

<!-- Links -->
[discovery-service-protocol]: https://etcd.io/docs/v3.5/dev-internal/discovery_protocol/
[reconfiguration-guide]: https://etcd.io/docs/v3.5/op-guide/runtime-configuration/
[clustering-static]: https://etcd.io/docs/v3.5/op-guide/clustering/#static
[clustering-discovery]: https://etcd.io/docs/v3.5/op-guide/clustering/#discovery
