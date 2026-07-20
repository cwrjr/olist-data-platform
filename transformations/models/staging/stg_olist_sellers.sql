{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_sellers_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
),

typed as (
    select
        -- 1. Primary Key
        seller_id as seller_key,

        -- 2. Location Attributes (explicit string casting for consistency)
        cast(seller_zip_code_prefix as string) as zip_code_prefix,
        seller_city as city,
        seller_state as state

    from raw_source
),

deduped as (
    select *
    from typed
    qualify row_number() over (
        partition by seller_key
        order by seller_key
    ) = 1
)

select * from deduped
