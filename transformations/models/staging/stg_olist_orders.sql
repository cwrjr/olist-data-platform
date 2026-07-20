{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_orders_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
)

select
    -- 1. Primary Key
    order_id as order_key,

    -- 2. Foreign Keys
    customer_id as customer_key,

    -- 3. Attributes
    order_status as order_status,

    -- 4. Timestamps
    cast(order_purchase_timestamp as timestamp) as purchase_timestamp,
    cast(order_approved_at as timestamp) as approved_at_timestamp,
    cast(order_delivered_carrier_date as timestamp) as delivered_carrier_timestamp,
    cast(order_delivered_customer_date as timestamp) as delivered_customer_timestamp,
    cast(order_estimated_delivery_date as timestamp) as estimated_delivery_timestamp

from raw_source
