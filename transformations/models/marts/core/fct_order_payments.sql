{{ config(
    materialized='table',
    file_format='delta'
) }}

with payments as (
    select * from {{ ref('stg_olist_order_payments') }}
)

select
    md5(concat(coalesce(order_key, ''), '-', coalesce(cast(payment_sequential as string), ''))) as order_payment_key,
    order_key,
    payment_sequential as payment_sequence,
    payment_type,
    payment_installments as installment_count,
    payment_value as payment_amount
from payments
