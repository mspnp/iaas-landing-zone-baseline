# Prep for Azure Active Directory based VM user authentication [Platform team]

Now that you have an [application landing zone awaiting your workload](./04-subscription-vending-execute.md), we'll prepare Azure AD for role-based access control (RBAC) for user access to the virtual machines. This will ensure the application team will have an Azure AD security group(s) and user(s) assigned for group-based remote access, through Azure Bastion.

## Expected results

Following the steps below you will result in an Azure AD configuration that will be used for virtual machine remote access authorization.

| Object                         | Purpose                                   |
| :----------------------------- | :---------------------------------------- |
| A compute admin security group | Represents the group of operators that will contain all virtual machine admin users. |
| Group membership for yourself  | Ensure you are part of the group so that you can access the compute.                 |

This does not configure anything related to workload identities. This configuration is exclusively to set up access to obtain virtual machine access.

### Azure AD login

Using Azure RBAC as your virtual machine user authorization approach is often preferred as it allows for the unified management and access control across Azure Resources, virtual machines, and other resources. You organization instead might desire to use alternative access methods like self-managed SSH keys or domain joined machines. This deployment guide is only set up to use Azure RBAC access; other access methods are beyond the scope of this guide.

### Platform team integration

The platform identity team probably manages your Azure Active Directory groups and group memberships. If security groups and membership have been delegated to application teams, then this process would be performed self-service by the application landing zone team; if not, then it should be an integrated part of the subscription vending process. In this deployment guide, it is sitting between the application landing zone deployment and the start of the application team's work to represent that potential ambiguity.

**We understand that Azure AD access is highly variable from organization to organization and sandbox implementations. If it's impossible to get Azure Active Directory group access configured, then please skip to [Alternative if group management access is not possible in your environment](#alternative-if-group-management-access-is-not-possible-in-your-environment) for a workaround.**

## Steps

> :book: The Contoso Azure AD team requires all operations user access to be security-group based. This applies to the new virtual machines that are being created for this solution. Virtual machine access will be exclusively AAD-backed and access granted based on users' AAD group membership(s).

1. Create/identify the Azure AD security group to be given admin access to the virtual machines.

   If you already have a security group that is appropriate for your compute's admin user accounts, use that group and don't create a new one. If using your own group or your Azure AD administrator created one for you to use as part of the subscription vending landing zone process; set that Object ID below.

   ```bash
   export AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE="Paste your existing compute admin group Object ID (guid) in these quotes."
   echo AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE: $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE
   ```

   If you want to create a new one instead, and have the permissions to do so, you can use the following command:

   ```bash
   export AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE=$(az ad group create --display-name 'compute-admins-bu04a42' --mail-nickname 'compute-admins-bu04a42' --description "Principals in this group are compute admins in the bu04a42 virtual machines." --query id -o tsv)
   echo AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE: $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE
   ```

   This Azure AD group object ID will be used later while creating the virtual machines so that once the virtual machines gets deployed the identified group will get the proper Azure role assignment to be able to login.

1. Add yourself to the security group, _if not already in it_.

   If you used a pre-existing security group use whatever process you need in order to get your personal identity added.

   If instead followed the instructions above to create a new security group, you can use the follow command to add yourself:

   ```bash
   az ad group member add -g $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE --member-id $(az ad signed-in-user show --query id -o tsv)
   ```

### Alternative if group management access is not possible in your environment

If an existing suitable group is not available or access to do the above is not possible, please execute the following and the deployment guide will provide RBAC access to _your user_ directly instead of being group-based.

```bash
export AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE=""
export AADOBJECTID_SIGNEDINUSER_IAAS_BASELINE="$(az ad signed-in-user show --query "id" -o tsv)"
echo AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE: $AADOBJECTID_GROUP_COMPUTEADMIN_IAAS_BASELINE
echo AADOBJECTID_SIGNEDINUSER_IAAS_BASELINE: $AADOBJECTID_SIGNEDINUSER_IAAS_BASELINE
```

### Final thoughts

For your eventual actual workload deployment, follow your organization's best practices around providing virtual machine break-glass accounts, group-based access, conditional access, just-in-time configuration, etc. This deployment guide's group based access configuration is just one example of what this process might look like. It does result in standing admin permissions, which might not be desireable.

### Save your work-in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to iaas_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source iaas_baseline.env
```

### Next step

> The vending process is now complete and the application team will now start using their new subscription for their solution, complete with Azure AD configured. The platform team is not involved in the deployment of the actual solution's architecture. Once the application team starts deploying resources into their subscription, the vending process is considered frozen as re-running the complete vending process would potentially render the workload inoperable as it is non-idempotent.

This is the last step in which you'll be directly acting in the role of someone on the platform team. Thanks for role playing that role. From this point forward, you now will be deploying the IaaS baseline architecture into your prepared application landing zone.

:arrow_forward: Let's start by [getting your TLS certificates ready for workload deployment](./05-ca-certificates.md)
