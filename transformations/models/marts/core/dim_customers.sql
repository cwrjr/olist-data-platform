{{ config(
    materialized='table',
    file_format='delta'
) }}

with customers as (
    select * from {{ ref('stg_olist_customers') }}
),

geo as (
    -- Defensive selection to ensure 1 row per zip_code_prefix
    select distinct 
        zip_code_prefix,
        latitude,
        longitude
    from {{ ref('stg_olist_geolocation') }}
)

select
    c.customer_key,
    c.customer_unique_id,
    c.zip_code_prefix,
    c.city,
    c.state,
    -- Pulling in spatial coordinates for geographic mapping
    g.latitude,
    g.longitude

from customers c
left join geo g 
    on c.zip_code_prefix = g.zip_code_prefix
