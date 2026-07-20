{{ config(
    materialized='table',
    file_format='delta'
) }}

with orders as (
    select * from {{ ref('fct_orders') }}
),

dates as (
    select * from {{ ref('dim_dates') }}
),

reviews as (
    select * from {{ ref('fct_order_reviews') }}
)

select
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    d.quarter_year,
    
    -- Financial & Volume Metrics
    round(sum(o.total_order_value), 2) as total_gmv,
    count(distinct o.order_key) as total_orders,
    round(sum(o.total_order_value) / nullif(count(distinct o.order_key), 0), 2) as avg_order_value,
    
    -- Fulfillment SLA Metrics (Denominator filtered to fulfilled orders to avoid in-flight/canceled dilution)
    count(case when o.delivered_to_customer_at is not null then 1 end) as fulfilled_orders_count,
    round(
        count(case when o.delivery_performance_status = 'On Time / Early' then 1 end) * 100.0 / 
        nullif(count(case when o.delivered_to_customer_at is not null then 1 end), 0), 
        2
    ) as on_time_delivery_rate_pct,
    
    -- Customer Satisfaction (Explicit Average Review Score)
    round(avg(r.review_score), 2) as avg_review_score

from orders o
left join dates d 
    on to_date(o.purchased_at) = d.date_key
left join reviews r 
    on o.order_key = r.order_key
where d.calendar_year is not null
group by 1, 2, 3, 4
