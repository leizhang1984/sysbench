#!/bin/bash
cd "$(dirname "$0")"
exec > deploy-infra.log 2>&1
az account show --query user.name -o tsv || { echo "NOT LOGGED IN"; exit 1; }
bash ./deploy-infra.sh
echo "DEPLOY_INFRA_EXIT=$?"
