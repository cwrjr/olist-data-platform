{{ config(
    materialized='table',
    file_format='delta'
) }}

with date_sequence as (
    -- Generates a continuous series covering the entire Olist dataset timeline (2016-2018)
    select explode(sequence(to_date('2016-01-01'), to_date('2018-12-31'), interval 1 day)) as date_day
)

select
    date_day as date_key,
    year(date_day) as calendar_year,
    month(date_day) as calendar_month,
    date_format(date_day, 'MMMM') as month_name,
    quarter(date_day) as calendar_quarter,
    concat('Q', quarter(date_day), '-', year(date_day)) as quarter_year,
    dayofweek(date_day) as day_of_week,
    date_format(date_day, 'EEEE') as day_name,
    case when dayofweek(date_day) in (1, 7) then true else false end as is_weekend
from date_sequence
