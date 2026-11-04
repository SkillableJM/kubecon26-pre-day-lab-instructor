# A6 · The data survived, the application didn't — END state

`records-api` is Ready and serves the 500 seeded records from the original disk (sha256 `aa451749…c149`).

| | Begin state (fault) | End state (this folder) |
|---|---|---|
| Deployment `records-api`, volume `data` | `claimName: records-data-v2` (does not exist) | `claimName: records-data` (the original, seeded claim) |

The PVC, the seed Job (setup phase) and the app are identical in both states.

How a participant gets here: [SOLUTION.md](SOLUTION.md)

## Verify

```bash
scoring/verify.sh --context <cluster-name> --challenges a6        # bash
./scoring/verify.ps1 -Context <cluster-name> -Challenges a6       # PowerShell
```

Every check should report `PASS`.