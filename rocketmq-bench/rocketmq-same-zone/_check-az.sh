#!/bin/bash
if az account show --query user.name -o tsv 2>/dev/null; then
  echo "WSL_AZ_LOGGED_IN"
else
  echo "WSL_AZ_NOT_LOGGED_IN"
fi
