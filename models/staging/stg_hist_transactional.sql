{{ config(
    materialized = 'incremental',
    incremental_strategy = 'append'
)
}}

WITH src AS (

    SELECT
     *
    FROM
        {{ source(
            'crmuser', 
            'hist_transactional'
        ) }} 

    {% if is_incremental() %}

    WHERE 
        tran_date > (
            SELECT 
            MAX(tran_date)
            FROM   
             {{ this }}
        )
    {% endif %}
)
    SELECT
    tran_id, 
    account_id, 
    branch_id,
     tran_amount,
      tran_crncy,
     tran_date, 
     tran_particular,
     tran_remarks, 
     created_date, 
     modified_date
    FROM src