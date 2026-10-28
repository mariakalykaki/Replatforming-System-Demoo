#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

API=${API:-http://localhost:5100/api/activations}
FMT="python3 scripts/demo_fmt.py"
PACE=${DEMO_PACE:-3}
T1=15; T2=30; T3=45

if [ -t 1 ]; then B=$'\e[1m'; D=$'\e[2m'; G=$'\e[32m'; R=$'\e[31m'; C=$'\e[36m'; X=$'\e[0m'; else B=; D=; G=; R=; C=; X=; fi
START=$(date +%s)
now() { printf '%s[+%02ds]%s' "$D" $(( $(date +%s) - START )) "$X"; }
phase() { printf '\n%s== %s ==%s\n' "$B" "$1" "$X"; }
note() { printf '   %s%s%s\n' "$D" "$1" "$X"; }

post() { curl -sS -X POST "$1" -H 'content-type: application/json' ${2:+-d "$2"}; }
get()  { curl -sS "$API/$1"; }

echo "Checking the API is up at $API ..."
for i in $(seq 1 30); do
  curl -s -m 2 -o /dev/null "$API/0" && break
  if [ "$i" -eq 30 ]; then
    echo "The API is not reachable. Start the stack with scripts/run-local.sh and wait for it to finish building, then re-run." >&2
    exit 1
  fi
  sleep 2
done

submit() {
  local var=$1 title=$2 who=$3 msisdn=$4 customer=$5 type=$6 verified=$7 plan=$8 blurb=$9
  printf '\n%s %s%s%s\n' "$(now)" "$C" "$title" "$X"
  note "$who"
  note "Request: $customer ($type, ID verified: $verified) asks for $msisdn on plan $plan"
  local body; body=$(post "$API" "{\"msisdn\":\"$msisdn\",\"customerId\":\"$customer\",\"customerType\":\"$type\",\"idVerified\":$verified,\"planCode\":\"$plan\"}")
  printf -v "$var" '%s' "$(echo "$body" | $FMT id)"
  track "${title%% *}" "${!var}"
  printf '   -> %s\n' "$(echo "$body" | $FMT outcome)"
  note "$blurb"
  pause
}

signal() {
  printf '%s %s\n' "$(now)" "$4"
  local body; body=$(post "$API/$1/$2" "${3:-}")
  printf '   -> %s\n' "$(echo "$body" | $FMT outcome)"
  mark_seen "$1"
  pause
}

status_of() { get "$1" | $FMT status; }
short_of()  { get "$1" | $FMT short; }

W_LABEL=(); W_ID=(); W_LAST=()
track() { W_LABEL+=("$1"); W_ID+=("$2"); W_LAST+=("$(short_of "$2")"); }
mark_seen() {
  local i
  for i in "${!W_ID[@]}"; do
    if [ "${W_ID[$i]}" = "$1" ]; then W_LAST[$i]=$(short_of "$1"); fi
  done
  return 0
}

meaning() {
  case "$1:$2" in
    S4:AWAITING_ACTIVATION)  echo "the carrier failed twice (503); the third attempt succeeded" ;;
    S5a:FAILED)              echo "the carrier timed out (504) on every retry; number returned to the pool" ;;
    S5b:FAILED)              echo "the carrier refused the number (422) so it was not retried; number returned to the pool" ;;
    *:AWAITING_ACTIVATION)   echo "the carrier allocated the number; waiting for the customer to confirm the SIM" ;;
    *:"MANUAL_REVIEW (escalated)") echo "nobody reviewed it in time: escalated to ops, still waiting for a decision" ;;
    S3:EXPIRED|S7:EXPIRED)   echo "the review window closed with no decision; number returned to the pool" ;;
    S9:EXPIRED)              echo "the customer never confirmed the SIM in time; number returned to the pool" ;;
    *:ACTIVE)                echo "the number is live" ;;
    *:CANCELLED)             echo "cancelled; number returned to the pool" ;;
    *)                       echo "" ;;
  esac
}

