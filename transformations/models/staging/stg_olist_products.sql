{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_products_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
)

select
    -- 1. Primary Key
    product_id as product_key,

    -- 2. Categorization
    product_category_name as category_name_portuguese,

    -- 3. Product Descriptive Attributes
    cast(product_name_lenght as integer) as name_char_length,
    cast(product_description_lenght as integer) as description_char_length,
    cast(product_photos_qty as integer) as photo_count,

    -- 4. Physical Dimensions (Explicitly Casted)
    cast(product_weight_g as double) as weight_grams,
    cast(product_length_cm as double) as length_cm,
    cast(product_height_cm as double) as height_cm,
    cast(product_width_cm as double) as width_cm

from raw_source
