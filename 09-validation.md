# Perform end-to-end validation [Workload team]

Now that you have [validated the compute infrastructure is operational](./08-boostrap-validation.md), you can start validating and exploring the rest of the reference implementation of the [IaaS baseline](./). In addition to the workload, there are some observability validation you can perform as well.

## Validate the Contoso web app

This section will help you to validate the workload is exposed correctly and responding to HTTP requests.

### Steps

1. Get the public IP address of Application Gateway.

   > :book: The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

   ```bash
   # query the Azure Application Gateway Public Ip
   APPGW_PUBLIC_IP=$(az deployment group show -g rg-alz-bu04a42-spoke -n apply-networking --query properties.outputs.appGwPublicIpAddress.value -o tsv)
   echo APPGW_PUBLIC_IP: $APPGW_PUBLIC_IP
   ```

1. Create an `A` record for DNS.

   > :bulb: You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, please edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end: `${APPGW_PUBLIC_IP}  contoso.com` (e.g. `50.140.130.120  contoso.com`)

1. Validate your workload is reachable over internet through your Azure Application Gateway public endpoint

   ```bash
   curl https://contoso.com --resolve contoso.com:443:$APPGW_PUBLIC_IP -k
   ```

1. Browse to the site.

   > :bulb: Remember to include the protocol prefix `https://` in the URL you type in the address bar of your browser. A TLS warning will be present due to using a self-signed certificate. You can ignore it or import the self-signed cert (`appgw.pfx`) to your user's trusted root store.

   ```bash
   open https://contoso.com
   ```

   Refresh the web page a couple of times and observe the frontend and backend values `Machine name` displayed at the top of the page. As the Application Gateway and Internal Load Balancer balances the requests between the tiers, the machine names will change from one machine name to the other throughout your queries.

## Validate web application firewall functionality

Your workload is placed behind a Web Application Firewall (WAF), which has rules designed to stop intentionally malicious activity. You can test this by triggering one of the built-in rules with a request that looks malicious.

> :bulb: This reference implementation enables the built-in OWASP ruleset, in **Prevention** mode.

### Steps

1. Browse to the site with the following appended to the URL: `?sql=DELETE%20FROM` (e.g. <https://contoso.com/?sql=DELETE%20FROM>).
1. Observe that your request was blocked by Application Gateway's WAF rules and your workload never saw this potentially dangerous request.
1. Blocked requests (along with other gateway data) will be visible in the attached Log Analytics workspace.

   Browse to the Application Gateway in the resource group `rg-bu0001-a0008` and navigate to the _Logs_ blade. Execute the following query below to show WAF logs and see that the request was rejected due to a _SQL Injection Attack_ (field _Message_).

   > :warning: Note that it may take a couple of minutes until the logs are transferred from the Application Gateway to the Log Analytics Workspace. So be a little patient if the query does not immediatly return results after sending the https request in the former step.

   ```
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
   ```

## Validate Azure Monitor VM insights and logs

Monitoring your compute infrastructure is critical, especially when you're running in production. Therefore, your VMs are configured with [boot diagnostics](https://learn.microsoft.com/troubleshoot/azure/virtual-machines/boot-diagnostics) and to send [diagnostic information](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings?tabs=portal) to the Log Analytics Workspace deployed as part of the [bootstrapping step](./05-bootstrap-prep.md).

```bash
az vm boot-diagnostics get-boot-log --ids $(az vm list -g rg-bu0001a0008 --query "[].id" -o tsv)
```

### Steps

1. In the Azure Portal, navigate to your VM resources.
1. Click _Insights_ to see captured data. For more information please take a look at <https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-overview>

You can also execute [queries](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-tutorial) on the [VM Insights logs captured](https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-log-query).

1. In the Azure Portal, navigate to your VMSS resources.
1. Click _Logs_ to see and query log data.

## Next step

:arrow_forward: [Clean Up Azure Resources](./10-cleanup.md)
