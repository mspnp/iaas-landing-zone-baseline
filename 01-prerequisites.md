# Install and meet the prerequisites

This is the starting point for deploying the [IaaS baseline reference implementation](./README.md). Follow the instructions below and on the subsequent pages to get your environment ready.

| :clock10: | These steps are intentionally verbose, intermixed with context, narrative, and guidance. The deployments are all conducted via [Bicep templates](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview), but they are executed manually via `az cli` commands. We strongly encourage you to dedicate time to walk through these instructions, with a focus on learning. By design, there is no "one click" method to complete all deployments.<br><br>Once you understand the components involved and have identified the shared responsibilities between your team and your platform team, you are encouraged to build suitable, repeatable deployment processes around your final infrastructure and bootstrapping. The [DevOps architecture design](https://learn.microsoft.com/azure/architecture/guide/devops/devops-start-here) is a great place to learn best practices to build your own automation pipelines. |
| :-------: | :------------------------ |

## Requirements

- An Azure subscription.

   The subscription used in this deployment cannot be a [free account](https://azure.microsoft.com/free); it must be a standard EA, pay-as-you-go, or Visual Studio benefit subscription. This is because the resources deployed here are often beyond the quotas of free subscriptions.

   This subscription is expected to NOT be an actual Azure application landing zone subscription. This is expected be deployed within a sandbox subscription offered by your organization, as long as it meets the following requirements.

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure Role-Based Access Control (RBAC) roles:
   >
   > - [Contributor role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is _required_ at the subscription level to have the ability to create resource groups and perform deployments.
   > - [User Access Administrator role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is _required_ at the subscription level since you'll be performing role assignments to managed identities across various resource groups.
   > - [Resource Policy Contributor role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#resource-policy-contributor) is _required_ at the subscription level since you'll be creating custom Azure policy definitions to govern resources in your compute.

- An Azure AD tenant to associate your compute authentication to.

   **TODO-CK: Align this with final requirements**

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure AD permissions assigned:
   >
   > - Azure AD [User Administrator](https://learn.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions) is _required_ to create a "break glass" compute admin Active Directory Security Group and User. Alternatively, you could get your Azure AD admin to create this for you when instructed to do so.
   >   - If you are not part of the User Administrator group in the tenant associated to your Azure subscription, please consider [creating a new tenant](https://learn.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation. The Azure AD tenant backing your login users does NOT need to be the same tenant associated with your Azure subscription.

- Latest [Azure CLI installed](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) (must be at least 2.49), or you can perform this from Azure Cloud Shell.

   [![Launch Azure Cloud Shell](https://learn.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

- Ensure [OpenSSL is installed](https://github.com/openssl/openssl#download) to generate self-signed certificates used in this implementation. _OpenSSL is already installed in Azure Cloud Shell._

   > :warning: Some shells may have the `openssl` command aliased for LibreSSL. LibreSSL will not work with the instructions found here. You can check this by running `openssl version` and you should see output that says `OpenSSL <version>` and not `LibreSSL <version>`.

## Get started

1. Clone or download this repo locally. Consider forking the repo first, for a better experience.

   ```bash
   git clone https://github.com/mspnp/iaas-landing-zone-baseline.git
   cd iaas-landing-zone-baseline
   ```

   > :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://learn.microsoft.com/windows/wsl/about) to run Bash.

### Next step

:arrow_forward: [Deploy mock connectivity subscription](./02-connectivity-subscription.md)
