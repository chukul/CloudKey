#!/bin/bash

# Check if the command is sts assume-role
if [[ "$1" == "sts" && "$2" == "assume-role" ]]; then
  # Return sample JSON
  echo '{
    "Credentials": {
        "AccessKeyId": "ASIA_MOCK_ACCESS_KEY",
        "SecretAccessKey": "MOCK_SECRET_KEY",
        "SessionToken": "MOCK_SESSION_TOKEN",
        "Expiration": "2023-01-01T12:00:00Z"
    }
  }'
  exit 0
fi

# Check if the command is sso login
if [[ "$1" == "sso" && "$2" == "login" ]]; then
  echo "Successfully logged in to SSO"
  exit 0
fi

echo "Unknown command"
exit 1
