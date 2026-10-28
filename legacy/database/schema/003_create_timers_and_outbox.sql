
CREATE TABLE na_timers (
    id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activation_id  NUMBER NOT NULL REFERENCES na_activations (id),
    timer_code     VARCHAR2(30) NOT NULL REFERENCES na_timer_types (timer_code),
    due_at         TIMESTAMP WITH TIME ZONE NOT NULL,
    status         VARCHAR2(10) DEFAULT 'PENDING' NOT NULL
                       CHECK (status IN ('PENDING', 'FIRED', 'CANCELLED', 'FAILED')),
    fired_at       TIMESTAMP WITH TIME ZONE,
    error_message  VARCHAR2(400)
);

CREATE INDEX ix_na_timers_due ON na_timers (status, due_at);

CREATE TABLE na_outbox (
    id                 NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activation_id      NUMBER NOT NULL REFERENCES na_activations (id),
    notification_code  VARCHAR2(40) NOT NULL REFERENCES na_notification_types (notification_code),
    payload            VARCHAR2(1000) NOT NULL,
    status             VARCHAR2(10) DEFAULT 'PENDING' NOT NULL
                           CHECK (status IN ('PENDING', 'IN_FLIGHT', 'PUBLISHED', 'FAILED')),
    attempts           NUMBER DEFAULT 0 NOT NULL,
    error_message      VARCHAR2(400),
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    published_at       TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_na_outbox_pending ON na_outbox (status, id);
