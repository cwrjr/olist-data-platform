# ADR-001: Databricks as Lakehouse Layer vs. Self-Hosted Postgres

## Context
We need a storage and compute layer to ingest, clean, and model the Olist e-commerce dataset. We evaluated using a self-hosted PostgreSQL instance versus a cloud-managed Databricks Lakehouse.

## Decision
We chose the Databricks Lakehouse architecture leveraging Delta Lake and Unity Catalog.

## Consequences & Trade-offs
* **Pros:** Unlimited horizontal scaling via Spark, decoupled storage and compute costs, native support for unstructured file staging via UC Volumes, and automated data lineage.
* **Cons:** Introduces minor initial cloud network setup complexity and operational dependencies compared to a traditional monolithic relational database.
