{{ config(
    materialized='table',
    file_format='delta'
) }}

with items as (
    select * from {{ ref('fct_order_items') }}
),

orders as (
    select order_key, actual_delivery_days from {{ ref('fct_orders') }}
)

select
    i.seller_key,
    count(distinct i.order_key) as historical_orders_handled,
    count(distinct i.product_key) as unique_products_cataloged,
    round(avg(o.actual_delivery_days), 1) as merchant_avg_delivery_days
from items i
left join orders o 
    on i.order_key = o.order_key
group by 1
