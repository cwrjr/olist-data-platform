{{ config(
    materialized='table',
    file_format='delta'
) }}

with payments as (
    select * from {{ ref('fct_order_payments') }}
),

orders as (
    select order_key, total_order_value, purchased_at from {{ ref('fct_orders') }}
)

select
    p.payment_type,
    
    -- Volume & Transaction Metrics
    count(distinct p.order_key) as total_orders_using_payment_type,
    count(*) as total_payment_transactions,
    round(avg(p.installment_count), 1) as avg_installment_count,
    
    -- Financial Volumes
    round(sum(p.payment_amount), 2) as total_captured_payment_value,
    round(avg(p.payment_amount), 2) as avg_payment_transaction_value,
    
    -- Revenue Reconciliation (Captured Payments vs GMV)
    round(sum(o.total_order_value), 2) as total_associated_order_gmv,
    round(sum(p.payment_amount) - sum(o.total_order_value), 2) as payment_reconciliation_discrepancy

from payments p
left join orders o 
    on p.order_key = o.order_key
group by 1
