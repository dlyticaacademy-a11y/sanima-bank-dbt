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
        SUM(CASE WHEN account.schm_type = 'CA' THEN account.account_balance ELSE 0 END) AS total_ca_balance,
        SUM(CASE WHEN account.schm_type = 'SA' THEN account.account_balance ELSE 0 END) AS total_sa_balance,
        SUM(CASE WHEN account.schm_type = 'FD' THEN account.account_balance ELSE 0 END) AS total_fd_balance,
        SUM(CASE WHEN account.schm_type = 'RD' THEN account.account_balance ELSE 0 END) AS total_rd_balance
    FROM account
    GROUP BY GROUPING SETS ((account.branch_id), ())

)

SELECT
    COALESCE(agg.branch_id, 'ALL_BRANCHES') AS branch_id,
    COALESCE(branch.branch_name, 'All Branches') AS branch_name,
    agg.total_ca_balance,
    agg.total_sa_balance,
    agg.total_fd_balance,
    agg.total_rd_balance,
    agg.total_ca_balance + agg.total_sa_balance + agg.total_fd_balance + agg.total_rd_balance AS total_deposit_balance,
    ROUND(
        (agg.total_ca_balance + agg.total_sa_balance)
        / NULLIF(agg.total_ca_balance + agg.total_sa_balance + agg.total_fd_balance + agg.total_rd_balance, 0),
        4
    ) AS casa_ratio,
    CURRENT_TIMESTAMP AS calculated_at
FROM agg
LEFT JOIN branch
    ON agg.branch_id = branch.branch_id
