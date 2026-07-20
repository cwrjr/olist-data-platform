{{ config(
    materialized='table',
    file_format='delta'
) }}

with sellers as (
    select * from {{ ref('stg_olist_sellers') }}
),

geo as (
    -- Defensive distinct to ensure 1 row per zip_code_prefix
    select distinct 
        zip_code_prefix,
        latitude,
        longitude
    from {{ ref('stg_olist_geolocation') }}
)

select
    s.seller_key,
    s.zip_code_prefix,
    s.city,
    s.state,
    -- Merging the clean location coordinates for sellers
    g.latitude,
    g.longitude

from sellers s
left join geo g 
    on s.zip_code_prefix = g.zip_code_prefix
