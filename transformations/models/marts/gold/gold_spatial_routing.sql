{{ config(
    materialized='table',
    file_format='delta'
) }}

with items as (
    select distinct 
        order_key,
        seller_key,
        customer_key
    from {{ ref('fct_order_items') }}
),

sellers as (
    select 
        seller_key, 
        city as seller_city,
        state as seller_state,
        latitude as seller_lat,
        longitude as seller_lon
    from {{ ref('dim_sellers') }}
),

customers as (
    select 
        customer_key, 
        city as customer_city,
        state as customer_state,
        latitude as customer_lat,
        longitude as customer_lon
    from {{ ref('dim_customers') }}
),

routes as (
    select
        i.order_key,
        s.seller_city,
        s.seller_state,
        s.seller_lat,
        s.seller_lon,
        c.customer_city,
        c.customer_state,
        c.customer_lat,
        c.customer_lon,
        
        -- Route packages through regional logistics hubs based on customer region
        case 
            when c.customer_state = 'SP' then 'Sao Paulo Hub'
            when c.customer_state = 'RJ' then 'Rio de Janeiro Hub'
            when c.customer_state = 'MG' then 'Belo Horizonte Hub'
            else 'Sao Paulo Hub'
        end as hub_name,
        
        case 
            when c.customer_state = 'SP' then -23.5505
            when c.customer_state = 'RJ' then -22.9068
            when c.customer_state = 'MG' then -19.9167
            else -23.5505
        end as hub_lat,
        
        case 
            when c.customer_state = 'SP' then -46.6333
            when c.customer_state = 'RJ' then -43.1729
            when c.customer_state = 'MG' then -43.9345
            else -46.6333
        end as hub_lon

    from items i
    join sellers s on i.seller_key = s.seller_key
    join customers c on i.customer_key = c.customer_key
    where s.seller_lat is not null 
      and s.seller_lon is not null
      and c.customer_lat is not null 
      and c.customer_lon is not null
)

select * 
from routes
limit 3000
