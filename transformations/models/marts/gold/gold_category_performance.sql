{{ config(
    materialized='table',
    file_format='delta'
) }}

with order_items as (
    select * from {{ ref('fct_order_items') }}
),

products as (
    select product_key, category_name from {{ ref('dim_products') }}
),

reviews as (
    select order_key, review_score from {{ ref('fct_order_reviews') }}
),

-- Deduplicate review score to (order_key, category_name) grain to avoid line-item weighting bias
category_order_reviews as (
    select distinct
        i.order_key,
        p.category_name,
        r.review_score
    from order_items i
    join products p on i.product_key = p.product_key
    join reviews r on i.order_key = r.order_key
),

category_review_avg as (
    select
        category_name,
        round(avg(review_score), 2) as avg_review_score
    from category_order_reviews
    group by 1
)

select
    p.category_name,
    
    -- Category Revenue & Volume Metrics
    round(sum(i.total_item_value), 2) as total_category_revenue,
    round(sum(i.price), 2) as total_merchandise_revenue,
    round(sum(i.freight_value), 2) as total_freight_revenue,
    count(*) as units_sold,
    count(distinct i.order_key) as total_orders,
    
    -- Unit Economics
    round(sum(i.total_item_value) / count(*), 2) as revenue_per_unit,
    round(sum(i.freight_value) / count(*), 2) as freight_per_unit,
    
    -- Deduplicated Category Satisfaction Score
    coalesce(ra.avg_review_score, 0.0) as avg_review_score

from order_items i
join products p 
    on i.product_key = p.product_key
left join category_review_avg ra 
    on p.category_name = ra.category_name
group by 1, ra.avg_review_score
