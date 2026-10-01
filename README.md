# Sanima Bank — a dbt project for the banking domain

This project takes raw banking data sitting in a PostgreSQL database (customers, branches, products, accounts, cards and transactions) and transforms it with **dbt** into clean, tested, analysis-ready tables.

It is written as a learning project. If you follow this README from top to bottom you will be able to:

1. run this project on your own computer, and
2. build the same kind of dbt project yourself, from an empty folder.

You only need basic SQL. No previous dbt experience is assumed.

---

## Table of contents

1. [What is dbt?](#1-what-is-dbt)
2. [How this project is organised](#2-how-this-project-is-organised)
3. [The source tables](#3-the-source-tables)
4. [What you need before you start](#4-what-you-need-before-you-start)
5. [Step-by-step setup](#5-step-by-step-setup)
6. [Building the project from scratch](#6-building-the-project-from-scratch)
7. [Running the project](#7-running-the-project)
8. [What each model does](#8-what-each-model-does)
9. [Load patterns used in this project](#9-load-patterns-used-in-this-project)
10. [Practice: see incremental loads and snapshots in action](#10-practice-see-incremental-loads-and-snapshots-in-action)
11. [Command cheat sheet](#11-command-cheat-sheet)
12. [Troubleshooting](#12-troubleshooting)
13. [Glossary](#13-glossary)

---

## 1. What is dbt?

**dbt (data build tool)** lets you transform data that is already inside a database, using plain `SELECT` statements.

You write a `SELECT` query in a `.sql` file. dbt wraps it in the `CREATE TABLE` / `INSERT` / `MERGE` code for you, runs the files in the correct order, tests the results, and generates documentation.

dbt is the **T** in **ELT** (Extract, Load, Transform):

| Step | Meaning | Who does it in this project |
| --- | --- | --- |
| **E**xtract + **L**oad | Get the raw data into the database | A Python script ([insert_to_postgres.py](SQL%20FILES/insert_to_postgres.py)) |
| **T**ransform | Clean it and build reporting tables | dbt |

dbt does **not** move data between systems. It only transforms data inside one database.

---

## 2. How this project is organised

The project follows the standard dbt layout (`staging` → `marts`), which maps onto the "medallion" layers many data teams use:

```text
   PostgreSQL schema: public         schema: silver              schema: gold
  ┌──────────────────────┐      ┌──────────────────────┐    ┌───────────────────────────┐
  │  RAW / BRONZE        │      │  STAGING / SILVER    │    │  MARTS / GOLD             │
  │                      │      │                      │    │                           │
  │  customer            │      │  stg_customer        │    │  dim_customer (snapshot)  │
  │  branch              │ dbt  │  stg_branch          │dbt │  dim_product              │
  │  product             │ ───► │  stg_product         │───►│  dim_card                 │
  │  account             │      │  stg_account         │    │  fct_casa_ratio           │
  │  card                │      │  stg_card            │    │  fct_loan_to_deposit_ratio│
  │  hist_transactional  │      │  stg_hist_trans...   │    │  currency_conversion_rates│
  └──────────────────────┘      └──────────────────────┘    │  (seed)                   │
     loaded by Python              models/staging/          └───────────────────────────┘
                                                             models/marts/, snapshots/, seeds/
```

| Layer | dbt folder | Database schema | Purpose |
| --- | --- | --- | --- |
| Raw (bronze) | — (declared in `sources.yml`) | `public` | Data exactly as it arrived. dbt only reads it. |
| Staging (silver) | [models/staging/](models/staging/) | `silver` | One model per source table. Light cleaning, explicit column lists. |
| Marts (gold) | [models/marts/](models/marts/), [snapshots/](snapshots/), [seeds/](seeds/) | `gold` | Business-ready dimensions (`dim_`), facts/KPIs (`fct_`), history and reference data. |

### Folder structure

```text
sanima-bank/
├── dbt_project.yml              # Project settings: name, folders, schema per layer
├── profiles.yml                 # Database connection details
├── macros/
│   └── generate_schema_name.sql # Makes dbt use "silver"/"gold" as exact schema names
├── models/
│   ├── staging/                 # SILVER layer
│   │   ├── sources.yml          # Declares the 6 raw tables in schema "public"
│   │   ├── stg_customer.sql     # One .sql file  = one table in the database
│   │   ├── stg_customer.yml     # One .yml file  = description + tests for that table
│   │   ├── stg_branch.sql / .yml
│   │   ├── stg_product.sql / .yml
│   │   ├── stg_account.sql / .yml
│   │   ├── stg_card.sql / .yml
│   │   └── stg_hist_transactional.sql / .yml
│   └── marts/                   # GOLD layer
│       ├── dim_product.sql / .yml
│       ├── dim_card.sql / .yml
│       ├── fct_casa_ratio.sql / .yml
│       └── fct_loan_to_deposit_ratio.sql / .yml
├── snapshots/
│   └── dim_customer.sql         # Keeps the history of customer changes (SCD Type 2)
├── seeds/
│   └── currency_conversion_rates.csv   # Small CSV loaded into the database as a table
├── SQL FILES/                   # Not dbt: scripts that create and load the raw data
│   ├── insert.sql               # CREATE TABLE + INSERT for all 6 source tables
│   ├── insert_to_postgres.py    # Python script that runs insert.sql
│   ├── 1_insert_new_customer.sql            # Practice files, see section 10
│   ├── 2_update_and_insert_account.sql
│   ├── 3_insert_new_hist_transactional.sql
│   ├── add_lchg_time_to_account.sql         # Only for an older copy of the account table
│   ├── Banking_ER_Diagram.drawio            # ER diagram (open at app.diagrams.net)
│   └── load_patterns_full_incremental_merge_append.pdf
├── analyses/  tests/            # Empty for now (standard dbt folders)
└── env/  target/  logs/         # Generated locally, ignored by git
```

---

## 3. The source tables

All six tables are created and filled by [SQL FILES/insert.sql](SQL%20FILES/insert.sql) in the `public` schema.

| Table | Rows | One row is… | Primary key |
| --- | --- | --- | --- |
| `customer` | 50 | a bank customer (name, address, occupation, …) | `cust_id` |
| `branch` | 30 | a physical branch (province, city, cluster) | `branch_id` |
| `product` | 15 | a banking product / scheme | `product_id` |
| `account` | 150 | a customer's account — the central table | `account_id` |
| `card` | 60 | a debit or credit card linked to an account | `card_number` |
| `hist_transactional` | 400 | one posted transaction | `tran_id` |

How they relate:

```text
customer ──┐
branch ────┼──►  account  ──►  card
product ───┘        │
                    └───────►  hist_transactional  ◄── branch
```

Banking terms you will see in the data:

| Code | Meaning |
| --- | --- |
| `schm_type` = `SA` / `CA` | Savings Account / Current Account (together called **CASA**) |
| `schm_type` = `FD` / `RD` | Fixed Deposit / Recurring Deposit (term deposits) |
| `schm_type` = `LD` | Loan. Loan accounts have a **negative** `account_balance` (money owed to the bank) |
| `acct_cls_flg` | `N` = account is open, `Y` = account is closed |
| `lien_amt` | Part of the balance that is blocked and cannot be withdrawn |
| `lchg_time` | "Last changed time" of an account row. Used for incremental loading |

---

## 4. What you need before you start

| Requirement | How to check | Notes |
| --- | --- | --- |
| Python 3.9 or newer | `python --version` | Download from python.org. On Windows tick "Add Python to PATH" during install. |
| A database | — | This project uses **PostgreSQL 15 or newer** (15+ is needed for the `merge` strategy in `stg_account`). |
| A code editor | — | VS Code is a good choice. |
| Git (optional) | `git --version` | Only needed to clone the repository. |

A SQL client such as pgAdmin or DBeaver is helpful for looking at the tables dbt creates.

---

## 5. Step-by-step setup

Run every command from the project folder (the folder that contains `dbt_project.yml`).

### Step 1 — Create a Python virtual environment

A virtual environment is a private folder of Python packages for this project only, so it cannot clash with other projects.

```powershell
python -m venv env
```

This creates a folder called `env`.

### Step 2 — Activate the environment

You must activate it **every time you open a new terminal**.

| Terminal | Command |
| --- | --- |
| Windows PowerShell | `.\env\Scripts\Activate.ps1` |
| Windows Command Prompt | `env\Scripts\activate.bat` |
| Git Bash on Windows | `source env/Scripts/activate` |
| macOS / Linux | `source env/bin/activate` |

When it works, your prompt starts with `(env)`.

> **PowerShell says "running scripts is disabled on this system"?**
> Run this once, then activate again:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Step 3 — Install dbt with the adapter for your database

dbt needs an **adapter**: a plugin that teaches it how to talk to one type of database. Install the one that matches your database. Installing the adapter also installs dbt itself.

| Your database | Install command |
| --- | --- |
| PostgreSQL (used here) | `pip install dbt-postgres` |
| Oracle | `pip install dbt-oracle` |
| MySQL | `pip install dbt-mysql` |
| Snowflake | `pip install dbt-snowflake` |
| BigQuery | `pip install dbt-bigquery` |
| Databricks | `pip install dbt-databricks` |

Check it worked:

```powershell
dbt --version
```

You should see `dbt-core` listed under **Core** and `postgres` under **Plugins**.

### Step 4 — Load the raw data into PostgreSQL

The Python script reads `insert.sql` and creates and fills the six source tables in the `public` schema.

```powershell
python "SQL FILES\insert_to_postgres.py"
```

Expected output ends with the row counts (50 customers, 30 branches, 15 products, 150 accounts, 60 cards, 400 transactions).

The script connects with these defaults: host `localhost`, port `5432`, database `postgres`, user `postgres`, password `postgres`. If yours are different, set them before running the script:

```powershell
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGDATABASE = "postgres"
$env:PGUSER = "postgres"
$env:PGPASSWORD = "your_password"
```

Good to know:

- Tables that already exist are skipped, so running the script twice is safe.
- To delete the six tables and reload them from scratch, add `--drop`:
  `python "SQL FILES\insert_to_postgres.py" --drop`
- The script uses the `psycopg2` package, which was installed together with `dbt-postgres`.

### Step 5 — Tell dbt how to connect to the database

The connection lives in [profiles.yml](profiles.yml):

```yaml
sanima_bank:            # must match "profile:" in dbt_project.yml
  target: dev
  outputs:
    dev:
      type: postgres    # the adapter you installed
      host: localhost
      port: 5432
      user: postgres
      pass: postgres    # change to your password
      dbname: postgres
      schema: public    # default schema
      threads: 2        # how many models dbt builds at the same time
```

Edit the values to match your database, then test the connection:

```powershell
dbt debug
```

The last line should say **All checks passed!**

> dbt looks for `profiles.yml` in the current folder first, and then in your home folder (`C:\Users\<you>\.dbt\` on Windows, `~/.dbt/` on macOS/Linux).
> In a real project, never commit real passwords to git. Keep `profiles.yml` in your home folder or read the password from an environment variable: `pass: "{{ env_var('DBT_PASSWORD') }}"`.

### Step 6 — Build everything

```powershell
dbt seed        # loads the CSV in seeds/ into gold
dbt run         # builds all models (silver, then gold)
dbt snapshot    # builds / updates gold.dim_customer
dbt test        # runs all 62 data tests
```

Or do all four in the right order with a single command:

```powershell
dbt build
```

Open your SQL client: you now have a `silver` schema with 6 tables and a `gold` schema with 6 tables.

---

## 6. Building the project from scratch

Use this section if you want to create your own project instead of using this one. Do steps 1–4 of section 5 first (environment, adapter, raw data).

### 6.1 Initialise the project

```powershell
dbt init sanima_bank
```

dbt asks a few questions. For PostgreSQL the answers look like this:

```text
Which database would you like to use?
[1] postgres
Enter a number: 1                      <- pick the adapter you installed
host (hostname for the instance): localhost
port [5432]: 5432
user (dev username): postgres
pass (dev password): ********
dbname (default database that dbt will build objects in): postgres
schema (default schema that dbt will build objects in): public
threads (1 or more) [1]: 2
```

dbt creates a `sanima_bank` folder with the standard sub-folders (`models`, `seeds`, `snapshots`, `macros`, `tests`, `analyses`) and saves your answers in `profiles.yml` in your home `.dbt` folder.

```powershell
cd sanima_bank
dbt debug
```

Delete the `models/example` folder that `dbt init` creates. You do not need it.

### 6.2 Create the layer folders

Inside `models/` create two folders: `staging` (silver) and `marts` (gold).

### 6.3 Set a schema and materialization per folder

In [dbt_project.yml](dbt_project.yml), settings that start with `+` apply to every file inside that folder:

```yaml
models:
  sanima_bank:              # your project name
    staging:                # everything in models/staging/
      +materialized: table
      +schema: silver
    marts:                  # everything in models/marts/
      +materialized: table
      +schema: gold

snapshots:
  sanima_bank:
    +schema: gold

seeds:
  sanima_bank:
    +schema: gold
```

### 6.4 Add the custom schema macro

By default dbt does **not** use your schema name as written. It glues the default schema from `profiles.yml` in front of it, so `silver` becomes `public_silver`.

To get exactly `silver` and `gold`, create [macros/generate_schema_name.sql](macros/generate_schema_name.sql):

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

In words: if a model has a custom schema, use it as is; otherwise use the default schema from the profile. The macro must have this exact name, because dbt calls it automatically for every model.

### 6.5 Declare the raw tables as sources

Create [models/staging/sources.yml](models/staging/sources.yml) so dbt knows which raw tables exist:

```yaml
version: 2

sources:
  - name: crmuser          # a nickname you choose for the source system
    schema: public         # the schema where the raw tables live
    tables:
      - name: customer
      - name: branch
      - name: product
      - name: account
      - name: card
      - name: hist_transactional
```

### 6.6 Write a staging model

One file per source table, named `stg_<table>.sql`. Example: [models/staging/stg_branch.sql](models/staging/stg_branch.sql)

```sql
{{ config(materialized = 'table') }}

WITH src AS (
    SELECT * FROM {{ source('crmuser', 'branch') }}
),

FINAL AS (
    SELECT
        branch_id,
        province,
        cluster_name,
        city_name,
        branch_name,
        CURRENT_TIMESTAMP AS created_date
    FROM src
)

SELECT * FROM FINAL
```

- `{{ source('crmuser', 'branch') }}` means "the raw table `public.branch`". Use `source()` to read **raw** tables.
- The file name becomes the table name: this creates `silver.stg_branch`.

### 6.7 Describe and test the model

Next to each `.sql` file add a `.yml` file with the same name. Example: [models/staging/stg_branch.yml](models/staging/stg_branch.yml)

```yaml
version: 2

models:
  - name: stg_branch
    description: One row per physical bank branch.
    columns:
      - name: branch_id
        description: Primary key.
        tests:
          - unique
          - not_null
```

dbt has four built-in tests, and this project uses all of them:

| Test | Checks that… | Example in this project |
| --- | --- | --- |
| `unique` | no value appears twice | `stg_customer.cust_id` |
| `not_null` | no value is empty | `stg_account.lchg_time` |
| `accepted_values` | every value is in an allowed list | `stg_account.schm_type` is one of SA, CA, FD, RD, LD |
| `relationships` | every value exists in another table (foreign key) | `stg_account.customer_id` exists in `stg_customer.cust_id` |

> The `.yml` files here write test settings under an `arguments:` key. That form needs dbt 1.10 or newer.

### 6.8 Write a mart model

Mart models read from staging models with `ref()`. Example: [models/marts/dim_product.sql](models/marts/dim_product.sql) starts with

```sql
SELECT * FROM {{ ref('stg_product') }}
```

`ref()` is the most important function in dbt. It does two things: it points to the right schema and table, and it tells dbt that `dim_product` depends on `stg_product`, so dbt always builds them in the right order.

**Rule of thumb:** `source()` for raw tables, `ref()` for anything dbt built.

### 6.9 Add a snapshot and a seed

- **Snapshot** — put a file in `snapshots/` (see [snapshots/dim_customer.sql](snapshots/dim_customer.sql)) and run `dbt snapshot`.
- **Seed** — put a small CSV file in `seeds/` and run `dbt seed`. The file name becomes the table name.

---

## 7. Running the project

`-s` (short for `--select`) chooses what to run. Without it, dbt runs everything.

### Models

```powershell
dbt run                          # all models
dbt run -s stg_customer          # one model
dbt run -s staging               # every model in the staging folder
dbt run -s marts                 # every model in the marts folder
dbt run -s +fct_casa_ratio       # the model and everything it depends on
dbt run -s stg_account+          # the model and everything that depends on it
dbt run -s stg_account --full-refresh   # rebuild an incremental model from zero
```

### Snapshot

```powershell
dbt snapshot -s dim_customer
```

Run `dbt run -s stg_customer` first, because the snapshot reads from `stg_customer`.

### Tests

```powershell
dbt test                         # all tests
dbt test -s stg_account          # only the tests of one model
```

### Seeds

```powershell
dbt seed                                   # all CSV files in seeds/
dbt seed -s currency_conversion_rates      # one seed
```

### Documentation

```powershell
dbt docs generate
dbt docs serve
```

This opens a website in your browser with every model, column description and a lineage graph showing how the tables depend on each other.

---

## 8. What each model does

### Staging (schema `silver`)

| Model | Reads from | How it is loaded | Notes |
| --- | --- | --- | --- |
| `stg_customer` | `public.customer` | Full rebuild (`table`) | Adds `created_date` |
| `stg_branch` | `public.branch` | Full rebuild (`table`) | Adds `created_date` |
| `stg_product` | `public.product` | Full rebuild (`table`) | Adds `created_date` |
| `stg_card` | `public.card` | Full rebuild (`table`) | Adds `created_date` |
| `stg_account` | `public.account` | Incremental **merge** on `account_id` | Picks up rows whose `lchg_time` is newer than the latest one already loaded |
| `stg_hist_transactional` | `public.hist_transactional` | Incremental **append** | Picks up rows whose `tran_date` is newer than the latest one already loaded |

### Marts (schema `gold`)

| Model | Type | What it gives you |
| --- | --- | --- |
| `dim_product` | Dimension | Products with readable labels: `product_category` (Savings Account, Loan, …), `product_group` (CASA / Term Deposit / Loan), `is_deposit_product`, `is_loan_product` |
| `dim_card` | Dimension | Cards joined to their account, so each card also carries `customer_id`, `branch_id`, `product_id`, plus an `is_expired` flag |
| `dim_customer` | Snapshot | Customers **with history**: a new row is added when a customer changes, with `dbt_valid_from` / `dbt_valid_to` dates |
| `fct_casa_ratio` | Fact / KPI | CASA ratio per branch, plus one `ALL_BRANCHES` row for the whole bank |
| `fct_loan_to_deposit_ratio` | Fact / KPI | Loan-to-deposit ratio per branch, plus one `ALL_BRANCHES` row |
| `currency_conversion_rates` | Seed | 166 currencies with their rate to USD and NPR. Reference data; not used by a model yet |

### The two KPIs in plain language

Both KPIs only count **open** accounts (`acct_cls_flg = 'N'`).

**CASA ratio** — how much of a bank's deposits sit in current and savings accounts.

```text
CASA ratio = (current account balance + savings account balance) / total deposits
```

Current and savings accounts pay little or no interest, so a higher CASA ratio means the bank gets its money more cheaply.

**Loan-to-deposit ratio** — how much of the deposited money the bank has lent out.

```text
Loan-to-deposit ratio = total loans outstanding / total deposits
```

A very high ratio means the bank may run short of cash; a very low one means it is not earning much from lending. Loan balances are stored as negative numbers, so the model flips the sign before adding them up.

> Both KPIs add up balances as they are, without converting currencies. A good exercise is to convert every balance to NPR first, using the `currency_conversion_rates` seed.

---

## 9. Load patterns used in this project

A **materialization** is how dbt saves the result of your `SELECT` in the database.

| Pattern | Used by | What happens on every run | Use it when… |
| --- | --- | --- | --- |
| **Full load** (`table`) | `stg_customer`, `stg_branch`, `stg_product`, `stg_card`, all marts | The table is dropped and rebuilt from all the data | The table is small |
| **Incremental — merge** | `stg_account` | Only new or changed rows are read. Existing rows are **updated**, new rows are **inserted**, matched on `unique_key` | Rows can change after they are created (an account balance) |
| **Incremental — append** | `stg_hist_transactional` | Only new rows are read and **added** at the end. Nothing is updated | Rows never change once written (transactions, logs) |
| **Snapshot** (SCD Type 2) | `dim_customer` | Changed rows get a **new version**; the old version is kept and closed with an end date | You need to know what a record looked like in the past |

How an incremental model works ([stg_account.sql](models/staging/stg_account.sql)):

```sql
{{ config(
    materialized = 'incremental',
    unique_key = 'account_id',
    incremental_strategy = 'merge'
) }}

SELECT * FROM {{ source('crmuser', 'account') }}

{% if is_incremental() %}
WHERE lchg_time > (SELECT MAX(lchg_time) FROM {{ this }})
{% endif %}
```

- On the **first** run the table does not exist yet, so the `WHERE` is skipped and everything is loaded.
- On **later** runs `is_incremental()` is true, so only rows newer than what is already loaded are read. `{{ this }}` means "the table this model has already built".
- `--full-refresh` forces a complete rebuild.

More background: [load_patterns_full_incremental_merge_append.pdf](SQL%20FILES/load_patterns_full_incremental_merge_append.pdf).

> **Good to know about the snapshot.** `dim_customer` uses the `timestamp` strategy with `updated_at = 'created_date'`. In `stg_customer`, `created_date` is the time the table was built, so every time you rebuild `stg_customer` and run the snapshot again, **every** customer gets a new version, not only the changed ones. To version only real changes, switch the snapshot to `strategy = 'check'` with a `check_cols` list, or use a genuine "last updated" column from the source.

---

## 10. Practice: see incremental loads and snapshots in action

The three numbered files in [SQL FILES/](SQL%20FILES/) simulate "the next day" at the bank. Run them **in order** in your SQL client (pgAdmin, DBeaver or `psql`) after you have done a first full `dbt build`.

| Step | Run this SQL file in PostgreSQL | Then run in dbt | What to look for |
| --- | --- | --- | --- |
| 1 | `1_insert_new_customer.sql` — adds customer `C0051` | `dbt run -s stg_customer` then `dbt snapshot -s dim_customer` | `silver.stg_customer` has 51 rows; `C0051` appears in `gold.dim_customer` |
| 2 | `2_update_and_insert_account.sql` — changes the balance of `AC000001`, adds `AC000151` and `AC000152` | `dbt run -s stg_account` | `silver.stg_account` has 152 rows; `AC000001` was **updated**, not duplicated (merge) |
| 3 | `3_insert_new_hist_transactional.sql` — adds 4 transactions | `dbt run -s stg_hist_transactional` | `silver.stg_hist_transactional` grows from 400 to 404 rows (append) |

> **Important for step 2.** A fresh load sets every account's `lchg_time` to the moment you loaded the data. File 2 uses the fixed date `2026-09-21`. If you loaded your data after that date, the new rows look "older" than what is already in `stg_account` and the incremental filter skips them. Before running file 2, replace `'2026-09-21 00:00:00'` with `CURRENT_TIMESTAMP` (three places).

Useful checks:

```sql
SELECT COUNT(*) FROM silver.stg_account;
SELECT account_id, account_balance, lchg_time FROM silver.stg_account WHERE account_id = 'AC000001';
SELECT cust_id, name, dbt_valid_from, dbt_valid_to FROM gold.dim_customer WHERE cust_id = 'C0051';
```

In a snapshot table, the row with `dbt_valid_to` empty (`NULL`) is the current version.

---

## 11. Command cheat sheet

| Command | What it does |
| --- | --- |
| `dbt --version` | Shows the installed dbt and adapter versions |
| `dbt init <project_name>` | Creates a new dbt project |
| `dbt debug` | Tests the database connection and project setup |
| `dbt seed` | Loads CSV files from `seeds/` |
| `dbt run` | Builds models |
| `dbt snapshot` | Builds / updates snapshots |
| `dbt test` | Runs data tests |
| `dbt build` | seed + run + snapshot + test, in dependency order |
| `dbt run -s <model>` | Builds one model |
| `dbt run -s +<model>` | Builds a model and everything before it |
| `dbt run -s <model>+` | Builds a model and everything after it |
| `dbt run --full-refresh` | Rebuilds incremental models from zero |
| `dbt compile` | Writes the final SQL into `target/compiled/` without running it |
| `dbt ls` | Lists everything in the project |
| `dbt docs generate` / `dbt docs serve` | Builds and opens the documentation website |
| `dbt clean` | Deletes the `target/` and `dbt_packages/` folders |

---

## 12. Troubleshooting

| Problem | Likely cause and fix |
| --- | --- |
| `dbt : The term 'dbt' is not recognized` | The virtual environment is not active. Activate it (section 5, step 2). |
| `running scripts is disabled on this system` | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once, then activate again. |
| `Could not find profile named 'sanima_bank'` | The top-level name in `profiles.yml` must match `profile:` in `dbt_project.yml`, and you must run dbt from the project folder. |
| `password authentication failed` / `connection refused` | Wrong details in `profiles.yml`, or PostgreSQL is not running. Check with `dbt debug`. |
| `relation "public.customer" does not exist` | The raw data is not loaded. Run the Python script (section 5, step 4). |
| Tables appear in `public_silver` instead of `silver` | The `generate_schema_name` macro is missing (section 6.4). |
| `relation "silver.stg_customer" does not exist` during `dbt snapshot` | Run `dbt run -s stg_customer` before the snapshot. |
| An incremental model does not pick up new rows | The new rows have a date that is not newer than the latest date already loaded (see the note in section 10), or run with `--full-refresh`. |
| `merge` strategy error on `stg_account` | Your PostgreSQL is older than version 15. Upgrade, or change the strategy to `delete+insert`. |
| A test fails | Open the file path shown in the error under `target/compiled/` and run that SQL in your SQL client: it returns the rows that broke the rule. |

---

## 13. Glossary

| Term | Meaning |
| --- | --- |
| **Adapter** | The plugin that connects dbt to one type of database (`dbt-postgres`, `dbt-oracle`, …) |
| **Model** | A `.sql` file containing one `SELECT`. dbt turns it into a table or view |
| **Source** | A raw table that dbt reads but did not create |
| **`ref()`** | Refers to another model and creates the dependency between them |
| **`source()`** | Refers to a raw table declared in `sources.yml` |
| **Materialization** | How a model is stored: `table`, `view`, `incremental`, … |
| **Seed** | A small CSV file that dbt loads as a table |
| **Snapshot** | A table that keeps old versions of rows when they change |
| **SCD Type 2** | "Slowly changing dimension type 2": keep history by adding a new row for each change |
| **Macro** | A reusable piece of code written in Jinja (the `{{ ... }}` and `{% ... %}` syntax) |
| **Profile** | The database connection settings in `profiles.yml` |
| **Target** | The environment dbt is building into (here: `dev`) |
| **Lineage / DAG** | The map of which model depends on which |
| **Staging / silver** | Cleaned copies of the raw tables |
| **Marts / gold** | Final tables built for reporting and analysis |
| **Dimension (`dim_`)** | A table describing things: customers, products, cards |
| **Fact (`fct_`)** | A table of measurements or KPIs: balances, ratios |
