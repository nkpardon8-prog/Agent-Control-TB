# Uninstall

From the source checkout:

```bash
./uninstall.sh
```

This removes the SwiftBar plugin link and clears launchd Claude environment
variables.

It does not delete runtime data. To remove runtime configs, logs, reports, and
isolated profile auth:

```bash
rm -rf ~/.agent-control-tb
```