report_changes() {
  local i cur
  for i in "${!W_ID[@]}"; do
    cur=$(short_of "${W_ID[$i]}")
    if [ "$cur" != "${W_LAST[$i]}" ]; then
      printf '%s %s%-4s%s %s -> %s\n' "$(now)" "$B" "${W_LABEL[$i]}" "$X" "${W_LAST[$i]}" "$cur"
      local m; m=$(meaning "${W_LABEL[$i]}" "$cur")
      if [ -n "$m" ]; then note "$m"; fi
      W_LAST[$i]=$cur
    fi
  done
  return 0
}

pause() { local n=${1:-$PACE}; while [ "$n" -gt 0 ]; do report_changes; sleep 1; n=$((n-1)); done; }

wait_for() {
  local timeout=$1; shift
  while [ "$timeout" -gt 0 ]; do
    report_changes
    local all_ok=1 pair i
    for pair in "$@"; do
      for i in "${!W_LABEL[@]}"; do
        if [ "${W_LABEL[$i]}" = "${pair%%=*}" ] && ! [[ "${W_LAST[$i]}" =~ ^(${pair#*=})$ ]]; then all_ok=0; fi
      done
    done
    [ "$all_ok" -eq 1 ] && return 0
    sleep 1; timeout=$((timeout-1))
  done
  echo "   (timed out waiting; the results below will show where things stand)"
}

FAILURES=0
check() {
  local body line trail; body=$(get "$2"); line=$(echo "$body" | $FMT outcome)
  if [[ "$line" == "$3"* ]]; then printf '%sPASS%s  %s\n' "$G" "$X" "$1"; else
    printf '%sFAIL%s  %s  (expected %s)\n' "$R" "$X" "$1" "$3"; FAILURES=$((FAILURES+1)); fi
  printf '        %s%s%s\n' "$D" "$line" "$X"
  echo "$body" | $FMT trail | sed "s/^/        ${D}path: /; s/\$/${X}/"
}

printf '%sNumber Activation demo%s\n' "$B" "$X"
note "Greek mobile numbers (+3069...). Timers: T1 ${T1}s review escalation, T2 ${T2}s review expiry, T3 ${T3}s SIM activation window."
note "Every status decision below is made by the database rules engine; the API only raises events."

phase "1. Submitting ten activation requests"
note "On submit the database checks six eligibility rules (E1-E6), reserves the number, then scores risk (R1-R4)."

submit s1 "S1  Clean request" "Long-standing customer, free number, nothing unusual." \
  +306900000101 C-1001 POSTPAID true PRO \
  "All eligibility rules pass, risk score 0 -> auto-approved. The number is reserved and a carrier allocation is queued."
submit s2 "S2  Busy customer -> manual review" "C-1004 has already made 3 requests in the last 24 hours." \
  +306900000103 C-1004 POSTPAID true PRO \
  "Request velocity (R1, +40) pushes the score to 40 -> MANUAL_REVIEW. Timers T1 (${T1}s) and T2 (${T2}s) start; ops are notified."
signal "$s2" review '{"decision":"APPROVE"}' "S2: a reviewer picks it up and approves it, well inside the ${T1}s escalation window"
note "Approval cancels S2's review timers and queues its carrier allocation."
submit s3 "S3  New account + premium number, nobody reviews it" "C-1005 opened its account yesterday and wants a premium number." \
  +306998000001 C-1005 POSTPAID true PRO \
  "New account (R2, +20) and premium range (R3, +20) -> score 40 -> MANUAL_REVIEW. Nobody will review it: watch it escalate and expire."
submit s4 "S4  Flaky carrier (number ends in 50)" "The mock carrier fails this number twice before succeeding." \
  +306900000150 C-1006 POSTPAID true PRO \
  "Passes straight through. The retry behaviour shows up in the allocation step."
submit s5a "S5a Carrier timeout (number ends in 00)" "The mock carrier answers 504 for this number every time." \
  +306900000100 C-1007 POSTPAID true PRO \
  "Passes straight through; the failure happens at the carrier."
submit s5b "S5b Carrier refusal (number ends in 99)" "The mock carrier refuses this number outright (422)." \
  +306900000199 C-1008 POSTPAID true PRO \
  "Passes straight through; the failure happens at the carrier."
submit s6 "S6  Rejected on several rules at once" "C-1002 owes 25.00 and is a prepaid customer with no verified ID." \
  +306900000102 C-1002 PREPAID false PRO \
  "Two rules fail (outstanding balance, ID required); both are reported and no number is reserved."
submit s7 "S7  Prepaid, unverified, STARTER plan" "STARTER is exempt from the ID rule, so this passes eligibility." \
  +306900000104 C-1009 PREPAID false STARTER \
  "Risk rule R4 (+30) still flags it -> score 30 -> MANUAL_REVIEW. Nobody reviews this one either."
submit s8 "S8  Customer will cancel" "Clean request; the customer changes their mind after allocation." \
  +306900000105 C-1010 POSTPAID true PRO \
  "Auto-approved like S1."
submit s9 "S9  Customer never activates the SIM" "Clean request; the customer never confirms the SIM." \
  +306900000106 C-1011 POSTPAID true PRO \
  "Auto-approved like S1; the ${T3}s activation timer will start once the carrier allocates."

phase "2. Carrier allocation (the worker relays the outbox)"
note "Approved requests have an allocation message in the transactional outbox. The worker picks it up every ~2s and calls the carrier."
note "From here on a line appears only when a request changes state."
wait_for 60 S1=AWAITING_ACTIVATION S2=AWAITING_ACTIVATION S4=AWAITING_ACTIVATION S5a=FAILED S5b=FAILED S8=AWAITING_ACTIVATION S9=AWAITING_ACTIVATION
pause

phase "3. People act (signals)"
signal "$s1" confirm "" "S1: customer confirms the SIM is live"
signal "$s4" confirm "" "S4: customer confirms the SIM is live"
signal "$s2" confirm "" "S2: customer confirms the SIM is live"
signal "$s8" cancel "" "S8: customer cancels; the reserved number goes back to the pool"
note "S3, S7 and S9 are deliberately left alone."

phase "4. Timers (nobody touches S3, S7, S9)"
note "T1 (${T1}s): unreviewed requests escalate to ops and stay in review.  T2 (${T2}s): review expires.  T3 (${T3}s): unconfirmed activation expires."
note "A background sweep fires due timers every ~5s, so expect each to land a few seconds late."
wait_for 120 S3=EXPIRED S7=EXPIRED S9=EXPIRED
pause

phase "5. Results"
note "Each line is checked against the expected final status. 'path' is the audit trail the database kept for that request."
echo
check "S1  clean, auto-approved, confirmed"               "$s1"  ACTIVE
check "S2  velocity -> review -> approved -> confirmed"   "$s2"  ACTIVE
check "S3  premium + new account, review ignored"         "$s3"  EXPIRED
check "S4  carrier fails twice, third attempt succeeds"   "$s4"  ACTIVE
check "S5a carrier timeout, retries exhausted"            "$s5a" FAILED
check "S5b carrier hard refusal, not retried"             "$s5b" FAILED
check "S6  rejected on balance + ID rules"                "$s6"  REJECTED
check "S7  prepaid STARTER unverified, review ignored"    "$s7"  EXPIRED
check "S8  cancelled after allocation"                    "$s8"  CANCELLED
check "S9  SIM never confirmed"                           "$s9"  EXPIRED

echo
if [ "$FAILURES" -eq 0 ]; then printf '%sAll scenarios behaved as expected.%s\n' "$G" "$X"
else printf '%s%d scenario(s) did not behave as expected.%s\n' "$R" "$FAILURES" "$X"; exit 1; fi
