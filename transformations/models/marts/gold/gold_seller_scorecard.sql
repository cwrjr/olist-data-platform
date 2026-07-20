{{ config(
    materialized='table',
    file_format='delta'
) }}

with seller_perf as (
    select * from {{ ref('int_seller_performance_enriched') }}
),

sellers as (
    select seller_key, city, state, latitude, longitude from {{ ref('dim_sellers') }}
),

order_items as (
    select * from {{ ref('fct_order_items') }}
),

customers as (
    select customer_key, customer_unique_id from {{ ref('dim_customers') }}
),

reviews as (
    select order_key, review_score from {{ ref('fct_order_reviews') }}
),

-- Unique actual human buyers served by seller
seller_buyers as (
    select
        i.seller_key,
        count(distinct c.customer_unique_id) as unique_buyers_served,
        round(sum(i.total_item_value), 2) as total_gross_revenue,
        count(*) as total_items_sold
    from order_items i
    join customers c on i.customer_key = c.customer_key
    group by 1
),

-- Deduplicate review score to (seller_key, order_key) grain for fair multi-seller order attribution
seller_order_reviews as (
    select distinct
        i.seller_key,
        i.order_key,
        r.review_score
    from order_items i
    join reviews r on i.order_key = r.order_key
),

seller_review_avg as (
    select
        seller_key,
        round(avg(review_score), 2) as avg_review_score
    from seller_order_reviews
    group by 1
)

select
    s.seller_key,
    s.city as seller_city,
    s.state as seller_state,
    s.latitude,
    s.longitude,
    
    -- Enriched Seller Velocity Metrics from Intermediate Bridge
    sp.historical_orders_handled,
    sp.unique_products_cataloged,
    sp.merchant_avg_delivery_days,
    
    -- Financials & Human Customer Counts
    sb.unique_buyers_served,
    sb.total_items_sold,
    sb.total_gross_revenue,
    
    -- Customer Feedback Rating
    coalesce(ra.avg_review_score, 0.0) as avg_review_score

from sellers s
join seller_perf sp 
    on s.seller_key = sp.seller_key
left join seller_buyers sb 
    on s.seller_key = sb.seller_key
left join seller_review_avg ra 
    on s.seller_key = ra.seller_key
