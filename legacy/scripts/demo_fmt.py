"""Formatting helper for scripts/demo.sh: reads an API JSON body on stdin."""
import json
import sys

cmd = sys.argv[1]
body = json.load(sys.stdin)


def activation():
    if "activation" not in body:
        sys.exit("API error: " + json.dumps(body) +
                 "\n -- check logs/api.log, and that scripts/db-apply.sh completed")
    return body["activation"]


if cmd == "id":
    print(activation()["id"])
elif cmd == "status":
    print(activation()["status"])
elif cmd == "short":
    a = activation()
    print(a["status"] + (" (escalated)" if a["escalated"] and a["status"] == "MANUAL_REVIEW" else ""))
elif cmd == "outcome":
    a = activation()
    out = a["status"]
    if a["riskScore"] is not None:
        factors = ",".join(a["riskFactors"]) or "none"
        out += f"  | risk score {a['riskScore']} (factors: {factors}) -> {a['riskDecision']}"
    if a["rejectionReasons"]:
        out += "  | failed rules: " + ", ".join(a["rejectionReasons"])
    if a["escalated"]:
        out += "  | escalated to ops"
    print(out)
elif cmd == "trail":
    for hop in body["audit"]:
        stay = " (stays)" if hop["fromStatus"] == hop["toStatus"] else ""
        print(f"{hop['fromStatus']:<20} --{hop['eventType']}--> {hop['toStatus']}{stay}")
