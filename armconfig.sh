# Create a Service Principal in AAD, to use with Terraform

# Prerequisites:
# install jq:
#   sudo apt install jq
# install Azure CLI 2.0:
#   curl -L https://aka.ms/InstallAzureCli | bash
# login:
#   az login
#   az account set --subscription <subscription name>

# Get subscription id and tenant id
echo
echo az account show...
ARM_ACCOUNT=$(az account show --output json)
echo ARM_ACCOUNT=$ARM_ACCOUNT
ARM_SUBSCRIPTION_ID=$(echo $ARM_ACCOUNT | jq -r .id)
ARM_TENANT_ID=$(echo $ARM_ACCOUNT | jq -r .tenantId)

# Create the app, service principal and role assignment
echo
echo az ad sp create-for-rbac...
ARM_SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --role Contributor --scopes /subscriptions/$ARM_SUBSCRIPTION_ID --out json)
echo ARM_SERVICE_PRINCIPAL=$ARM_SERVICE_PRINCIPAL

# Example:
# {
#   "appId": "4f6525e2-9bee-4de0-90e2-be5121d5e060",
#   "displayName": "azure-cli-2017-04-24-16-47-01",
#   "name": "http://azure-cli-2017-04-24-16-47-01",
#   "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
# }

ARM_CLIENT_ID=$(echo $ARM_SERVICE_PRINCIPAL | jq -r .appId)
ARM_SP_DISPLAY_NAME=$(echo $ARM_SERVICE_PRINCIPAL | jq -r .displayName)
ARM_CLIENT_SECRET=$(echo $ARM_SERVICE_PRINCIPAL | jq -r .password)

# test login

echo
echo Command to try the service principal:
echo az login --service-principal -u $ARM_SP_DISPLAY_NAME -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# Terraform file
echo
echo Writing armcred.tf:
cat > armcred.tf <<EOF
# Configure the Microsoft Azure Provider
# Service Principal Display Name: $ARM_SP_DISPLAY_NAME
provider "azurerm" {
  subscription_id = "$ARM_SUBSCRIPTION_ID"
  tenant_id       = "$ARM_TENANT_ID"
  client_id       = "$ARM_CLIENT_ID"
  client_secret   = "$ARM_CLIENT_SECRET"
}
EOF
cat armcred.tf

# How to delete the service principal
echo
echo If you want to delete the service principal:
echo az ad app delete --id $ARM_CLIENT_ID
