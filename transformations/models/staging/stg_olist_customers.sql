{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_customers_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => true
    )
)

select
    -- 1. Primary Key
    customer_id as customer_key,
    
    -- 2. Attributes
    customer_unique_id as customer_unique_id,
    cast(customer_zip_code_prefix as string) as zip_code_prefix,
    customer_city as city,
    customer_state as state

from raw_source