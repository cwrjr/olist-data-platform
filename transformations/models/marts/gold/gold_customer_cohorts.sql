{{ config(
    materialized='table',
    file_format='delta'
) }}

with orders as (
    select * from {{ ref('fct_orders') }}
),

customers as (
    select customer_key, customer_unique_id from {{ ref('dim_customers') }}
),

dates as (
    select date_key, calendar_year, calendar_month, month_name, quarter_year from {{ ref('dim_dates') }}
),

-- Determine each unique human buyer's first purchase date
customer_first_orders as (
    select
        c.customer_unique_id,
        min(to_date(o.purchased_at)) as first_purchase_date
    from orders o
    join customers c on o.customer_key = c.customer_key
    group by 1
),

order_buyer_details as (
    select
        o.order_key,
        c.customer_unique_id,
        to_date(o.purchased_at) as purchase_date,
        o.total_order_value,
        fo.first_purchase_date,
        case when to_date(o.purchased_at) = fo.first_purchase_date then 'New' else 'Returning' end as customer_type,
        datediff(to_date(o.purchased_at), fo.first_purchase_date) as days_since_first_purchase
    from orders o
    join customers c on o.customer_key = c.customer_key
    join customer_first_orders fo on c.customer_unique_id = fo.customer_unique_id
)

select
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    d.quarter_year,
    
    -- Buyer & Order Counts
    count(distinct ob.customer_unique_id) as total_unique_buyers,
    count(distinct case when ob.customer_type = 'New' then ob.customer_unique_id end) as new_buyers_count,
    count(distinct case when ob.customer_type = 'Returning' then ob.customer_unique_id end) as returning_buyers_count,
    count(distinct ob.order_key) as total_orders,
    
    -- Revenue Split
    round(sum(ob.total_order_value), 2) as total_gmv,
    round(sum(case when ob.customer_type = 'New' then ob.total_order_value else 0 end), 2) as new_buyer_gmv,
    round(sum(case when ob.customer_type = 'Returning' then ob.total_order_value else 0 end), 2) as returning_buyer_gmv,
    
    -- Repeat Rates & Purchase Interval
    round(
        count(distinct case when ob.customer_type = 'Returning' then ob.customer_unique_id end) * 100.0 / 
        nullif(count(distinct ob.customer_unique_id), 0), 
        2
    ) as repeat_buyer_rate_pct,
    round(avg(case when ob.customer_type = 'Returning' then ob.days_since_first_purchase end), 1) as avg_days_since_first_purchase

from order_buyer_details ob
left join dates d 
    on ob.purchase_date = d.date_key
where d.calendar_year is not null
group by 1, 2, 3, 4
