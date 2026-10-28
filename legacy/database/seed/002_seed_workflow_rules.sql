
INSERT INTO na_conditions (condition_name, description) VALUES ('ELIGIBILITY_PASSED', 'No eligibility failure reasons recorded');
INSERT INTO na_conditions (condition_name, description) VALUES ('RISK_AUTO_APPROVE',  'Risk decision is AUTO_APPROVE');
INSERT INTO na_conditions (condition_name, description) VALUES ('RISK_MANUAL_REVIEW', 'Risk decision is MANUAL_REVIEW');

INSERT INTO na_workflow_action_types (action_type, description) VALUES ('TRANSITION_TO',   'Set the activation status');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('NOTIFY',          'Enqueue an outbox notification');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('START_TIMER',     'Start a timer');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('STOP_ALL_TIMERS', 'Cancel all pending timers');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('RESERVE_NUMBER',  'Reserve the number in the pool');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('RELEASE_NUMBER',  'Return the number to the pool');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('ACTIVATE_NUMBER', 'Mark the pool number ACTIVE');
INSERT INTO na_workflow_action_types (action_type, description) VALUES ('FLAG_ESCALATED',  'Set the escalated flag');

DECLARE
    v_seq NUMBER;
    b     NUMBER;

    FUNCTION br(p_status VARCHAR2, p_event VARCHAR2, p_seq NUMBER, p_cond VARCHAR2, p_desc VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        INSERT INTO na_workflow_branches (status, event_type, branch_sequence, condition_name, description)
        VALUES (p_status, p_event, p_seq, p_cond, p_desc)
        RETURNING id INTO v_id;
        v_seq := 0;
        RETURN v_id;
    END br;

    PROCEDURE act(p_branch NUMBER, p_type VARCHAR2, p_param VARCHAR2 DEFAULT NULL) IS
    BEGIN
        v_seq := v_seq + 1;
        INSERT INTO na_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
        VALUES (p_branch, v_seq, p_type, p_param);
    END act;

    PROCEDURE cancel_branch(p_status VARCHAR2) IS
        b NUMBER;
    BEGIN
        b := br(p_status, 'CUSTOMER_CANCELLED', 1, NULL, 'Customer cancels');
        act(b, 'STOP_ALL_TIMERS'); act(b, 'RELEASE_NUMBER');
        act(b, 'TRANSITION_TO', 'CANCELLED'); act(b, 'NOTIFY', 'ACTIVATION_CANCELLED');
    END cancel_branch;

BEGIN
    b := br('REQUESTED', 'REQUEST_RECEIVED', 1, 'ELIGIBILITY_PASSED', 'Eligible: reserve the number');
    act(b, 'RESERVE_NUMBER'); act(b, 'TRANSITION_TO', 'ELIGIBLE');
    b := br('REQUESTED', 'REQUEST_RECEIVED', 2, NULL, 'Not eligible');
    act(b, 'TRANSITION_TO', 'REJECTED'); act(b, 'NOTIFY', 'ACTIVATION_REJECTED');

    b := br('ELIGIBLE', 'RISK_SCORED', 1, 'RISK_AUTO_APPROVE', 'Low risk: allocate');
    act(b, 'TRANSITION_TO', 'ALLOCATING'); act(b, 'NOTIFY', 'ALLOCATE_NUMBER');
    b := br('ELIGIBLE', 'RISK_SCORED', 2, 'RISK_MANUAL_REVIEW', 'Medium risk: human review');
    act(b, 'TRANSITION_TO', 'MANUAL_REVIEW');
    act(b, 'START_TIMER', 'REVIEW_ESCALATION'); act(b, 'START_TIMER', 'REVIEW_EXPIRY');
    act(b, 'NOTIFY', 'MANUAL_REVIEW_REQUIRED'); act(b, 'NOTIFY', 'ACTIVATION_UNDER_REVIEW');
    b := br('ELIGIBLE', 'RISK_SCORED', 3, NULL, 'High risk: reject');
    act(b, 'RELEASE_NUMBER'); act(b, 'TRANSITION_TO', 'REJECTED'); act(b, 'NOTIFY', 'ACTIVATION_REJECTED');

    b := br('MANUAL_REVIEW', 'REVIEW_APPROVED', 1, NULL, 'Reviewer approves');
    act(b, 'STOP_ALL_TIMERS'); act(b, 'TRANSITION_TO', 'ALLOCATING'); act(b, 'NOTIFY', 'ALLOCATE_NUMBER');
    b := br('MANUAL_REVIEW', 'REVIEW_REJECTED', 1, NULL, 'Reviewer rejects');
    act(b, 'STOP_ALL_TIMERS'); act(b, 'RELEASE_NUMBER');
    act(b, 'TRANSITION_TO', 'REJECTED'); act(b, 'NOTIFY', 'ACTIVATION_REJECTED');
    b := br('MANUAL_REVIEW', 'REVIEW_TIMER_ESCALATE', 1, NULL, 'T1: escalate, stay in review');
    act(b, 'FLAG_ESCALATED'); act(b, 'NOTIFY', 'REVIEW_ESCALATED');
    b := br('MANUAL_REVIEW', 'REVIEW_TIMER_EXPIRED', 1, NULL, 'T2: review expired');
    act(b, 'STOP_ALL_TIMERS'); act(b, 'RELEASE_NUMBER');
    act(b, 'TRANSITION_TO', 'EXPIRED'); act(b, 'NOTIFY', 'ACTIVATION_EXPIRED');

    b := br('ALLOCATING', 'ALLOCATION_SUCCEEDED', 1, NULL, 'Carrier allocated the number');
    act(b, 'TRANSITION_TO', 'AWAITING_ACTIVATION');
    act(b, 'START_TIMER', 'ACTIVATION_WINDOW'); act(b, 'NOTIFY', 'NUMBER_ALLOCATED');
    b := br('ALLOCATING', 'ALLOCATION_FAILED', 1, NULL, 'Carrier refused or retries exhausted');
    act(b, 'RELEASE_NUMBER'); act(b, 'TRANSITION_TO', 'FAILED');
    act(b, 'NOTIFY', 'ACTIVATION_FAILED'); act(b, 'NOTIFY', 'ACTIVATION_FAILED_OPS');

    b := br('AWAITING_ACTIVATION', 'SIM_CONFIRMED', 1, NULL, 'Customer confirms SIM is live');
    act(b, 'STOP_ALL_TIMERS'); act(b, 'ACTIVATE_NUMBER');
    act(b, 'TRANSITION_TO', 'ACTIVE'); act(b, 'NOTIFY', 'ACTIVATION_COMPLETE');
    b := br('AWAITING_ACTIVATION', 'ACTIVATION_TIMER_EXPIRED', 1, NULL, 'T3: customer never confirmed');
    act(b, 'RELEASE_NUMBER'); act(b, 'TRANSITION_TO', 'EXPIRED'); act(b, 'NOTIFY', 'ACTIVATION_EXPIRED');

    cancel_branch('REQUESTED');
    cancel_branch('ELIGIBLE');
    cancel_branch('MANUAL_REVIEW');
    cancel_branch('AWAITING_ACTIVATION');

    COMMIT;
END;
/
EXIT;
