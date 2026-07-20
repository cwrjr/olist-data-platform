{{ config(
    materialized='table',
    file_format='delta'
) }}

with reviews as (
    select * from {{ ref('fct_order_reviews') }}
)

select
    review_score,
    
    -- Volume & Comment Coverage Metrics
    count(*) as total_reviews_count,
    count(case when comment_message is not null and trim(comment_message) != '' then 1 end) as reviews_with_written_comments_count,
    round(
        count(case when comment_message is not null and trim(comment_message) != '' then 1 end) * 100.0 / count(*), 
        2
    ) as comment_written_rate_pct,
    
    -- Response Latency Metrics
    round(avg(review_response_delay_days), 1) as avg_merchant_response_delay_days,
    
    -- Operational Keyword Complaint Signal Flags
    count(case when lower(coalesce(comment_message, '')) like '%atraso%' 
                 or lower(coalesce(comment_message, '')) like '%demor%' 
                 or lower(coalesce(comment_message, '')) like '%late%' 
                 or lower(coalesce(comment_message, '')) like '%delay%' then 1 end) as delay_complaint_count,
                 
    count(case when lower(coalesce(comment_message, '')) like '%estragad%' 
                 or lower(coalesce(comment_message, '')) like '%quebrad%' 
                 or lower(coalesce(comment_message, '')) like '%damag%' 
                 or lower(coalesce(comment_message, '')) like '%broken%' then 1 end) as damage_complaint_count,

    count(case when lower(coalesce(comment_message, '')) like '%pessim%' 
                 or lower(coalesce(comment_message, '')) like '%ruim%' 
                 or lower(coalesce(comment_message, '')) like '%bad%' 
                 or lower(coalesce(comment_message, '')) like '%poor%' then 1 end) as poor_quality_complaint_count

from reviews
group by 1
