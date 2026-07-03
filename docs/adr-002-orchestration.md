# ADR-002: Databricks Workflows for Orchestration vs. External Tooling

## Context
Our platform requires automated, scheduled, and dependent task execution across ingestion scripts and dbt transformations.

## Decision
We chose Databricks Workflows as our primary orchestration engine.

## Consequences & Trade-offs
* **Pros:** Fully managed and serverless (zero extra infrastructure overhead or host maintenance fees), tight native integration with dbt Core tasks and Delta schemas.
* **Cons:** Less flexible for complex cross-cloud multi-platform pipelines compared to tools like Dagster or Airflow.
* **Stretch Goal:** If pipeline requirements expand to include external APIs outside Databricks, we note Dagster as our primary migration target.
