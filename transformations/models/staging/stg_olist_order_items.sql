{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_order_items_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
)

select
    -- 1. Keys
    order_id as order_key,
    cast(order_item_id as integer) as order_item_id,
    product_id as product_key,
    seller_id as seller_key,

    -- 2. Timestamps
    cast(shipping_limit_date as timestamp) as shipping_limit_timestamp,

    -- 3. Financial Amounts
    cast(price as double) as price,
    cast(freight_value as double) as freight_value

from raw_source
