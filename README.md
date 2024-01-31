# Dockerized Setup for Kafka Connect with MSSQL Debezium Stack

## Overview

This repository provides a Dockerized setup for running Kafka Connect with Debezium for capturing changes from Microsoft
SQL Server (MSSQL). Debezium is an open-source CDC (Change Data Capture) platform that streamlines data change capture
from various databases, and in this case, it is used to capture changes from MSSQL and forward them to Kafka.

## Components

- **Apache Kafka:** A distributed streaming platform for building real-time data pipelines and streaming applications.
- **Zookeeper:** A centralized service for maintaining configuration information, naming, providing distributed
  synchronization, and providing group services.
- **Kafka Connect:** A framework for connecting Kafka with external systems.
- **Debezium:** An open-source CDC platform that captures row-level changes in databases.
- **Microsoft SQL Server (MSSQL):** A relational database management system used for storing and retrieving data.
- **Schema Registry:** A service that stores and retrieves Avro schemas for Kafka producers and consumers.

## Prerequisites

Make sure you have the following software installed on your machine:

- Docker
- Docker Compose

## Usage

1. Clone this repository:

```bash
git clone https://github.com/royalihasan/dockerized-setup-kafka-connect-mssql-debezium-stack.git
cd dockerized-setup-kafka-connect-mssql-debezium-stack
```

---

## Prepare MSSQL Database For CDC

**Step1: Login into the DB**

```shell
docker exec -it mssql-server /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Admin123
```

**Step2: Create a Demo Database and Enable CDC**

```sql
USE
[master]
GO
CREATE
DATABASE demo;
GO
USE [demo]
EXEC sys.sp_cdc_enable_db
GO

-- Run this to confirm that CDC is now enabled: 
SELECT name, is_cdc_enabled
FROM sys.databases;
GO
```

**Step3: Create Table in Demo Database**

```sql
use
[demo];

CREATE TABLE demo.dbo.ORDERS
(
    order_id        INT,
    customer_id     INT,
    order_ts        DATE,
    order_total_usd DECIMAL(5, 2),
    item            VARCHAR(50)
);
GO

EXEC sys.sp_cdc_enable_table
@source_schema = N'dbo',
@source_name   = N'ORDERS',
@role_name     = NULL,
@supports_net_changes = 0
GO

-- At this point you should get a row returned from this query
SELECT s.name AS Schema_Name, tb.name AS Table_Name, tb.object_id, tb.type, tb.type_desc, tb.is_tracked_by_cdc
FROM sys.tables tb
         INNER JOIN sys.schemas s on s.schema_id = tb.schema_id
WHERE tb.is_tracked_by_cdc = 1
    GO
```

**Step4: Populate Data into the `ORDER` Table**

```sql
use
demo;
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (1, 7, '2019-12-26T02:38:46Z', '2.10', 'Proper Job');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (2, 8, '2019-12-06T06:53:07Z', '0.23', 'Wainwright');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (3, 12, '2019-11-17T12:26:20Z', '4.30', 'Proper Job');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (4, 7, '2019-11-23T07:59:39Z', '4.88', 'Galena');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (5, 14, '2019-12-03T19:25:47Z', '3.89', 'Wainwright');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (6, 16, '2019-11-25T03:42:17Z', '3.91', 'Galena');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (7, 19, '2019-11-27T16:44:46Z', '4.69', 'Landlord');
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (8, 2, '2019-11-28T10:27:19Z', '3.67', 'Proper Job');
```

> Now Database is Ready for CDC

---

## Create a Source Connector

> Note: Make Sure MSSQL Agent Should be Enable as ENV Variable `MSSQL_AGENT_ENABLED=true `

`POST http://localhost:8083/connectors/`

```json
{
  "name": "inventory-connector",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "database.hostname": "mssql",
    "database.port": "1433",
    "database.user": "sa",
    "database.password": "Admin123",
    "database.names": "demo",
    "topic.prefix": "test",
    "table.include.list": "dbo.ORDERS",
    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schemahistory.fullfillment",
    "database.encrypt": "false"
  }
}
```

**Now Check the Connector is Working Correctly!**

`By Using this in your BASH`

```shell
curl -s "http://localhost:8083/connectors?expand=info&expand=status" | \
jq '. | to_entries[] | [ .value.info.type, .key, .value.status.connector.state,.value.status.tasks[].state,.value.info.config."connector.class"]|join(":|:")' | \
column -s : -t| sed 's/\"//g'| sort
```

`The Output Should be like this `

```text
source | inventory-connector | RUNNING | RUNNING | io.debezium.connector.sqlserver.SqlServerConnector
```

## Now Check the CDC is Working Fine

**Step1: Listen the Data By Tailing the Topic**

```shell
docker run --tty --network resources_default confluentinc/cp-kafkacat kafkacat -b kafka:9092 -C -f "%S: %s\n"  -t test.demo.dbo.ORDERS
```

OR

```shell
docker exec -it connect bash /kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092  --from-beginning --property print.key=true --topic test.demo.dbo.ORDERS
```

**Step2: Access you MSSQL Bash**

```shell
docker exec -it mssql-server /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Admin123
```

**Step3: Do Some Changes in the `ORDERS` Table**

`INSERT`

```sql
insert into demo.dbo.ORDERS (order_id, customer_id, order_ts, order_total_usd, item)
values (11, 2, '2019-11-28T10:27:19Z', '3.67', 'Proper Job');
```

`UPDATE`

```sql
UPDATE demo.dbo.ORDERS
SET order_total_usd = '3.50'
WHERE order_id = 11;
```

`DELETE`

```sql
DELETE
FROM demo.dbo.ORDERS
WHERE order_id = 11;
```

> Congrats! Your CDC is working Fine

---