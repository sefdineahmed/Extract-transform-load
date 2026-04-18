-- ------------------------------------------------------
-- Remplir dim_time (générer toutes les dates de 2024 à 2025)
-- ------------------------------------------------------
INSERT INTO dim_time (full_date, year, quarter, month, month_name, day, day_of_week, day_name, week_of_year, is_weekend)
WITH RECURSIVE dates AS (
    SELECT DATE('2024-01-01') AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM dates WHERE dt < '2025-12-31'
)
SELECT 
    dt,
    YEAR(dt),
    QUARTER(dt),
    MONTH(dt),
    MONTHNAME(dt),
    DAY(dt),
    WEEKDAY(dt) + 1,  -- 1=Monday, 7=Sunday
    DAYNAME(dt),
    WEEK(dt, 1),
    CASE WHEN WEEKDAY(dt) IN (5,6) THEN TRUE ELSE FALSE END
FROM dates;

-- ------------------------------------------------------
-- Remplir dim_user depuis la table source users
-- ------------------------------------------------------
INSERT INTO dim_user (user_id, full_name, phone_number, registration_date, status, kyc_level, city, age_group)
SELECT 
    user_id,
    full_name,
    phone_number,
    registration_date,
    status,
    kyc_level,
    city,
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) < 25 THEN '18-24'
        WHEN TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) BETWEEN 25 AND 34 THEN '25-34'
        WHEN TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) BETWEEN 35 AND 49 THEN '35-49'
        ELSE '50+'
    END
FROM fintech_source.users;

-- ------------------------------------------------------
-- Remplir dim_account
-- ------------------------------------------------------
INSERT INTO dim_account (account_id, user_id, account_type, currency, opening_date, is_active)
SELECT 
    account_id,
    user_id,
    account_type,
    currency,
    opening_date,
    is_active
FROM fintech_source.accounts;

-- ------------------------------------------------------
-- Remplir fact_transaction (avec indicateur de qualité)
-- ------------------------------------------------------
INSERT INTO fact_transaction (
    transaction_id, time_id, account_source_id, account_dest_id, transaction_type_id,
    amount, status, failure_reason, device_id, location, is_fraud_suspected, quality_flag
)
SELECT 
    t.transaction_id,
    dt.time_id,
    t.account_source_id,
    t.account_dest_id,
    ttype.type_id,
    t.amount,
    t.status,
    t.failure_reason,
    t.device_id,
    t.location,
    CASE WHEN fa.alert_id IS NOT NULL THEN TRUE ELSE FALSE END,
    CASE WHEN t.amount > 0 THEN TRUE ELSE FALSE END AS quality_flag
FROM fintech_source.transactions t
JOIN dim_time dt ON dt.full_date = DATE(t.transaction_date)
JOIN dim_transaction_type ttype ON ttype.type_code = t.transaction_type
LEFT JOIN fintech_source.fraud_alerts fa ON fa.transaction_id = t.transaction_id;

-- ------------------------------------------------------
-- Remplir fact_daily_balance (si vous avez généré les snapshots)
-- ------------------------------------------------------
INSERT INTO fact_daily_balance (snapshot_id, time_id, account_id, closing_balance)
SELECT 
    s.snapshot_id,
    dt.time_id,
    s.account_id,
    s.closing_balance
FROM fintech_source.daily_balance_snapshot s
JOIN dim_time dt ON dt.full_date = s.snapshot_date;
