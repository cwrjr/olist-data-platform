{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_order_reviews_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false,
        multiLine => true,
        quote => '"',
        escape => '"'
    )
),

typed as (
    select
        -- 1. Primary & Foreign Keys
        review_id as review_key,
        order_id as order_key,

        -- 2. Rating & Comments
        try_cast(review_score as integer) as review_score,
        review_comment_title as comment_title,
        review_comment_message as comment_message,

        -- 3. Timestamps (try_cast for resilient parsing)
        try_cast(review_creation_date as timestamp) as creation_timestamp,
        try_cast(review_answer_timestamp as timestamp) as answer_timestamp

    from raw_source
),

deduped as (
    select *
    from typed
    qualify row_number() over (
        partition by review_key
        order by coalesce(answer_timestamp, creation_timestamp) desc
    ) = 1
)

select * from deduped
