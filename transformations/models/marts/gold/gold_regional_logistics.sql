{{ config(
    materialized='table',
    file_format='delta'
) }}

with order_items as (
    select distinct order_key, seller_key, customer_key, freight_value from {{ ref('fct_order_items') }}
),

orders as (
    select 
        order_key, 
        order_status, 
        actual_delivery_days, 
        delivery_performance_status, 
        delivered_to_customer_at 
    from {{ ref('fct_orders') }}
),

sellers as (
    select seller_key, state as seller_state from {{ ref('dim_sellers') }}
),

customers as (
    select customer_key, state as customer_state from {{ ref('dim_customers') }}
)

select
    s.seller_state as origin_state,
    c.customer_state as destination_state,
    
    -- Volume Metrics
    count(distinct i.order_key) as total_orders_shipped,
    
    -- Fulfilled SLA Metrics (Denominator filtered to fulfilled orders)
    count(case when o.delivered_to_customer_at is not null then 1 end) as fulfilled_orders_count,
    round(
        count(case when o.delivery_performance_status = 'Late' then 1 end) * 100.0 / 
        nullif(count(case when o.delivered_to_customer_at is not null then 1 end), 0), 
        2
    ) as sla_breach_rate_pct,
    
    -- Delivery & Freight Speed Metrics
    round(avg(o.actual_delivery_days), 1) as avg_delivery_days,
    round(avg(i.freight_value), 2) as avg_freight_cost_per_item

from order_items i
join orders o on i.order_key = o.order_key
join sellers s on i.seller_key = s.seller_key
join customers c on i.customer_key = c.customer_key
where s.seller_state is not null and c.customer_state is not null
group by 1, 2
