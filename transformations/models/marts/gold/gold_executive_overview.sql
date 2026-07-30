{{ config(
    materialized='table',
    file_format='delta'
) }}

with orders as (
    select 
        order_key,
        customer_key,
        purchased_at,
        estimated_delivery_at,
        actual_delivery_days
    from {{ ref('fct_orders') }}
),

items as (
    select 
        order_key,
        seller_key,
        price,
        freight_value
    from {{ ref('fct_order_items') }}
),

customers as (
    select 
        customer_key, 
        state as customer_state 
    from {{ ref('dim_customers') }}
),

simulated as (
    select
        o.order_key,
        o.customer_key,
        i.seller_key,
        c.customer_state,
        o.purchased_at,
        o.estimated_delivery_at,
        o.actual_delivery_days as actual_shipping_days,
        i.freight_value as actual_freight,
        
        -- Simulation: consolidated hub logistics saves 35% time and freight cost.
        -- We apply least() to prevent optimized shipping days from exceeding actual shipping days on fast shipments.
        coalesce(least(o.actual_delivery_days, greatest(1, round(o.actual_delivery_days * 0.65))), 0) as optimized_shipping_days,
        coalesce(round(i.freight_value * 0.65, 2), 0.0) as optimized_freight

    from orders o
    join items i on o.order_key = i.order_key
    join customers c on o.customer_key = c.customer_key
    where o.actual_delivery_days is not null
      and i.freight_value is not null
)

select
    order_key,
    customer_key,
    seller_key,
    customer_state,
    purchased_at,
    estimated_delivery_at,
    actual_shipping_days,
    actual_freight,
    optimized_shipping_days,
    optimized_freight,
    
    -- Savings metrics
    (actual_shipping_days - optimized_shipping_days) as days_saved,
    round(actual_freight - optimized_freight, 2) as freight_dollars_saved,
    
    -- Late flags
    case 
        when optimized_shipping_days > datediff(estimated_delivery_at, purchased_at) 
        then 1 
        else 0 
    end as is_optimized_late

from simulated
