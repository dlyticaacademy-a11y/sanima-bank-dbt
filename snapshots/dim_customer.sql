{% snapshot dim_customer %}

{{ config(
    target_schema = 'gold',
    strategy      = 'timestamp',
    unique_key    = 'cust_id',
    updated_at    = 'created_date'
) }}

WITH src AS (
    SELECT * FROM {{ ref('stg_customer') }}
)

SELECT
    cust_id,
    name,
    address,
    phone_number,
    postal_code,
    country,
    email,
    father_name,
    mother_name,
    occupation,
    education,
    nationality,
    created_date
FROM src

{% endsnapshot %}


end_of_day_acct_bal_table