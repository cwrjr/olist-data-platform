{{ config(
    materialized='table',
    file_format='delta'
) }}

with order_items as (
    select * from {{ ref('stg_olist_order_items') }}
),

orders as (
    select 
        order_key,
        customer_key,
        order_status,
        purchase_timestamp
    from {{ ref('stg_olist_orders') }}
)

select
    -- 1. Composite Identifiers
    i.order_key,
    i.order_item_id,

    -- 2. Foreign Keys
    o.customer_key,
    i.product_key,
    i.seller_key,

    -- 3. Operational Attributes & Timestamps
    o.order_status,
    o.purchase_timestamp as ordered_at,
    i.shipping_limit_timestamp,

    -- 4. Financial Metrics
    i.price,
    i.freight_value,
    i.price + i.freight_value as total_item_value

from order_items i
inner join orders o 
    on i.order_key = o.order_key
