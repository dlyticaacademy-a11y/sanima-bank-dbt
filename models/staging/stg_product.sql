{{ config(
     materialized = 'table'
 ) }}

WITH src AS (
    SELECT * FROM
    {{ source(
        'crmuser',
        'product'
    ) }}
),

FINAL AS (
    SELECT
        product_id,
        schm_type,
        schm_code,
        product_desc,
        CURRENT_TIMESTAMP AS created_date

    FROM
        src
)

SELECT * FROM FINAL
