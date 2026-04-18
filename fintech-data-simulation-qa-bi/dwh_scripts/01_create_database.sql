-- ======================================================
-- Base de données cible : fintech_dwh
-- Schéma en étoile : 1 table de faits + 4 dimensions
-- ======================================================

CREATE DATABASE IF NOT EXISTS fintech_dwh;
USE fintech_dwh;

-- ------------------------------------------------------
-- 1. Dimension Temps (Time)
-- ------------------------------------------------------
CREATE TABLE dim_time (
    time_id INT PRIMARY KEY AUTO_INCREMENT,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20),
    day INT NOT NULL,
    day_of_week INT,
    day_name VARCHAR(20),
    week_of_year INT,
    is_weekend BOOLEAN
);

-- ------------------------------------------------------
-- 2. Dimension Utilisateur (User)
-- ------------------------------------------------------
CREATE TABLE dim_user (
    user_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    phone_number VARCHAR(20),
    registration_date DATE,
    status VARCHAR(20),          -- active, inactive, suspended
    kyc_level INT,
    city VARCHAR(50),
    age_group VARCHAR(20)        -- calculé à partir de date_of_birth
);

-- ------------------------------------------------------
-- 3. Dimension Compte (Account)
-- ------------------------------------------------------
CREATE TABLE dim_account (
    account_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    account_type VARCHAR(20),    -- principal, savings, merchant, salary
    currency VARCHAR(3),
    opening_date DATE,
    is_active BOOLEAN,
    FOREIGN KEY (user_id) REFERENCES dim_user(user_id)
);

-- ------------------------------------------------------
-- 4. Dimension Transaction Type (optionnel, pour clarté)
-- ------------------------------------------------------
CREATE TABLE dim_transaction_type (
    type_id INT PRIMARY KEY AUTO_INCREMENT,
    type_code VARCHAR(30),       -- transfer, cash_in, cash_out, payment, airtime_purchase
    type_label VARCHAR(50)
);

INSERT INTO dim_transaction_type (type_code, type_label) VALUES
('transfer', 'Virement entre comptes'),
('cash_in', 'Dépôt d’argent'),
('cash_out', 'Retrait d’argent'),
('payment', 'Paiement marchand'),
('airtime_purchase', 'Achat de crédit téléphonique');

-- ------------------------------------------------------
-- 5. Table de Faits : Transactions
-- ------------------------------------------------------
CREATE TABLE fact_transaction (
    transaction_id INT PRIMARY KEY,
    time_id INT NOT NULL,                -- clé étrangère vers dim_time
    account_source_id INT NOT NULL,      -- clé étrangère vers dim_account
    account_dest_id INT NOT NULL,
    transaction_type_id INT NOT NULL,
    amount DECIMAL(15,2),
    status VARCHAR(20),                  -- completed, pending, failed, reversed
    failure_reason VARCHAR(50),
    device_id VARCHAR(100),
    location VARCHAR(50),
    is_fraud_suspected BOOLEAN DEFAULT FALSE,
    quality_flag BOOLEAN DEFAULT TRUE,   -- TRUE = donnée valide, FALSE = anomalie (montant négatif, etc.)
    FOREIGN KEY (time_id) REFERENCES dim_time(time_id),
    FOREIGN KEY (account_source_id) REFERENCES dim_account(account_id),
    FOREIGN KEY (account_dest_id) REFERENCES dim_account(account_id),
    FOREIGN KEY (transaction_type_id) REFERENCES dim_transaction_type(type_id)
);

-- ------------------------------------------------------
-- 6. Table de Faits secondaire : Soldes journaliers (optionnelle)
-- ------------------------------------------------------
CREATE TABLE fact_daily_balance (
    snapshot_id INT PRIMARY KEY,
    time_id INT NOT NULL,
    account_id INT NOT NULL,
    closing_balance DECIMAL(15,2),
    FOREIGN KEY (time_id) REFERENCES dim_time(time_id),
    FOREIGN KEY (account_id) REFERENCES dim_account(account_id)
);

-- ======================================================
-- Index pour les performances
-- ======================================================
CREATE INDEX idx_fact_transaction_time ON fact_transaction(time_id);
CREATE INDEX idx_fact_transaction_source ON fact_transaction(account_source_id);
CREATE INDEX idx_fact_transaction_dest ON fact_transaction(account_dest_id);
CREATE INDEX idx_fact_balance_time ON fact_daily_balance(time_id);
CREATE INDEX idx_fact_balance_account ON fact_daily_balance(account_id);
CREATE INDEX idx_dim_user_status ON dim_user(status);
CREATE INDEX idx_dim_account_user ON dim_account(user_id);
