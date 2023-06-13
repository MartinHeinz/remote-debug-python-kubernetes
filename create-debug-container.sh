#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

POD_NAMESPACE=$1
POD_NAME=$2
TARGET_CONTAINER_NAME=$3

URL="localhost:8001/api/v1/namespaces/$POD_NAMESPACE/pods/$POD_NAME/ephemeralcontainers"
PATCH=$(cat <<EOF
{
  "spec": {
    "ephemeralContainers": [
      {
        "image": "docker.io/martinheinz/python-debugger:v1.0",
        "name": "debugger",
        "command": [
          "sleep"
        ],
        "args": [
          "infinity"
        ],
        "tty": true,
        "stdin": true,
        "securityContext": {
          "privileged": true,
          "capabilities": {
            "add": [
              "SYS_PTRACE"
            ]
          },
          "runAsNonRoot": false,
          "runAsUser": 0,
          "runAsGroup": 0
        },
        "targetContainerName": "$TARGET_CONTAINER_NAME"
      }
    ]
  }
}
EOF
)

kubectl proxy --address 127.0.0.1 --port 8001 &

echo "$PATCH" | curl \
  --silent \
  --retry 5 \
  --retry-delay 1 \
  --retry-connrefused \
  "$URL" \
  -XPATCH \
  -H 'Content-Type: application/strategic-merge-patch+json' \
  -d @- \
  >/dev/null

kill %1

EXEC_TRIES=1
until
  [ $EXEC_TRIES -gt 5 ] || kubectl exec -n "$POD_NAMESPACE" "$POD_NAME" --container=debugger -- sh
do
  sleep 1
  EXEC_TRIES=$((EXEC_TRIES + 1))
done

kubectl exec "$POD_NAME" --container=debugger -- python -m debugpy --listen 0.0.0.0:5678 --pid 1