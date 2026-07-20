{{ config(
    materialized='table',
    file_format='delta'
) }}

with reviews as (
    select * from {{ ref('stg_olist_order_reviews') }}
),

orders as (
    select order_key, customer_key from {{ ref('stg_olist_orders') }}
)

select
    r.review_key,
    r.order_key,
    o.customer_key,
    r.review_score,
    r.comment_title,
    r.comment_message,
    r.creation_timestamp as review_created_at,
    r.answer_timestamp as review_answered_at,
    datediff(r.answer_timestamp, r.creation_timestamp) as review_response_delay_days
from reviews r
left join orders o 
    on r.order_key = o.order_key
