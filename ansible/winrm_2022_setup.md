# Setup Winrm for ansible with HTTPS self signed certs
## DESCRIPTION:
Enable and setup winrm on windows 2022 server

## NOTES:

```
# Enable WinRM
Enable-PSRemoting -Force

# Create a self-signed certificate for HTTPS
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My"

# Configure WinRM to use HTTPS
winrm quickconfig -transport:https
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Basic="false"}'
winrm set winrm/config/client/auth '@{Basic="false";Digest="false";Kerberos="true";Negotiate="true";Certificate="false";CredSSP="false"}'
winrm set winrm/config/client '@{AllowUnencrypted="false"}'

# Create WinRM listener using HTTPS with the self-signed certificate
winrm create winrm/config/Listener?Address=*+Transport=HTTPS '@{Hostname="localhost";CertificateThumbprint="'"$($cert.Thumbprint)"'";port="5986"}'

# Add firewall rule for HTTPS
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "Windows Remote Management (HTTPS-In)" -Profile Any -LocalPort 5986 -Protocol TCP -Action Allow

# Restart the WinRM service
Restart-Service WinRM

```
