# Number Activation

Small telecom number-activation workflow service (.NET + Oracle). See `USECASE.md` for the full spec and `CLAUDE.md` for commands and architecture.

```bash
podman compose --env-file .env up -d && scripts/db-apply.sh
scripts/run-local.sh        # API :5100, mock carrier :5101
scripts/demo.sh             # in another terminal
```

```bash
curl -X POST localhost:5100/api/activations -H 'content-type: application/json' \
  -d '{"msisdn":"+306900000101","customerId":"C-1001","customerType":"POSTPAID","idVerified":true,"planCode":"PRO"}'
curl localhost:5100/api/activations/<id>                      # status + audit trail
curl -X POST localhost:5100/api/activations/<id>/confirm      # SIM activated
curl -X POST localhost:5100/api/activations/<id>/review -H 'content-type: application/json' -d '{"decision":"APPROVE"}'
curl -X POST localhost:5100/api/activations/<id>/cancel
```
