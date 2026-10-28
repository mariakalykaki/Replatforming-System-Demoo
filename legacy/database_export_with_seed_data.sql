-- ============================================================
-- Live export of the NA_APP schema PLUS reference/config seed
-- data and the demo customers/numbers, from the running Oracle database - extracted via
-- DBMS_METADATA/direct queries, not reconstructed from the
-- repo's own migration scripts.
--
-- Seed data here is reference/config data (config, number ranges,
-- risk factors, timer durations, notification types, workflow
-- rules) plus the demo customers C-1001..C-1011, the demo number
-- pool (reset to AVAILABLE, except the five ACTIVE lines of
-- C-1003) and the historic activations from
-- database/seed/003_seed_demo_data.sql. It deliberately excludes
-- transactional data (other activations, audit log, outbox rows,
-- timers) accumulated from live/test usage.
--
-- Table/column comments and in-source package comments are
-- stripped (structure only). Identity-column sequences are
-- omitted (embedded inline in each table's identity column).
-- ============================================================

--
-- TABLES
--


  CREATE TABLE "NA_APP"."NA_CONDITIONS" 
   (	"CONDITION_NAME" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	 PRIMARY KEY ("CONDITION_NAME")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_CONFIG" 
   (	"CONFIG_KEY" VARCHAR2(40), 
	"CONFIG_VALUE" VARCHAR2(100) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(200), 
	 PRIMARY KEY ("CONFIG_KEY")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_CUSTOMERS" 
   (	"CUSTOMER_ID" VARCHAR2(20), 
	"NAME" VARCHAR2(100) NOT NULL ENABLE, 
	"OUTSTANDING_BALANCE" NUMBER(10,2) DEFAULT 0 NOT NULL ENABLE, 
	"CREATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	 PRIMARY KEY ("CUSTOMER_ID")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_NOTIFICATION_TYPES" 
   (	"NOTIFICATION_CODE" VARCHAR2(40), 
	"AUDIENCE" VARCHAR2(10) NOT NULL ENABLE, 
	"CHANNEL" VARCHAR2(10) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(200), 
	 CHECK (audience IN ('CUSTOMER', 'OPERATIONS', 'CARRIER')) ENABLE, 
	 CHECK (channel IN ('SMS', 'EMAIL', 'LOG', 'REST')) ENABLE, 
	 PRIMARY KEY ("NOTIFICATION_CODE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_NUMBER_RANGES" 
   (	"PREFIX" VARCHAR2(20), 
	"RANGE_CODE" VARCHAR2(10) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(100), 
	 CHECK (range_code IN ('STANDARD', 'PREMIUM')) ENABLE, 
	 PRIMARY KEY ("PREFIX")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_RISK_FACTORS" 
   (	"FACTOR_CODE" VARCHAR2(10), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	"POINTS" NUMBER NOT NULL ENABLE, 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("FACTOR_CODE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_TIMER_TYPES" 
   (	"TIMER_CODE" VARCHAR2(30), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	"DURATION_SECONDS" NUMBER NOT NULL ENABLE, 
	"FIRES_EVENT" VARCHAR2(40) NOT NULL ENABLE, 
	 PRIMARY KEY ("TIMER_CODE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_WORKFLOW_ACTION_TYPES" 
   (	"ACTION_TYPE" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	 PRIMARY KEY ("ACTION_TYPE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_WORKFLOW_BRANCHES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"EVENT_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"BRANCH_SEQUENCE" NUMBER NOT NULL ENABLE, 
	"CONDITION_NAME" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200), 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "UQ_NA_BRANCH" UNIQUE ("STATUS", "EVENT_TYPE", "BRANCH_SEQUENCE")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("CONDITION_NAME")
	  REFERENCES "NA_APP"."NA_CONDITIONS" ("CONDITION_NAME") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_ACTIVATIONS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"MSISDN" VARCHAR2(30) NOT NULL ENABLE, 
	"CUSTOMER_ID" VARCHAR2(20) NOT NULL ENABLE, 
	"CUSTOMER_TYPE" VARCHAR2(10) NOT NULL ENABLE, 
	"ID_VERIFIED" VARCHAR2(1) NOT NULL ENABLE, 
	"PLAN_CODE" VARCHAR2(20) NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) DEFAULT 'REQUESTED' NOT NULL ENABLE, 
	"REJECTION_REASONS" VARCHAR2(200), 
	"RISK_SCORE" NUMBER, 
	"RISK_FACTORS" VARCHAR2(100), 
	"RISK_DECISION" VARCHAR2(15), 
	"ESCALATED_FLAG" VARCHAR2(1) DEFAULT 'N' NOT NULL ENABLE, 
	"CREATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	"UPDATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	 CHECK (customer_type IN ('PREPAID', 'POSTPAID')) ENABLE, 
	 CHECK (id_verified IN ('Y', 'N')) ENABLE, 
	 CHECK (status IN (
			   'REQUESTED', 'ELIGIBLE', 'MANUAL_REVIEW', 'ALLOCATING',
			   'AWAITING_ACTIVATION', 'ACTIVE',
			   'REJECTED', 'EXPIRED', 'FAILED', 'CANCELLED'
		       )) ENABLE, 
	 CHECK (risk_decision IN ('AUTO_APPROVE', 'MANUAL_REVIEW', 'REJECT')) ENABLE, 
	 CHECK (escalated_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("CUSTOMER_ID")
	  REFERENCES "NA_APP"."NA_CUSTOMERS" ("CUSTOMER_ID") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_AUDIT_LOG" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"ACTIVATION_ID" NUMBER NOT NULL ENABLE, 
	"EVENT_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"FROM_STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"TO_STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"BRANCH_ID" NUMBER, 
	"DETAIL" VARCHAR2(400), 
	"OCCURRED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("ACTIVATION_ID")
	  REFERENCES "NA_APP"."NA_ACTIVATIONS" ("ID") ENABLE, 
	 FOREIGN KEY ("BRANCH_ID")
	  REFERENCES "NA_APP"."NA_WORKFLOW_BRANCHES" ("ID") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_NUMBER_POOL" 
   (	"MSISDN" VARCHAR2(20), 
	"STATUS" VARCHAR2(10) DEFAULT 'AVAILABLE' NOT NULL ENABLE, 
	"RESERVED_BY_ID" NUMBER, 
	"UPDATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	 CHECK (status IN ('AVAILABLE', 'RESERVED', 'ACTIVE')) ENABLE, 
	 PRIMARY KEY ("MSISDN")
  USING INDEX  ENABLE, 
	 CONSTRAINT "FK_NA_POOL_RESERVED_BY" FOREIGN KEY ("RESERVED_BY_ID")
	  REFERENCES "NA_APP"."NA_ACTIVATIONS" ("ID") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_OUTBOX" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"ACTIVATION_ID" NUMBER NOT NULL ENABLE, 
	"NOTIFICATION_CODE" VARCHAR2(40) NOT NULL ENABLE, 
	"PAYLOAD" VARCHAR2(1000) NOT NULL ENABLE, 
	"STATUS" VARCHAR2(10) DEFAULT 'PENDING' NOT NULL ENABLE, 
	"ATTEMPTS" NUMBER DEFAULT 0 NOT NULL ENABLE, 
	"ERROR_MESSAGE" VARCHAR2(400), 
	"CREATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	"PUBLISHED_AT" TIMESTAMP (6) WITH TIME ZONE, 
	 CHECK (status IN ('PENDING', 'IN_FLIGHT', 'PUBLISHED', 'FAILED')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("ACTIVATION_ID")
	  REFERENCES "NA_APP"."NA_ACTIVATIONS" ("ID") ENABLE, 
	 FOREIGN KEY ("NOTIFICATION_CODE")
	  REFERENCES "NA_APP"."NA_NOTIFICATION_TYPES" ("NOTIFICATION_CODE") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_TIMERS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"ACTIVATION_ID" NUMBER NOT NULL ENABLE, 
	"TIMER_CODE" VARCHAR2(30) NOT NULL ENABLE, 
	"DUE_AT" TIMESTAMP (6) WITH TIME ZONE NOT NULL ENABLE, 
	"STATUS" VARCHAR2(10) DEFAULT 'PENDING' NOT NULL ENABLE, 
	"FIRED_AT" TIMESTAMP (6) WITH TIME ZONE, 
	"ERROR_MESSAGE" VARCHAR2(400), 
	 CHECK (status IN ('PENDING', 'FIRED', 'CANCELLED', 'FAILED')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("ACTIVATION_ID")
	  REFERENCES "NA_APP"."NA_ACTIVATIONS" ("ID") ENABLE, 
	 FOREIGN KEY ("TIMER_CODE")
	  REFERENCES "NA_APP"."NA_TIMER_TYPES" ("TIMER_CODE") ENABLE
   ) ;

  CREATE TABLE "NA_APP"."NA_WORKFLOW_ACTIONS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER	NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"BRANCH_ID" NUMBER NOT NULL ENABLE, 
	"ACTION_SEQUENCE" NUMBER NOT NULL ENABLE, 
	"ACTION_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"ACTION_PARAMETER" VARCHAR2(60), 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "UQ_NA_ACTION" UNIQUE ("BRANCH_ID", "ACTION_SEQUENCE")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("BRANCH_ID")
	  REFERENCES "NA_APP"."NA_WORKFLOW_BRANCHES" ("ID") ENABLE, 
	 FOREIGN KEY ("ACTION_TYPE")
	  REFERENCES "NA_APP"."NA_WORKFLOW_ACTION_TYPES" ("ACTION_TYPE") ENABLE
   ) ;
--
-- SEED DATA (reference/config tables plus demo customers, numbers and history - see header)
--
INSERT INTO na_config (config_key, config_value, description) VALUES ('MAX_ACTIVE_LINES', '5', 'E4: customer may not exceed this many ACTIVE lines');
INSERT INTO na_config (config_key, config_value, description) VALUES ('NEW_ACCOUNT_DAYS', '7', 'R2: accounts younger than this are "new"');
INSERT INTO na_config (config_key, config_value, description) VALUES ('RISK_MANUAL_REVIEW_MIN', '30', 'Score at or above this goes to MANUAL_REVIEW');
INSERT INTO na_config (config_key, config_value, description) VALUES ('RISK_REJECT_MIN', '70', 'Score at or above this is REJECTED');
INSERT INTO na_config (config_key, config_value, description) VALUES ('VELOCITY_LIMIT', '3', 'R1: requests in the window that trigger the factor');
INSERT INTO na_config (config_key, config_value, description) VALUES ('VELOCITY_WINDOW_HOURS', '24', 'R1: velocity window');
INSERT INTO na_number_ranges (prefix, range_code, description) VALUES ('+30690', 'STANDARD', 'Greek mobile range (690)');
INSERT INTO na_number_ranges (prefix, range_code, description) VALUES ('+30699', 'PREMIUM', 'Greek premium / high-risk range (699)');
INSERT INTO na_risk_factors (factor_code, description, points, active_flag) VALUES ('R1', 'Customer made 3 or more requests in the last 24h', 40, 'Y');
INSERT INTO na_risk_factors (factor_code, description, points, active_flag) VALUES ('R2', 'Customer account created less than 7 days ago', 20, 'Y');
INSERT INTO na_risk_factors (factor_code, description, points, active_flag) VALUES ('R3', 'Number is in a premium / high-risk range', 20, 'Y');
INSERT INTO na_risk_factors (factor_code, description, points, active_flag) VALUES ('R4', 'Prepaid customer without verified ID', 30, 'Y');
INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('ACTIVATION_WINDOW', 'T3: customer SIM activation window', 45, 'ACTIVATION_TIMER_EXPIRED');
INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('REVIEW_ESCALATION', 'T1: manual review escalation', 15, 'REVIEW_TIMER_ESCALATE');
INSERT INTO na_timer_types (timer_code, description, duration_seconds, fires_event) VALUES ('REVIEW_EXPIRY', 'T2: manual review expiry', 30, 'REVIEW_TIMER_EXPIRED');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_CANCELLED', 'CUSTOMER', 'EMAIL', 'Request cancelled');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_COMPLETE', 'CUSTOMER', 'SMS', 'Number is live');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_EXPIRED', 'CUSTOMER', 'SMS', 'Request expired');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_FAILED', 'CUSTOMER', 'EMAIL', 'Allocation failed');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_FAILED_OPS', 'OPERATIONS', 'LOG', 'Allocation failed - investigate');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_REJECTED', 'CUSTOMER', 'EMAIL', 'Request rejected');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ACTIVATION_UNDER_REVIEW', 'CUSTOMER', 'SMS', 'Request needs a manual check');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('ALLOCATE_NUMBER', 'CARRIER', 'REST', 'Ask the carrier to allocate the number');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('MANUAL_REVIEW_REQUIRED', 'OPERATIONS', 'LOG', 'Review queue item');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('NUMBER_ALLOCATED', 'CUSTOMER', 'SMS', 'Number allocated, please confirm SIM activation');
INSERT INTO na_notification_types (notification_code, audience, channel, description) VALUES ('REVIEW_ESCALATED', 'OPERATIONS', 'LOG', 'Review not actioned in time');
INSERT INTO na_conditions (condition_name, description) VALUES ('ELIGIBILITY_PASSED', 'No eligibility failure reasons recorded');
INSERT INTO na_conditions (condition_name, description) VALUES ('RISK_AUTO_APPROVE', 'Risk decision is AUTO_APPROVE');
INSERT INTO na_conditions (condition_name, description) VALUES ('RISK_MANUAL_REVIEW', 'Risk decision is MANUAL_REVIEW');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('ACTIVATE_NUMBER', 'Mark the pool number ACTIVE');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('FLAG_ESCALATED', 'Set the escalated flag');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('NOTIFY', 'Enqueue an outbox notification');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('RELEASE_NUMBER', 'Return the number to the pool');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('RESERVE_NUMBER', 'Reserve the number in the pool');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('START_TIMER', 'Start a timer');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('STOP_ALL_TIMERS', 'Cancel all pending timers');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('TRANSITION_TO', 'Set the activation status');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('REQUESTED', 'REQUEST_RECEIVED', 1, 'ELIGIBILITY_PASSED', 'Eligible: reserve the number');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('REQUESTED', 'REQUEST_RECEIVED', 2, NULL, 'Not eligible');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ELIGIBLE', 'RISK_SCORED', 1, 'RISK_AUTO_APPROVE', 'Low risk: allocate');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ELIGIBLE', 'RISK_SCORED', 2, 'RISK_MANUAL_REVIEW', 'Medium risk: human review');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ELIGIBLE', 'RISK_SCORED', 3, NULL, 'High risk: reject');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('MANUAL_REVIEW', 'REVIEW_APPROVED', 1, NULL, 'Reviewer approves');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('MANUAL_REVIEW', 'REVIEW_REJECTED', 1, NULL, 'Reviewer rejects');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('MANUAL_REVIEW', 'REVIEW_TIMER_ESCALATE', 1, NULL, 'T1: escalate, stay in review');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('MANUAL_REVIEW', 'REVIEW_TIMER_EXPIRED', 1, NULL, 'T2: review expired');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ALLOCATING', 'ALLOCATION_SUCCEEDED', 1, NULL, 'Carrier allocated the number');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ALLOCATING', 'ALLOCATION_FAILED', 1, NULL, 'Carrier refused or retries exhausted');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('AWAITING_ACTIVATION', 'SIM_CONFIRMED', 1, NULL, 'Customer confirms SIM is live');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('AWAITING_ACTIVATION', 'ACTIVATION_TIMER_EXPIRED', 1, NULL, 'T3: customer never confirmed');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('REQUESTED', 'CUSTOMER_CANCELLED', 1, NULL, 'Customer cancels');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('ELIGIBLE', 'CUSTOMER_CANCELLED', 1, NULL, 'Customer cancels');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('MANUAL_REVIEW', 'CUSTOMER_CANCELLED', 1, NULL, 'Customer cancels');
INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES ('AWAITING_ACTIVATION', 'CUSTOMER_CANCELLED', 1, NULL, 'Customer cancels');
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'RESERVE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'REQUEST_RECEIVED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'ELIGIBLE' FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'REQUEST_RECEIVED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'REJECTED' FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'REQUEST_RECEIVED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'NOTIFY', 'ACTIVATION_REJECTED' FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'REQUEST_RECEIVED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'ALLOCATING' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'NOTIFY', 'ALLOCATE_NUMBER' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'MANUAL_REVIEW' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'START_TIMER', 'REVIEW_ESCALATION' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'START_TIMER', 'REVIEW_EXPIRY' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'MANUAL_REVIEW_REQUIRED' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 5, 'NOTIFY', 'ACTIVATION_UNDER_REVIEW' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 2;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 3;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'REJECTED' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 3;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'NOTIFY', 'ACTIVATION_REJECTED' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'RISK_SCORED' AND branch_sequence = 3;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_APPROVED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'ALLOCATING' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_APPROVED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'NOTIFY', 'ALLOCATE_NUMBER' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_APPROVED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_REJECTED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_REJECTED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'REJECTED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_REJECTED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_REJECTED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_REJECTED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'FLAG_ESCALATED', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_ESCALATE' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'NOTIFY', 'REVIEW_ESCALATED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_ESCALATE' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'EXPIRED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_EXPIRED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'REVIEW_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'AWAITING_ACTIVATION' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_SUCCEEDED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'START_TIMER', 'ACTIVATION_WINDOW' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_SUCCEEDED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'NOTIFY', 'NUMBER_ALLOCATED' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_SUCCEEDED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_FAILED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'FAILED' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_FAILED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'NOTIFY', 'ACTIVATION_FAILED' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_FAILED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_FAILED_OPS' FROM na_workflow_branches
WHERE status = 'ALLOCATING' AND event_type = 'ALLOCATION_FAILED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'SIM_CONFIRMED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'ACTIVATE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'SIM_CONFIRMED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'ACTIVE' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'SIM_CONFIRMED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_COMPLETE' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'SIM_CONFIRMED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'ACTIVATION_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'EXPIRED' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'ACTIVATION_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'NOTIFY', 'ACTIVATION_EXPIRED' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'ACTIVATION_TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'CANCELLED' FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_CANCELLED' FROM na_workflow_branches
WHERE status = 'REQUESTED' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'CANCELLED' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_CANCELLED' FROM na_workflow_branches
WHERE status = 'ELIGIBLE' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'CANCELLED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_CANCELLED' FROM na_workflow_branches
WHERE status = 'MANUAL_REVIEW' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_ALL_TIMERS', NULL FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RELEASE_NUMBER', NULL FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'CANCELLED' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'NOTIFY', 'ACTIVATION_CANCELLED' FROM na_workflow_branches
WHERE status = 'AWAITING_ACTIVATION' AND event_type = 'CUSTOMER_CANCELLED' AND branch_sequence = 1;
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1001', 'Clean Long-Standing', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1002', 'Owes Money', 25, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1003', 'At Line Limit', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1004', 'High Velocity', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1005', 'Brand New Account', 0, SYSTIMESTAMP - NUMTODSINTERVAL(87428, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1006', 'Clean Spare 1', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1007', 'Clean Spare 2', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1008', 'Clean Spare 3', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1009', 'Clean Spare 4', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1010', 'Clean Spare 5', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_customers (customer_id, name, outstanding_balance, created_at) VALUES ('C-1011', 'Clean Spare 6', 0, SYSTIMESTAMP - NUMTODSINTERVAL(34561028, 'SECOND'));
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000100', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000101', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000102', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000103', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000104', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000105', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000106', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000107', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000108', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000109', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000110', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000111', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000112', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000113', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000114', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000115', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000116', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000117', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000118', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000119', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000120', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000150', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000199', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000201', 'ACTIVE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000202', 'ACTIVE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000203', 'ACTIVE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000204', 'ACTIVE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306900000205', 'ACTIVE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306998000001', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306998000002', 'AVAILABLE');
INSERT INTO na_number_pool (msisdn, status) VALUES ('+306998000003', 'AVAILABLE');
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000201', 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(2593028, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000202', 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(2593028, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000203', 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(2593028, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000204', 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(2593028, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000205', 'C-1003', 'POSTPAID', 'Y', 'PRO', 'ACTIVE', SYSTIMESTAMP - NUMTODSINTERVAL(2593028, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000301', 'C-1004', 'POSTPAID', 'Y', 'PRO', 'CANCELLED', SYSTIMESTAMP - NUMTODSINTERVAL(8228, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000302', 'C-1004', 'POSTPAID', 'Y', 'PRO', 'CANCELLED', SYSTIMESTAMP - NUMTODSINTERVAL(8228, 'SECOND'));
INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code, status, created_at) VALUES ('+306900000303', 'C-1004', 'POSTPAID', 'Y', 'PRO', 'CANCELLED', SYSTIMESTAMP - NUMTODSINTERVAL(8228, 'SECOND'));
COMMIT;

--
-- STANDALONE INDEXES (not already created by a table constraint)
--


  CREATE INDEX "NA_APP"."IX_NA_ACT_CUSTOMER" ON "NA_APP"."NA_ACTIVATIONS" ("CUSTOMER_ID", SYS_EXTRACT_UTC("CREATED_AT")) 
  ;

  CREATE INDEX "NA_APP"."IX_NA_ACT_MSISDN" ON "NA_APP"."NA_ACTIVATIONS" ("MSISDN") 
  ;

  CREATE INDEX "NA_APP"."IX_NA_AUDIT_ACTIVATION" ON "NA_APP"."NA_AUDIT_LOG" ("ACTIVATION_ID", SYS_EXTRACT_UTC("OCCURRED_AT")) 
  ;

  CREATE INDEX "NA_APP"."IX_NA_OUTBOX_PENDING" ON "NA_APP"."NA_OUTBOX" ("STATUS", "ID") 
  ;

  CREATE INDEX "NA_APP"."IX_NA_TIMERS_DUE" ON "NA_APP"."NA_TIMERS" ("STATUS", SYS_EXTRACT_UTC("DUE_AT")) 
  ;
--
-- PACKAGE SPECS
--

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_ACTIVATIONS" AS
    FUNCTION fn_submit(
	p_msisdn	IN VARCHAR2,
	p_customer_id	IN VARCHAR2,
	p_customer_type IN VARCHAR2,
	p_id_verified	IN VARCHAR2,
	p_plan_code	IN VARCHAR2
    ) RETURN NUMBER;

    PROCEDURE pr_raise_event(
	p_activation_id IN NUMBER,
	p_event_type	IN VARCHAR2,
	p_context	IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE pr_get(p_activation_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
    PROCEDURE pr_get_audit(p_activation_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
END pkg_activations;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_CONDITIONS" AS
    FUNCTION fn_evaluate(p_condition_name IN VARCHAR2, p_activation_id IN NUMBER) RETURN BOOLEAN;
END pkg_conditions;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_CONFIG" AS
    FUNCTION fn_get_number(p_key IN VARCHAR2) RETURN NUMBER;
END pkg_config;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_ELIGIBILITY" AS
    FUNCTION fn_check(p_activation_id IN NUMBER) RETURN VARCHAR2;
END pkg_eligibility;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_OUTBOX" AS
    PROCEDURE pr_enqueue(p_activation_id IN NUMBER, p_notification_code IN VARCHAR2);

    PROCEDURE pr_claim_next(
	p_id		    OUT NUMBER,
	p_activation_id     OUT NUMBER,
	p_notification_code OUT VARCHAR2,
	p_audience	    OUT VARCHAR2,
	p_channel	    OUT VARCHAR2,
	p_payload	    OUT VARCHAR2
    );
    PROCEDURE pr_mark_published(p_id IN NUMBER);
    PROCEDURE pr_mark_failed(p_id IN NUMBER, p_error IN VARCHAR2);
END pkg_outbox;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_RISK" AS
    PROCEDURE pr_score(p_activation_id IN NUMBER);
END pkg_risk;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_TIMERS" AS
    PROCEDURE pr_start_timer(p_activation_id IN NUMBER, p_timer_code IN VARCHAR2);
    PROCEDURE pr_cancel_all(p_activation_id IN NUMBER);
    FUNCTION fn_fire_due RETURN NUMBER;
END pkg_timers;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "NA_APP"."PKG_WORKFLOW_ENGINE" AS
    PROCEDURE pr_process_event(
	p_activation_id IN NUMBER,
	p_status	IN VARCHAR2,
	p_event_type	IN VARCHAR2,
	p_context	IN VARCHAR2 DEFAULT NULL
    );
END pkg_workflow_engine;
/
--
-- PACKAGE BODIES
--

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_ACTIVATIONS" AS

    PROCEDURE pr_assert_exists(p_activation_id IN NUMBER) IS
	v_count NUMBER;
    BEGIN
	SELECT COUNT(*) INTO v_count FROM na_activations WHERE id = p_activation_id;
	IF v_count = 0 THEN
	    RAISE_APPLICATION_ERROR(-20003, 'Activation ' || p_activation_id || ' not found.');
	END IF;
    END pr_assert_exists;

    FUNCTION fn_submit(
	p_msisdn	IN VARCHAR2,
	p_customer_id	IN VARCHAR2,
	p_customer_type IN VARCHAR2,
	p_id_verified	IN VARCHAR2,
	p_plan_code	IN VARCHAR2
    ) RETURN NUMBER IS
	v_id	  NUMBER;
	v_count   NUMBER;
	v_status  na_activations.status%TYPE;
	v_reasons VARCHAR2(200);
    BEGIN
	IF p_msisdn IS NULL OR p_customer_id IS NULL OR p_plan_code IS NULL
	   OR p_customer_type IS NULL OR p_customer_type NOT IN ('PREPAID', 'POSTPAID')
	   OR p_id_verified IS NULL OR p_id_verified NOT IN ('Y', 'N') THEN
	    RAISE_APPLICATION_ERROR(-20001,
		'msisdn, customerId and planCode are required; customerType must be PREPAID or POSTPAID.');
	END IF;

	SELECT COUNT(*) INTO v_count FROM na_customers WHERE customer_id = p_customer_id;
	IF v_count = 0 THEN
	    RAISE_APPLICATION_ERROR(-20003, 'Customer ' || p_customer_id || ' not found.');
	END IF;

	INSERT INTO na_activations (msisdn, customer_id, customer_type, id_verified, plan_code)
	VALUES (p_msisdn, p_customer_id, p_customer_type, p_id_verified, p_plan_code)
	RETURNING id INTO v_id;

	v_reasons := pkg_eligibility.fn_check(v_id);
	UPDATE na_activations SET rejection_reasons = v_reasons WHERE id = v_id;

	pr_raise_event(v_id, 'REQUEST_RECEIVED');

	SELECT status INTO v_status FROM na_activations WHERE id = v_id;
	IF v_status = 'ELIGIBLE' THEN
	    pkg_risk.pr_score(v_id);
	    pr_raise_event(v_id, 'RISK_SCORED');
	END IF;

	RETURN v_id;
    END fn_submit;

    PROCEDURE pr_raise_event(
	p_activation_id IN NUMBER,
	p_event_type	IN VARCHAR2,
	p_context	IN VARCHAR2 DEFAULT NULL
    ) IS
	v_status na_activations.status%TYPE;
    BEGIN
	pr_assert_exists(p_activation_id);
	SELECT status INTO v_status FROM na_activations WHERE id = p_activation_id FOR UPDATE;
	pkg_workflow_engine.pr_process_event(p_activation_id, v_status, p_event_type, p_context);
    END pr_raise_event;

    PROCEDURE pr_get(p_activation_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
    BEGIN
	pr_assert_exists(p_activation_id);
	OPEN p_cursor FOR
	    SELECT id, msisdn, customer_id, customer_type, id_verified, plan_code, status,
		   rejection_reasons, risk_score, risk_factors, risk_decision, escalated_flag,
		   created_at, updated_at
	      FROM na_activations WHERE id = p_activation_id;
    END pr_get;

    PROCEDURE pr_get_audit(p_activation_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
    BEGIN
	pr_assert_exists(p_activation_id);
	OPEN p_cursor FOR
	    SELECT event_type, from_status, to_status, detail, occurred_at
	      FROM na_audit_log WHERE activation_id = p_activation_id
	     ORDER BY occurred_at, id;
    END pr_get_audit;

END pkg_activations;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_CONDITIONS" AS

    FUNCTION fn_evaluate(p_condition_name IN VARCHAR2, p_activation_id IN NUMBER) RETURN BOOLEAN IS
	v_act na_activations%ROWTYPE;
    BEGIN
	SELECT * INTO v_act FROM na_activations WHERE id = p_activation_id;

	CASE p_condition_name
	    WHEN 'ELIGIBILITY_PASSED' THEN RETURN v_act.rejection_reasons IS NULL;
	    WHEN 'RISK_AUTO_APPROVE'  THEN RETURN v_act.risk_decision = 'AUTO_APPROVE';
	    WHEN 'RISK_MANUAL_REVIEW' THEN RETURN v_act.risk_decision = 'MANUAL_REVIEW';
	    ELSE RAISE_APPLICATION_ERROR(-20012, 'Unknown condition: ' || p_condition_name);
	END CASE;
    END fn_evaluate;

END pkg_conditions;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_CONFIG" AS
    FUNCTION fn_get_number(p_key IN VARCHAR2) RETURN NUMBER IS
	v_value na_config.config_value%TYPE;
    BEGIN
	SELECT config_value INTO v_value FROM na_config WHERE config_key = p_key;
	RETURN TO_NUMBER(v_value);
    END fn_get_number;
END pkg_config;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_ELIGIBILITY" AS

    PROCEDURE pr_add(p_reasons IN OUT VARCHAR2, p_reason IN VARCHAR2) IS
    BEGIN
	p_reasons := CASE WHEN p_reasons IS NULL THEN p_reason ELSE p_reasons || ',' || p_reason END;
    END pr_add;

    FUNCTION fn_check(p_activation_id IN NUMBER) RETURN VARCHAR2 IS
	v_act	   na_activations%ROWTYPE;
	v_balance  na_customers.outstanding_balance%TYPE;
	v_count    NUMBER;
	v_status   na_number_pool.status%TYPE;
	v_reasons  VARCHAR2(200);
    BEGIN
	SELECT * INTO v_act FROM na_activations WHERE id = p_activation_id;
	SELECT outstanding_balance INTO v_balance FROM na_customers WHERE customer_id = v_act.customer_id;

	SELECT COUNT(*) INTO v_count FROM na_number_ranges WHERE v_act.msisdn LIKE prefix || '%';
	IF NOT REGEXP_LIKE(v_act.msisdn, '^\+[1-9][0-9]{7,14}$') OR v_count = 0 THEN
	    pr_add(v_reasons, 'INVALID_NUMBER');
	END IF;

	BEGIN
	    SELECT status INTO v_status FROM na_number_pool WHERE msisdn = v_act.msisdn;
	EXCEPTION WHEN NO_DATA_FOUND THEN
	    v_status := NULL;
	END;
	IF v_status IS NULL OR v_status <> 'AVAILABLE' THEN
	    pr_add(v_reasons, 'NUMBER_UNAVAILABLE');
	END IF;

	IF v_balance > 0 THEN
	    pr_add(v_reasons, 'OUTSTANDING_BALANCE');
	END IF;

	SELECT COUNT(*) INTO v_count
	  FROM na_activations
	 WHERE customer_id = v_act.customer_id AND status = 'ACTIVE';
	IF v_count >= pkg_config.fn_get_number('MAX_ACTIVE_LINES') THEN
	    pr_add(v_reasons, 'LINE_LIMIT_EXCEEDED');
	END IF;

	SELECT COUNT(*) INTO v_count
	  FROM na_activations
	 WHERE customer_id = v_act.customer_id
	   AND msisdn = v_act.msisdn
	   AND id <> v_act.id
	   AND status NOT IN ('REJECTED', 'EXPIRED', 'FAILED', 'CANCELLED', 'ACTIVE');
	IF v_count > 0 THEN
	    pr_add(v_reasons, 'DUPLICATE_REQUEST');
	END IF;

	IF v_act.customer_type = 'PREPAID' AND v_act.plan_code <> 'STARTER' AND v_act.id_verified = 'N' THEN
	    pr_add(v_reasons, 'ID_REQUIRED');
	END IF;

	RETURN v_reasons;
    END fn_check;

END pkg_eligibility;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_OUTBOX" AS

    PROCEDURE pr_enqueue(p_activation_id IN NUMBER, p_notification_code IN VARCHAR2) IS
	v_payload VARCHAR2(1000);
	v_count   NUMBER;
    BEGIN
	SELECT COUNT(*) INTO v_count FROM na_notification_types WHERE notification_code = p_notification_code;
	IF v_count = 0 THEN
	    RAISE_APPLICATION_ERROR(-20015, 'Unknown notification code: ' || p_notification_code);
	END IF;

	SELECT JSON_OBJECT(
		   'activationId' VALUE id,
		   'msisdn'	  VALUE msisdn,
		   'customerId'   VALUE customer_id,
		   'status'	  VALUE status,
		   'notification' VALUE p_notification_code
	       )
	  INTO v_payload
	  FROM na_activations WHERE id = p_activation_id;

	INSERT INTO na_outbox (activation_id, notification_code, payload)
	VALUES (p_activation_id, p_notification_code, v_payload);
    END pr_enqueue;

    PROCEDURE pr_claim_next(
	p_id		    OUT NUMBER,
	p_activation_id     OUT NUMBER,
	p_notification_code OUT VARCHAR2,
	p_audience	    OUT VARCHAR2,
	p_channel	    OUT VARCHAR2,
	p_payload	    OUT VARCHAR2
    ) IS
    BEGIN
	SELECT id, activation_id, notification_code, payload
	  INTO p_id, p_activation_id, p_notification_code, p_payload
	  FROM na_outbox
	 WHERE status = 'PENDING' AND ROWNUM = 1
	   FOR UPDATE SKIP LOCKED;

	UPDATE na_outbox SET status = 'IN_FLIGHT', attempts = attempts + 1 WHERE id = p_id;

	SELECT audience, channel INTO p_audience, p_channel
	  FROM na_notification_types WHERE notification_code = p_notification_code;
    EXCEPTION WHEN NO_DATA_FOUND THEN
	p_id := NULL;
    END pr_claim_next;

    PROCEDURE pr_mark_published(p_id IN NUMBER) IS
    BEGIN
	UPDATE na_outbox SET status = 'PUBLISHED', published_at = SYSTIMESTAMP WHERE id = p_id;
    END pr_mark_published;

    PROCEDURE pr_mark_failed(p_id IN NUMBER, p_error IN VARCHAR2) IS
    BEGIN
	UPDATE na_outbox SET status = 'FAILED', error_message = SUBSTR(p_error, 1, 400) WHERE id = p_id;
    END pr_mark_failed;

END pkg_outbox;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_RISK" AS

    FUNCTION fn_factor_applies(p_code IN VARCHAR2, p_act IN na_activations%ROWTYPE) RETURN BOOLEAN IS
	v_count    NUMBER;
	v_created  na_customers.created_at%TYPE;
    BEGIN
	CASE p_code
	    WHEN 'R1' THEN  -- request velocity
		SELECT COUNT(*) INTO v_count
		  FROM na_activations
		 WHERE customer_id = p_act.customer_id
		   AND id <> p_act.id
		   AND created_at >= SYSTIMESTAMP - NUMTODSINTERVAL(pkg_config.fn_get_number('VELOCITY_WINDOW_HOURS'), 'HOUR');
		RETURN v_count >= pkg_config.fn_get_number('VELOCITY_LIMIT');
	    WHEN 'R2' THEN  -- new account
		SELECT created_at INTO v_created FROM na_customers WHERE customer_id = p_act.customer_id;
		RETURN v_created > SYSTIMESTAMP - NUMTODSINTERVAL(pkg_config.fn_get_number('NEW_ACCOUNT_DAYS'), 'DAY');
	    WHEN 'R3' THEN  -- premium range
		SELECT COUNT(*) INTO v_count
		  FROM na_number_ranges
		 WHERE range_code = 'PREMIUM' AND p_act.msisdn LIKE prefix || '%';
		RETURN v_count > 0;
	    WHEN 'R4' THEN  -- prepaid and not ID verified
		RETURN p_act.customer_type = 'PREPAID' AND p_act.id_verified = 'N';
	    ELSE
		RAISE_APPLICATION_ERROR(-20012, 'Unknown risk factor: ' || p_code);
	END CASE;
    END fn_factor_applies;

    PROCEDURE pr_score(p_activation_id IN NUMBER) IS
	v_act	   na_activations%ROWTYPE;
	v_score    NUMBER := 0;
	v_factors  VARCHAR2(100);
	v_decision na_activations.risk_decision%TYPE;
    BEGIN
	SELECT * INTO v_act FROM na_activations WHERE id = p_activation_id;

	FOR f IN (SELECT factor_code, points FROM na_risk_factors WHERE active_flag = 'Y' ORDER BY factor_code) LOOP
	    IF fn_factor_applies(f.factor_code, v_act) THEN
		v_score := v_score + f.points;
		v_factors := CASE WHEN v_factors IS NULL THEN f.factor_code ELSE v_factors || ',' || f.factor_code END;
	    END IF;
	END LOOP;

	v_decision := CASE
	    WHEN v_score >= pkg_config.fn_get_number('RISK_REJECT_MIN')        THEN 'REJECT'
	    WHEN v_score >= pkg_config.fn_get_number('RISK_MANUAL_REVIEW_MIN') THEN 'MANUAL_REVIEW'
	    ELSE 'AUTO_APPROVE'
	END;

	UPDATE na_activations
	   SET risk_score = v_score, risk_factors = v_factors, risk_decision = v_decision,
	       updated_at = SYSTIMESTAMP
	 WHERE id = p_activation_id;
    END pr_score;

END pkg_risk;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_TIMERS" AS

    PROCEDURE pr_start_timer(p_activation_id IN NUMBER, p_timer_code IN VARCHAR2) IS
	v_seconds na_timer_types.duration_seconds%TYPE;
    BEGIN
	BEGIN
	    SELECT duration_seconds INTO v_seconds FROM na_timer_types WHERE timer_code = p_timer_code;
	EXCEPTION WHEN NO_DATA_FOUND THEN
	    RAISE_APPLICATION_ERROR(-20011, 'Unknown timer code: ' || p_timer_code);
	END;

	INSERT INTO na_timers (activation_id, timer_code, due_at)
	VALUES (p_activation_id, p_timer_code, SYSTIMESTAMP + NUMTODSINTERVAL(v_seconds, 'SECOND'));
    END pr_start_timer;

    PROCEDURE pr_cancel_all(p_activation_id IN NUMBER) IS
    BEGIN
	UPDATE na_timers SET status = 'CANCELLED'
	 WHERE activation_id = p_activation_id AND status = 'PENDING';
    END pr_cancel_all;

    FUNCTION fn_fire_due RETURN NUMBER IS
	v_fired NUMBER := 0;
	v_error VARCHAR2(400);
    BEGIN
	FOR t IN (
	    SELECT tm.id, tm.activation_id, tt.fires_event
	      FROM na_timers tm
	      JOIN na_timer_types tt ON tt.timer_code = tm.timer_code
	     WHERE tm.status = 'PENDING' AND tm.due_at <= SYSTIMESTAMP
	     ORDER BY tm.due_at
	       FOR UPDATE OF tm.status SKIP LOCKED
	) LOOP
	    SAVEPOINT before_timer;
	    BEGIN
		UPDATE na_timers SET status = 'FIRED', fired_at = SYSTIMESTAMP WHERE id = t.id;
		pkg_activations.pr_raise_event(t.activation_id, t.fires_event);
		v_fired := v_fired + 1;
	    EXCEPTION WHEN OTHERS THEN
		v_error := SUBSTR(SQLERRM, 1, 400);
		ROLLBACK TO before_timer;
		UPDATE na_timers
		   SET status = 'FAILED', error_message = v_error
		 WHERE id = t.id;
	    END;
	END LOOP;
	RETURN v_fired;
    END fn_fire_due;

END pkg_timers;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "NA_APP"."PKG_WORKFLOW_ENGINE" AS

    PROCEDURE pr_run_actions(p_activation_id IN NUMBER, p_branch_id IN NUMBER, p_detail IN OUT VARCHAR2) IS
	v_rows NUMBER;
    BEGIN
	FOR act IN (
	    SELECT action_type, action_parameter
	      FROM na_workflow_actions
	     WHERE branch_id = p_branch_id
	     ORDER BY action_sequence
	) LOOP
	    CASE act.action_type
		WHEN 'TRANSITION_TO' THEN
		    UPDATE na_activations SET status = act.action_parameter, updated_at = SYSTIMESTAMP
		     WHERE id = p_activation_id;

		WHEN 'NOTIFY' THEN
		    pkg_outbox.pr_enqueue(p_activation_id, act.action_parameter);

		WHEN 'START_TIMER' THEN
		    pkg_timers.pr_start_timer(p_activation_id, act.action_parameter);

		WHEN 'STOP_ALL_TIMERS' THEN
		    pkg_timers.pr_cancel_all(p_activation_id);

		WHEN 'RESERVE_NUMBER' THEN
		    UPDATE na_number_pool p SET status = 'RESERVED', reserved_by_id = p_activation_id, updated_at = SYSTIMESTAMP
		     WHERE status = 'AVAILABLE'
		       AND msisdn = (SELECT msisdn FROM na_activations WHERE id = p_activation_id);
		    v_rows := SQL%ROWCOUNT;
		    IF v_rows = 0 THEN
			RAISE_APPLICATION_ERROR(-20014, 'Number is no longer available.');
		    END IF;

		WHEN 'RELEASE_NUMBER' THEN
		    UPDATE na_number_pool SET status = 'AVAILABLE', reserved_by_id = NULL, updated_at = SYSTIMESTAMP
		     WHERE reserved_by_id = p_activation_id;

		WHEN 'ACTIVATE_NUMBER' THEN
		    UPDATE na_number_pool SET status = 'ACTIVE', updated_at = SYSTIMESTAMP
		     WHERE reserved_by_id = p_activation_id;

		WHEN 'FLAG_ESCALATED' THEN
		    UPDATE na_activations SET escalated_flag = 'Y', updated_at = SYSTIMESTAMP
		     WHERE id = p_activation_id;

		ELSE
		    RAISE_APPLICATION_ERROR(-20013, 'Unknown action type: ' || act.action_type);
	    END CASE;

	    p_detail := CASE WHEN p_detail IS NULL THEN '' ELSE p_detail || ',' END
			|| act.action_type || CASE WHEN act.action_parameter IS NOT NULL THEN ':' || act.action_parameter END;
	END LOOP;
    END pr_run_actions;

    PROCEDURE pr_process_event(
	p_activation_id IN NUMBER,
	p_status	IN VARCHAR2,
	p_event_type	IN VARCHAR2,
	p_context	IN VARCHAR2 DEFAULT NULL
    ) IS
	v_branch_id NUMBER := NULL;
	v_detail    VARCHAR2(400) := CASE WHEN p_context IS NOT NULL THEN 'context=' || p_context END;
	v_to_status na_activations.status%TYPE;
    BEGIN
	FOR br IN (
	    SELECT id, condition_name
	      FROM na_workflow_branches
	     WHERE status = p_status AND event_type = p_event_type
	     ORDER BY branch_sequence
	) LOOP
	    IF br.condition_name IS NULL OR pkg_conditions.fn_evaluate(br.condition_name, p_activation_id) THEN
		v_branch_id := br.id;
		EXIT;
	    END IF;
	END LOOP;

	IF v_branch_id IS NULL THEN
	    RAISE_APPLICATION_ERROR(-20010,
		'Event ' || p_event_type || ' is not valid while the activation is ' || p_status || '.');
	END IF;

	pr_run_actions(p_activation_id, v_branch_id, v_detail);

	SELECT status INTO v_to_status FROM na_activations WHERE id = p_activation_id;

	INSERT INTO na_audit_log (activation_id, event_type, from_status, to_status, branch_id, detail)
	VALUES (p_activation_id, p_event_type, p_status, v_to_status, v_branch_id, SUBSTR(v_detail, 1, 400));
    END pr_process_event;

END pkg_workflow_engine;
/
