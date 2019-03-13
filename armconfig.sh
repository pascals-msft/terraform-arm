# Creates a Service Principal in AAD, to use with Terraform
#
# Output: armcred.tf with the azurerm provider configuration
#
# Prerequisites:
# install Azure CLI 2.0:
#   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# login:
#   az login
# choose subscription:
#   az account set --subscription <subscription name>

# Get subscription id and tenant id
echo
echo Subscription id...
ARM_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
# fields: environmentName, id, isDefault, name, state, tenandId
echo ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID

# Create the app, service principal and role assignment
echo
echo Create the app, service principal and role assignment...
SP_TSV=$(az ad sp create-for-rbac --role Contributor --scopes /subscriptions/$ARM_SUBSCRIPTION_ID -o tsv)
# fields: AppId, DisplayName, Name, Password, TenantID
ARM_CLIENT_ID=$(echo $SP_TSV | cut -d ' ' -f 1)
ARM_SP_DISPLAY_NAME=$(echo $SP_TSV | cut -d ' ' -f 2)
ARM_SP_NAME=$(echo $SP_TSV | cut -d ' ' -f 3)
ARM_CLIENT_SECRET=$(echo $SP_TSV | cut -d ' '  -f 4)
ARM_TENANT_ID=$(echo $SP_TSV | cut -d ' '  -f 5)
echo ARM_CLIENT_ID=$ARM_CLIENT_ID
echo ARM_SP_DISPLAY_NAME=$ARM_SP_DISPLAY_NAME
echo ARM_SP_NAME=$ARM_SP_NAME
echo ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET
echo ARM_TENANT_ID=$ARM_TENANT_ID

# test login
echo
echo Command to try the service principal:
echo az login --service-principal -u $ARM_SP_DISPLAY_NAME -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# Terraform file
echo
echo Writing armcred.tf:
tee armcred.tf <<EOF
# armcred.tf
# Configure the Microsoft Azure RM Provider
# Service Principal Display Name: $ARM_SP_DISPLAY_NAME
# Service Principal Name: $ARM_SP_NAME
# If you need to delete the service principal:
#   az ad app delete --id $ARM_CLIENT_ID
provider "azurerm" {
  subscription_id = "$ARM_SUBSCRIPTION_ID"
  tenant_id       = "$ARM_TENANT_ID"
  client_id       = "$ARM_CLIENT_ID"
  client_secret   = "$ARM_CLIENT_SECRET"
}
EOF