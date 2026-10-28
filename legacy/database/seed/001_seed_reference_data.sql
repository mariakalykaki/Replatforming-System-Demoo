
INSERT INTO na_config (config_key, config_value, description) VALUES ('MAX_ACTIVE_LINES', '5', 'E4: customer may not exceed this many ACTIVE lines');
INSERT INTO na_config (config_key, config_value, description) VALUES ('VELOCITY_LIMIT', '3', 'R1: requests in the window that trigger the factor');
INSERT INTO na_config (config_key, config_value, description) VALUES ('VELOCITY_WINDOW_HOURS', '24', 'R1: velocity window');
INSERT INTO na_config (config_key, config_value, description) VALUES ('NEW_ACCOUNT_DAYS', '7', 'R2: accounts younger than this are "new"');
INSERT INTO na_config (config_key, config_value, description) VALUES ('RISK_MANUAL_REVIEW_MIN', '30', 'Score at or above this goes to MANUAL_REVIEW');
INSERT INTO na_config (config_key, config_value, description) VALUES ('RISK_REJECT_MIN', '70', 'Score at or above this is REJECTED');

INSERT INTO na_number_ranges (prefix, range_code, description) VALUES ('+30690', 'STANDARD', 'Greek mobile range (690)');
INSERT INTO na_number_ranges (prefix, range_code, description) VALUES ('+30699', 'PREMIUM',  'Greek premium / high-risk range (699)');

INSERT INTO na_risk_factors (factor_code, description, points) VALUES ('R1', 'Customer made 3 or more requests in the last 24h', 40);
INSERT INTO na_risk_factors (factor_code, description, points) VALUES ('R2', 'Customer account created less than 7 days ago', 20);
INSERT INTO na_risk_factors (factor_code, description, points) VALUES ('R3', 'Number is in a premium / high-risk range', 20);
INSERT INTO na_risk_factors (factor_code, description, points) VALUES ('R4', 'Prepaid customer without verified ID', 30);

INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('REVIEW_ESCALATION', 'T1: manual review escalation', 15, 'REVIEW_TIMER_ESCALATE');
INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('REVIEW_EXPIRY',     'T2: manual review expiry',     30, 'REVIEW_TIMER_EXPIRED');
INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('ACTIVATION_WINDOW', 'T3: customer SIM activation window', 45, 'ACTIVATION_TIMER_EXPIRED');

INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ALLOCATE_NUMBER',          'CARRIER',    'REST',  'Ask the carrier to allocate the number');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_UNDER_REVIEW', 'CUSTOMER',   'SMS',   'Request needs a manual check');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('MANUAL_REVIEW_REQUIRED',  'OPERATIONS', 'LOG',   'Review queue item');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('REVIEW_ESCALATED',        'OPERATIONS', 'LOG',   'Review not actioned in time');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('NUMBER_ALLOCATED',        'CUSTOMER',   'SMS',   'Number allocated, please confirm SIM activation');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_COMPLETE',     'CUSTOMER',   'SMS',   'Number is live');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_REJECTED',     'CUSTOMER',   'EMAIL', 'Request rejected');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_FAILED',       'CUSTOMER',   'EMAIL', 'Allocation failed');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_FAILED_OPS',   'OPERATIONS', 'LOG',   'Allocation failed - investigate');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_EXPIRED',      'CUSTOMER',   'SMS',   'Request expired');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_CANCELLED',    'CUSTOMER',   'EMAIL', 'Request cancelled');

COMMIT;
EXIT;
