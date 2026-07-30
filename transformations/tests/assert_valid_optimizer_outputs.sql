-- Fails if the optimizer generates negative freight costs, negative shipping days, or optimized transit exceeding actual delivery time
select order_key, optimized_shipping_days, optimized_freight
from {{ ref('gold_executive_overview') }}
where 
    optimized_shipping_days < 0 
    or optimized_freight < 0
    or optimized_shipping_days > actual_shipping_days
