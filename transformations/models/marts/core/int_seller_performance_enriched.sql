{{ config(
    materialized='table',
    file_format='delta'
) }}

with seller_orders as (
    -- Deduplicate to (seller_key, order_key) grain for unweighted delivery day averaging
    select distinct 
        seller_key, 
        order_key 
    from {{ ref('fct_order_items') }}
),

seller_products as (
    select 
        seller_key, 
        count(distinct product_key) as unique_products_cataloged 
    from {{ ref('fct_order_items') }}
    group by 1
),

orders as (
    select order_key, actual_delivery_days from {{ ref('fct_orders') }}
)

select
    so.seller_key,
    count(distinct so.order_key) as historical_orders_handled,
    sp.unique_products_cataloged,
    round(avg(o.actual_delivery_days), 1) as merchant_avg_delivery_days
from seller_orders so
left join orders o 
    on so.order_key = o.order_key
left join seller_products sp 
    on so.seller_key = sp.seller_key
group by 1, sp.unique_products_cataloged
