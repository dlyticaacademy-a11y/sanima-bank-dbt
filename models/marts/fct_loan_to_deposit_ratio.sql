WITH account AS (

    SELECT *
    FROM {{ ref('stg_account') }}
    WHERE acct_cls_flg = 'N'

),

branch AS (

    SELECT *
    FROM {{ ref('stg_branch') }}

),

agg AS (

    SELECT
        account.branch_id,
        SUM(CASE WHEN account.schm_type IN ('CA', 'SA', 'FD', 'RD') THEN account.account_balance ELSE 0 END) AS total_deposit_balance,
        SUM(CASE WHEN account.schm_type = 'LD' THEN -account.account_balance ELSE 0 END) AS total_loan_outstanding
    FROM account
    GROUP BY GROUPING SETS ((account.branch_id), ())

)

SELECT
    COALESCE(agg.branch_id, 'ALL_BRANCHES') AS branch_id,
    COALESCE(branch.branch_name, 'All Branches') AS branch_name,
    agg.total_deposit_balance,
    agg.total_loan_outstanding,
    ROUND(
        agg.total_loan_outstanding / NULLIF(agg.total_deposit_balance, 0),
        4
    ) AS loan_to_deposit_ratio,
    CURRENT_TIMESTAMP AS calculated_at
FROM agg
LEFT JOIN branch
    ON agg.branch_id = branch.branch_id
