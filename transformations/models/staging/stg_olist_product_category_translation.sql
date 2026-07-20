{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/product_category_name_translation.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
),

typed as (
    select
        product_category_name as category_name_portuguese,
        product_category_name_english as category_name_english
    from raw_source
),

deduped as (
    select *
    from typed
    qualify row_number() over (
        partition by category_name_portuguese
        order by category_name_portuguese
    ) = 1
)

select * from deduped
