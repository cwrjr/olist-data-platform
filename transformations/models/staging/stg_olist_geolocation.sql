{{ config(
    materialized='table',
    file_format='delta'
) }}

with raw_source as (
    select * from read_files(
        '/Volumes/olist/bronze/raw_unstructured_files/olist_geolocation_dataset.csv',
        format => 'csv',
        header => true,
        inferSchema => false
    )
),

typed as (
    select
        -- 1. Composite / Natural Keys
        cast(geolocation_zip_code_prefix as string) as zip_code_prefix,

        -- 2. Geospatial Attributes
        cast(geolocation_lat as double) as latitude,
        cast(geolocation_lng as double) as longitude,
        geolocation_city as city,
        geolocation_state as state

    from raw_source
),

deduped as (
    select
        zip_code_prefix,
        latitude,
        longitude,
        city,
        state
    from typed
    qualify row_number() over (
        partition by zip_code_prefix
        order by latitude, longitude
    ) = 1
)

select * from deduped
