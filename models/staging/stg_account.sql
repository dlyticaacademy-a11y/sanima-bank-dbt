{{ config(
    materialized = 'incremental',
    unique_key = 'account_id',
    incremental_strategy = 'merge'
)
}}

WITH src AS (

    SELECT
     *
    FROM
        {{ source(
            'crmuser', 
            'account'
        ) }} 

    {% if is_incremental() %}

    WHERE 
        lchg_time > (
            SELECT 
            MAX(lchg_time)    --destination 2026-09-09
            FROM   
             {{ this }}
        )
    {% endif %}
)
    SELECT
    account_id, 
    customer_id, 
    branch_id, 
    account_balance,
     lien_amt, 
     acct_cls_flg,
      product_id, 
      schm_type,
     schm_code, 
     acct_crncy_code,
     lchg_time
    
    FROM src