{{ config(
    materialized='table',
    file_format='delta'
) }}

with products as (
    select * from {{ ref('stg_olist_products') }}
),

translations as (
    -- Defensive distinct to prevent fan-out joins
    select distinct 
        category_name_portuguese, 
        category_name_english
    from {{ ref('stg_olist_product_category_translation') }}
)

select
    p.product_key,
    -- Fall back to original Portuguese name, or 'Uncategorized' if missing in source
    coalesce(t.category_name_english, p.category_name_portuguese, 'Uncategorized') as category_name,
    p.category_name_portuguese,
    p.name_char_length,
    p.description_char_length,
    p.photo_count,
    p.weight_grams,
    p.length_cm,
    p.height_cm,
    p.width_cm
from products p
left join translations t 
    on p.category_name_portuguese = t.category_name_portuguese
