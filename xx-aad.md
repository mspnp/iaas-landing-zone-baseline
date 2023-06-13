# Prep for Azure Active Directory integration

In the prior step, you [generated the user-facing TLS certificate](./02-ca-certificates.md); now we'll prepare Azure AD for role-based access control (RBAC). This will ensure you have an Azure AD security group(s) and user(s) assigned for group-based control plane access.

**TODO-CK: Figure out what we need to do here.  Taking out of user flow for now.**

## Expected results

Following the steps below you will result in an Azure AD configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                             | Purpose                                                 |
|------------------------------------|---------------------------------------------------------|------------------------------------|---------------------------------------------------------|
| A Compute Ops Security Group       | Represents the group of operations that will logically gather all operation admin users      |
| A Compute Admin User               | Represents at least one break-glass compute admin user. |

This does not configure anything related to workload identity. This configuration is exclusively to set up access to perform VM operations.

## Steps

> :book: The Contoso Azure AD team requires all operations user access to be security-group based. This applies to the new VMs that are being created for Application ID a0008 under the BU0001 business unit. VM logging will be AAD-backed and access granted based on users' AAD group membership(s).

1. Query and save your Azure subscription's tenant id.

   ```bash
   export TENANTID_AZSUBSCRIPTION_IAAS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_AZSUBSCRIPTION_IAAS_BASELINE: $TENANTID_AZSUBSCRIPTION_IAAS_BASELINE
   ```

1. Playing the role as the Contoso Azure AD team, login into the tenant where compute authentication will be associated with.

   > :bulb: Skip the `az login` command if you plan to use your current user account's Azure AD tenant for compute authentication.

   ```bash
   az login -t <Replace-With-Compute-AzureAD-TenantId> --allow-no-subscriptions
   export TENANTID_DOMAIN_COMPUTEAUTHN_IAAS_BASELINE=$(az account show --query tenantId -o tsv)
   echo TENANTID_DOMAIN_COMPUTEAUTHN_IAAS_BASELINE: $TENANTID_DOMAIN_COMPUTEAUTHN_IAAS_BASELINE
   ```

1. Create/identify the Azure AD security group to be given with the role `compute-admin`.

   If you already have a security group that is appropriate for your compute's admin user accounts, use that group and don't create a new one. If using your own group or your Azure AD administrator created one for you to use; you will need to update the group name and ID throughout the reference implementation.
   ```bash
   export AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE=[Paste your existing compute admin group Object ID here.]
   echo AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE: $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE
   ```

   If you want to create a new one instead, you can use the following code:

   ```bash
   export AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE=$(az ad group create --display-name 'compute-admins-bu0001a000800' --mail-nickname 'compute-admins-bu0001a000800' --description "Principals in this group are compute admins in the bu0001a000800 VMs." --query id -o tsv)
   echo AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE: $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE
   ```

   This Azure AD group object ID will be used later while creating the VMs. This way, once the VMs gets deployed the new group will get the proper Role to be able to login.

1. Create a "break-glass" compute administrator user for your VMs.

   > :book: The organization knows the value of having a break-glass admin user for their critical infrastructure. The app team requests a compute admin user and Azure AD Admin team proceeds with the creation of the user in Azure AD.

   You should skip this step, if the group identified in the former step already has a compute admin assigned as member.

   ```bash
   TENANTDOMAIN_COMPUTEAUTHN_IAAS_BASELINE=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   AADOBJECTNAME_USER_COMPUTEADMIN=bu0001a000800-admin
   AADOBJECTID_USER_COMPUTEADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_COMPUTEADMIN} --user-principal-name ${AADOBJECTNAME_USER_COMPUTEADMIN}@${TENANTDOMAIN_COMPUTEAUTHN_IAAS_BASELINE} --force-change-password-next-sign-in --password ChangeMebu0001a0008AdminChangeMe --query id -o tsv)
   echo TENANTDOMAIN_COMPUTEAUTHN_IAAS_BASELINE: $TENANTDOMAIN_COMPUTEAUTHN_IAAS_BASELINE
   echo AADOBJECTNAME_USER_COMPUTEADMIN: $AADOBJECTNAME_USER_COMPUTEADMIN
   echo AADOBJECTID_USER_COMPUTEADMIN: $AADOBJECTID_USER_COMPUTEADMIN
   ```

1. Add the admin user to the compute admin security group.

   > :book: The recently created break-glass admin user is added to the Compute Admin group from Azure AD. After this step the Azure AD Admin team will have finished the app team's request.

   You should skip this step, if the group identified in the former step already has a compute admin assigned as member.

   ```bash
   az ad group member add -g $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE --member-id $AADOBJECTID_USER_COMPUTEADMIN
   ```

### Azure AD Login _[Preferred]_

If you are using a single tenant for this walk-through, the compute deployment step later will take care of the necessary role assignments for the groups created above. Specifically, in the above steps, you created the the Azure AD security group `compute-admins-bu0001a000800` is going to contain compute admins. Those group Object IDs will be associated to the 'Virtual Machine Administrator Login' [RBAC role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-administrator-login).

Using Azure RBAC as your authorization approach is ultimately preferred as it allows for the unified management and access control across Azure Resources, VMs, and VM resources. At the time of this writing there are ten [Azure RBAC roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#compute) that represent typical compute access patterns.

### Save your work-in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

:arrow_forward: [Deploy the hub-spoke network topology](./04-networking.md)
