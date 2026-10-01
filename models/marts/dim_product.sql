WITH src AS (

    SELECT * FROM {{ ref('stg_product') }}

),

FINAL AS (

    SELECT
        product_id,
        schm_type,
        schm_code,
        product_desc,

        CASE schm_type
            WHEN 'SA' THEN 'Savings Account'
            WHEN 'CA' THEN 'Current Account'
            WHEN 'FD' THEN 'Fixed Deposit'
            WHEN 'RD' THEN 'Recurring Deposit'
            WHEN 'LD' THEN 'Loan'
            ELSE 'Unknown'
        END AS product_category,

        CASE
            WHEN schm_type IN ('SA', 'CA') THEN 'CASA'
            WHEN schm_type IN ('FD', 'RD') THEN 'Term Deposit'
            WHEN schm_type = 'LD' THEN 'Loan'
            ELSE 'Unknown'
        END AS product_group,

        (schm_type IN ('SA', 'CA', 'FD', 'RD')) AS is_deposit_product,
        (schm_type = 'LD')                      AS is_loan_product,

        created_date

    FROM src

)

SELECT * FROM FINAL
