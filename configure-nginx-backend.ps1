<#
    .SYNOPSIS
        Downloads, configures Nginx as workload sample and process its requests.
#>

# Initialize Managed Data Disk
$dataDisk = (Get-Disk | Where partitionstyle -eq 'raw' | sort number)[0]
$dataDisk | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -UseMaximumSize -DriveLetter 'W' | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'dataDisk' -Confirm:$false -Force

# Firewall config
netsh advfirewall firewall add rule name="http" dir=in action=allow protocol=TCP localport=80
netsh advfirewall firewall add rule name="https" dir=in action=allow protocol=TCP localport=443

# Download nginx.
cd w:\
Invoke-WebRequest 'https://nginx.org/download/nginx-1.24.0.zip' -OutFile 'w:/nginx.zip'

# Install Nginx.
Expand-Archive w:/nginx.zip w:/
Move-Item w:/nginx-1.24.0 w:/nginx

# Create addtional folders
New-Item -ItemType Directory w:/nginx/ssl
New-Item -ItemType Directory w:/nginx/data

# Export Ssl crt and pfx from LocalMachine
$cert = Get-ChildItem -path Cert:\* -Recurse | where {$_.Subject -eq 'O=Contoso IaaS Ingresses, CN=*.iaas-ingress.contoso.com'}

@(
 '-----BEGIN CERTIFICATE-----'
 [System.Convert]::ToBase64String($cert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks)
 '-----END CERTIFICATE-----'
) | Out-File -FilePath w:/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.crt -Encoding ascii

$rsaKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$keyBytes = $rsaKey.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
@(
 '-----BEGIN RSA PRIVATE KEY-----'
 [System.Convert]::ToBase64String($keyBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
 '-----END RSA PRIVATE KEY-----'
) | Out-File -FilePath w:/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.key -Encoding ascii

# Create home page.
Invoke-WebRequest 'https://raw.githubusercontent.com/mspnp/aks-baseline/main/workload/index.html' -OutFile 'w:/nginx/html/index.html'

# Configure Nginx with root page, ssl, healt probe endpoint, and reverse proxy
@"
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    gzip  off;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

    server {
        listen 443 ssl;
        server_name bu0001a0008-00-backend.iaas-ingress.contoso.com;
        ssl_certificate w:/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.crt;
        ssl_certificate_key w:/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.key;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

        root w:/nginx/html;

        location / {
            access_log w:/nginx/logs/bu0001a0008.log combined buffer=10K flush=1m;
            index index.html;
            sub_filter '[backend]' '`$hostname';
            sub_filter_once off;
        }

        location = /favicon.ico {
            empty_gif;
            access_log off;
        }
    }
}
"@ | Out-File -FilePath w:/nginx/conf/nginx.conf -Encoding ascii

# Start nginx
cd w:/nginx
start nginx

# Task Scheduler to rotate and process workload total number of requests.

# Initialize processed request count data file
"0" | Out-File -FilePath w:/nginx/data/bu0001a0008.data -Encoding ascii

# Create rotation processing requests script
@"
# Renaming
Move-Item -Path w:/nginx/logs/bu0001a0008.log -Destination w:/nginx/logs/bu0001a0008.log.rot -Force

# Send USR1
cd w:/nginx
./nginx.exe -s reopen

# Process rotated log
`$lastProcessedRequestCount = (Get-Content w:/nginx/logs/bu0001a0008.log.rot | Measure-Object -Line).Lines

# Get current number of processed requests
`$currentProcessedRequestCount = (Get-Content w:/nginx/data/bu0001a0008.data)

# Write total number of processed requests
`$totalProcessedRequestCount = (`$lastProcessedRequestCount + `$currentProcessedRequestCount)
`$totalProcessedRequestCount | Out-File -FilePath w:/nginx/data/bu0001a0008.data -Force -Encoding ascii

# Get last write time
`$lastWriteTime = ((Get-Item w:/nginx/data/bu0001a0008.data).LastWriteTime).GetDateTimeFormats('u')

# Update workload content with total processed requests
`$updatedCount = [string]::Format('<h2>Welcome to the Contoso WebApp! Your request has been load balanced through [frontend] and [backend] {{Total Processed Requests: {0}, Last Update Time: {1}}}.</h2>', `$totalProcessedRequestCount, [string]`$lastWriteTime)
((Get-Content W:\nginx\html\index.html) -replace '(\s*)<h2>[\s\S]+</h2>(\s*)', `$updatedCount) | Set-Content -Path w:/nginx/html/index.html
"@ | Out-File -FilePath w:/nginx/rotate-process-nginx-backend-logs.ps1 -Encoding ascii

#Task Scheduler
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Unrestricted -File w:/nginx/rotate-process-nginx-backend-logs.ps1' -WorkingDirectory 'w:/nginx/'
$trigger = New-ScheduledTaskTrigger -Daily -At 12am
$task = Register-ScheduledTask -TaskName "Rotate and process workload logs" -Trigger $trigger -Action $action -Principal $principal
$task.Triggers.Repetition.Duration = "P1D"
$task.Triggers.Repetition.Interval = "PT2M"
$task | Set-ScheduledTask
