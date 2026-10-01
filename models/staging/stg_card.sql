{{ config(
     materialized = 'table'
 ) }}

WITH src AS (
    SELECT * FROM
    {{ source(
        'crmuser',
        'card'
    ) }}
),

FINAL AS (
    SELECT
        card_number,
        account_id,
        balance,
        card_type,
        closing_balance,
        card_expiry_date,
        CURRENT_TIMESTAMP AS created_date

    FROM
        src
)

SELECT * FROM FINAL
