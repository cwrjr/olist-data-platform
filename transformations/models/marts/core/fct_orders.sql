{{ config(
    materialized='table',
    file_format='delta'
) }}

with orders as (
    select * from {{ ref('stg_olist_orders') }}
),

order_items as (
    select 
        order_key,
        count(*) as total_items_ordered,
        count(distinct seller_key) as unique_sellers_count,
        sum(price) as total_item_revenue,
        sum(freight_value) as total_freight_cost
    from {{ ref('stg_olist_order_items') }}
    group by 1
)

select
    -- 1. Keys
    o.order_key,
    o.customer_key,
    
    -- 2. Operational Status
    o.order_status,
    
    -- 3. Core Timestamps
    o.purchase_timestamp as purchased_at,
    o.approved_at_timestamp as approved_at,
    o.delivered_carrier_timestamp as handed_to_carrier_at,
    o.delivered_customer_timestamp as delivered_to_customer_at,
    o.estimated_delivery_timestamp as estimated_delivery_at,
    
    -- 4. Dynamic Operational Analytics (Fulfillment Durations)
    datediff(o.delivered_customer_timestamp, o.purchase_timestamp) as actual_delivery_days,
    datediff(o.estimated_delivery_timestamp, o.delivered_customer_timestamp) as delivery_buffer_days,
    
    case 
        when o.order_status in ('canceled', 'unavailable') then 'Canceled / Unavailable'
        when o.delivered_customer_timestamp <= o.estimated_delivery_timestamp then 'On Time / Early'
        when o.delivered_customer_timestamp > o.estimated_delivery_timestamp then 'Late'
        else 'In Flight'
    end as delivery_performance_status,
    
    -- 5. Aggregated Financial & Quantity Metrics
    coalesce(i.total_items_ordered, 0) as total_items_ordered,
    coalesce(i.unique_sellers_count, 0) as unique_sellers_count,
    coalesce(i.total_item_revenue, 0.0) as total_item_revenue,
    coalesce(i.total_freight_cost, 0.0) as total_freight_cost,
    coalesce(i.total_item_revenue, 0.0) + coalesce(i.total_freight_cost, 0.0) as total_order_value

from orders o
left join order_items i 
    on o.order_key = i.order_key
