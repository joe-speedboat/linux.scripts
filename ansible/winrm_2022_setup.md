# Setup Winrm for ansible with HTTPS self signed certs
## DESCRIPTION:
Enable and setup winrm on windows 2022 server

## Ansible WinRM

### WinRM HTTPS Setup
```
# Setup HTTPS WinRM
$hostname = $env:computername
$isRunningService = (Get-Service winrm).Status -eq "Running"

if (-not ($isRunningService -eq $true)) {
  Write-Host "Starting WinRM service..."
  Start-Service winrm
}

Write-Host "Generating self-signed SSL certificate..."
$certificateThumbprint = (New-SelfSignedCertificate -DnsName "${hostname}" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint

Write-Host "Configuring WinRM to listen on HTTPS..."
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"${hostname}`"; CertificateThumbprint=`"${certificateThumbprint}`"}"

Write-Host "Updating firewall..."
netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=5986

Get-Service winrm
winrm enumerate winrm/config/Listener
```

##### Control Node
```
# as root
# find python version for ansible
ansible --version
dnf install python3-pip

# as user (s_ruettimc)
pip3.9 install --user pywinrm
ansible-galaxy collection install ansible.windows

echo "[win_hosts]
finswpx01.admin.unibas.ch

[win_hosts:vars]
ansible_port=5986
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
ansible_user=Administrator
ansible_password=changeMe...
" > /etc/ansible/hosts

ansible -m win_ping win_hosts
```
