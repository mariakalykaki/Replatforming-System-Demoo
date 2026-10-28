
CREATE TABLE na_config (
    config_key    VARCHAR2(40) PRIMARY KEY,
    config_value  VARCHAR2(100) NOT NULL,
    description   VARCHAR2(200)
);

CREATE TABLE na_customers (
    customer_id          VARCHAR2(20) PRIMARY KEY,
    name                 VARCHAR2(100) NOT NULL,
    outstanding_balance  NUMBER(10,2) DEFAULT 0 NOT NULL,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE na_number_ranges (
    prefix       VARCHAR2(20) PRIMARY KEY,
    range_code   VARCHAR2(10) NOT NULL CHECK (range_code IN ('STANDARD', 'PREMIUM')),
    description  VARCHAR2(100)
);

CREATE TABLE na_number_pool (
    msisdn          VARCHAR2(20) PRIMARY KEY,
    status          VARCHAR2(10) DEFAULT 'AVAILABLE' NOT NULL
                        CHECK (status IN ('AVAILABLE', 'RESERVED', 'ACTIVE')),
    reserved_by_id  NUMBER,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE na_risk_factors (
    factor_code  VARCHAR2(10) PRIMARY KEY,
    description  VARCHAR2(200) NOT NULL,
    points       NUMBER NOT NULL,
    active_flag  VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N'))
);

CREATE TABLE na_timer_types (
    timer_code        VARCHAR2(30) PRIMARY KEY,
    description       VARCHAR2(200) NOT NULL,
    duration_seconds  NUMBER NOT NULL,
    fires_event       VARCHAR2(40) NOT NULL
);

CREATE TABLE na_notification_types (
    notification_code  VARCHAR2(40) PRIMARY KEY,
    audience           VARCHAR2(10) NOT NULL CHECK (audience IN ('CUSTOMER', 'OPERATIONS', 'CARRIER')),
    channel            VARCHAR2(10) NOT NULL CHECK (channel IN ('SMS', 'EMAIL', 'LOG', 'REST')),
    description        VARCHAR2(200)
);
