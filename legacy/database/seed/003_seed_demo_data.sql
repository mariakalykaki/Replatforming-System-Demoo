
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1001', 'Clean Long-Standing',   0,     SYSTIMESTAMP - NUMTODSINTERVAL(400, 'DAY'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1002', 'Owes Money',            25.00, SYSTIMESTAMP - NUMTODSINTERVAL(400, 'DAY'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1003', 'At Line Limit',         0,     SYSTIMESTAMP - NUMTODSINTERVAL(400, 'DAY'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1004', 'High Velocity',         0,     SYSTIMESTAMP - NUMTODSINTERVAL(400, 'DAY'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1005', 'Brand New Account',     0,     SYSTIMESTAMP - NUMTODSINTERVAL(1, 'DAY'));

INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at)
    SELECT 'C-' || (1005 + LEVEL), 'Clean Spare ' || LEVEL, 0, SYSTIMESTAMP - NUMTODSINTERVAL(400, 'DAY')
      FROM dual CONNECT BY LEVEL <= 6;

INSERT INTO na_number_pool (msisdn) SELECT '+3069000001' || LPAD(LEVEL, 2, '0') FROM dual CONNECT BY LEVEL <= 20;
INSERT INTO na_number_pool (msisdn) VALUES ('+306900000150');
INSERT INTO na_number_pool (msisdn) VALUES ('+306900000199');
INSERT INTO na_number_pool (msisdn) VALUES ('+306900000100');
INSERT INTO na_number_pool (msisdn) SELECT '+30699800000' || LEVEL FROM dual CONNECT BY LEVEL <= 3;

INSERT INTO na_number_pool (msisdn, status) SELECT '+30690000020' || LEVEL, 'ACTIVE' FROM dual CONNECT BY LEVEL <= 5;
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at)
    SELECT '+30690000020' || LEVEL, 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(30, 'DAY')
      FROM dual CONNECT BY LEVEL <= 5;
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at)
    SELECT '+30690000030' || LEVEL, 'C-1004', 'POSTPAID', 'Y', 'PRO', 'CANCELLED', SYSTIMESTAMP - NUMTODSINTERVAL(2, 'HOUR')
      FROM dual CONNECT BY LEVEL <= 3;

COMMIT;
EXIT;
