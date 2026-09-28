{{config(
     materialized = 'table'
 ) }}

WITH src AS(
    SELECT * FROM
    {{ source (
        'crmuser',
         'customer'
    ) }}
),

FINAL AS (
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
    CURRENT_TIMESTAMP  AS created_date
    
    FROM
        src
)

SELECT * FROM FINAL