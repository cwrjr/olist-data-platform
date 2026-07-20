{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_order_payments_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
)

select
    -- 1. Keys
    order_id as order_key,
    cast(payment_sequential as integer) as payment_sequential,

    -- 2. Attributes
    payment_type as payment_type,
    cast(payment_installments as integer) as payment_installments,

    -- 3. Financial Amount
    cast(payment_value as double) as payment_value

from raw_source
