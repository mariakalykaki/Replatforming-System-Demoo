
CREATE TABLE na_activations (
    id                 NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    msisdn             VARCHAR2(30) NOT NULL,
    customer_id        VARCHAR2(20) NOT NULL REFERENCES na_customers (customer_id),
    customer_type      VARCHAR2(10) NOT NULL CHECK (customer_type IN ('PREPAID', 'POSTPAID')),
    id_verified        VARCHAR2(1) NOT NULL CHECK (id_verified IN ('Y', 'N')),
    plan_code          VARCHAR2(20) NOT NULL,
    status             VARCHAR2(20) DEFAULT 'REQUESTED' NOT NULL CHECK (status IN (
                           'REQUESTED', 'ELIGIBLE', 'MANUAL_REVIEW', 'ALLOCATING',
                           'AWAITING_ACTIVATION', 'ACTIVE',
                           'REJECTED', 'EXPIRED', 'FAILED', 'CANCELLED'
                       )),
    rejection_reasons  VARCHAR2(200),
    risk_score         NUMBER,
    risk_factors       VARCHAR2(100),
    risk_decision      VARCHAR2(15) CHECK (risk_decision IN ('AUTO_APPROVE', 'MANUAL_REVIEW', 'REJECT')),
    escalated_flag     VARCHAR2(1) DEFAULT 'N' NOT NULL CHECK (escalated_flag IN ('Y', 'N')),
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX ix_na_act_customer ON na_activations (customer_id, created_at);
CREATE INDEX ix_na_act_msisdn   ON na_activations (msisdn);

ALTER TABLE na_number_pool
    ADD CONSTRAINT fk_na_pool_reserved_by FOREIGN KEY (reserved_by_id) REFERENCES na_activations (id);

CREATE TABLE na_conditions (
    condition_name  VARCHAR2(40) PRIMARY KEY,
    description     VARCHAR2(200) NOT NULL
);

CREATE TABLE na_workflow_action_types (
    action_type  VARCHAR2(40) PRIMARY KEY,
    description  VARCHAR2(200) NOT NULL
);

CREATE TABLE na_workflow_branches (
    id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status           VARCHAR2(20) NOT NULL,
    event_type       VARCHAR2(40) NOT NULL,
    branch_sequence  NUMBER NOT NULL,
    condition_name   VARCHAR2(40) REFERENCES na_conditions (condition_name),
    description      VARCHAR2(200),
    CONSTRAINT uq_na_branch UNIQUE (status, event_type, branch_sequence)
);

CREATE TABLE na_workflow_actions (
    id                NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id         NUMBER NOT NULL REFERENCES na_workflow_branches (id),
    action_sequence   NUMBER NOT NULL,
    action_type       VARCHAR2(40) NOT NULL REFERENCES na_workflow_action_types (action_type),
    action_parameter  VARCHAR2(60),
    CONSTRAINT uq_na_action UNIQUE (branch_id, action_sequence)
);

CREATE TABLE na_audit_log (
    id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activation_id NUMBER NOT NULL REFERENCES na_activations (id),
    event_type    VARCHAR2(40) NOT NULL,
    from_status   VARCHAR2(20) NOT NULL,
    to_status     VARCHAR2(20) NOT NULL,
    branch_id     NUMBER REFERENCES na_workflow_branches (id),
    detail        VARCHAR2(400),
    occurred_at   TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX ix_na_audit_activation ON na_audit_log (activation_id, occurred_at);
