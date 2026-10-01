WITH card AS (

    SELECT * FROM {{ ref('stg_card') }}

),

account AS (

    SELECT * FROM {{ ref('stg_account') }}

),

FINAL AS (

    SELECT
        card.card_number,
        card.account_id,
        account.customer_id,
        account.branch_id,
        account.product_id,
        card.card_type,
        card.balance                AS card_balance,
        card.closing_balance,
        card.card_expiry_date,
        (card.card_expiry_date < CURRENT_DATE) AS is_expired,
        card.created_date

    FROM card
    LEFT JOIN account
        ON card.account_id = account.account_id

)

SELECT * FROM FINAL
