# FuseExchangeProtocoleExchangeProtocol.jl

FUSE eXchange Protocol defines the handshake for processes interfacing with FUSE, for example for co-simulation purposes with a controller.

```mermaid
sequenceDiagram
    autonumber
    actor FUSE as Service Requestor
    participant REDIS
    actor TokSys as Service Provider

    rect rgb(255, 223, 191)
        TokSys--)REDIS: Register service X (subscribe to channel X)
    end
    
    rect rgb(223, 255, 191)
        FUSE-->REDIS: Is service X available? (pubsub channels)
    end

    rect rgb(255, 191, 223)
        FUSE->>REDIS: del ID__X__req2pro
        FUSE->>REDIS: del ID__X__pro2req
        FUSE--)TokSys: publish FUSE session ID to channel X
    end
    
    loop
        rect rgb(191, 223, 255)
            FUSE->>+REDIS: lpush service inputs
            note over REDIS: ID__X__req2pro
            REDIS->>-TokSys: brpop service inputs
        end
        rect rgb(191, 223, 255)
            TokSys->>+REDIS: lpush service outputs
            note over REDIS: ID__X__pro2req
            REDIS->>-FUSE: brpop service outputs
        end
    end
```

## FuseExchangeProtocol builds on top of REDIS
* High Performance (operates in-memory) <1ms latency when run locally
* Support large data volumes (<512 MB per message)
* Distributed (ie. not geo-located)
* Versatility of data structures (lists, queues, streams, timeseries,...) with atomic operations
* Pub/Sub System
* Synchronous / Asynchronous communication patterns
* Supports multiple producers / consumers pattern
* Horizontal and vertical scalability
* Multi-language client libraries and open protocol
* Used by Twitter, GitHub, Snapchat, Airbnb, Netflix
* In comparison to other tools:
   * Unlike Memcached, REDIS supports a wider range of data structures and persistence.
   * While Kafka and RabbitMQ are more focused on message queuing and streaming, REDIS offers these capabilities along with its role as a data store and cache.
    * Compared to database services like DynamoDB, REDIS can serve as a more immediate, low-latency layer for data access and manipulation.
    * Unlike Hazelcast and etcd, which are more focused on distributed computing and configuration management respectively, REDIS offers a more general-purpose approach with its data structure support and performance.

## Online documentation
For more details, see the [online documentation](https://projecttorreypines.github.io/FuseExchangeProtocol.jl/dev).

![Docs](https://github.com/ProjectTorreyPines/FuseExchangeProtocol.jl/actions/workflows/make_docs.yml/badge.svg)
