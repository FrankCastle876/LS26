# Vulnerability report

### SMB service

SMB service was open on ports 445 and 139. This was not confirmed as malicious, but since it does not need to run (per instructions) it should be disabled to reduce the attack surface.  

### Port knocking

There is a port knocking service called "knockd" which is shut down but **enabled**. Said service could serve as access for attackers after reboot (persistence). This should be at least disabled.  

### Password hashing  

Insecure encryption methods were found in two configuration files (DES):
 - /etc/login.defs
 - /etc/pam.d/common-password

This could lead to hash cracking (if the attacker would get access) which would leave the attacker with plain text passwords and access trough all users. In both files the encrytion method should be changed to yescrypt and all passwords should be changed. 

### Unbound user is insecure

In /etc/shadow "unbound" user is enabled but no password set. Combined with the fact that empty passwords are allowed in /etc/ssh/sshd_config means that attacker could connect to the VM without having any passwords. User in question also has all sudo access with no password needed in /etc/sudoers giving the attacker root access. Permissions should be striped, ssh config file should be corrected to demand passwords and this user should have a password set.  

### Unsecure permissions  

In /etc/does.conf file permissions are set for all in "users" group with no need for a password. This would give an attacker ulimitied access to the system as soon as he gained access to anyone in this group. File should be correct to only allow users in "root" group.

### SSH key added 

In /etc/ssh/sshd_config.d allowing keys in "ssh_host_echd_key". The key is present. SSH key injection would lead to persistence by an attacker. This has to be deleted from settings.  

### SUID bit set  

SUID bit is set to "pexec". This program is vulnerable with this setting since it would allow an attacker to spawn an elevated shell on the system. SUID bit should be taken from this binary.  

### FTP service  

Ftp service is open on port 21 (only for IPv6). It's version (3.0.5) is vulnerable to CVE-2021-3618 which allows traffic redirection by an attacker compromising it's integrity. Service should be terminated.  

### Webserver vulnerabilities  

Podman container was run with --privileged and "/:/mnt" volume allowing container escape, gaining access to the system. Stop and remove this container and run it again with more secure options. 

### MySql misconfiguration  

In /lib/systemd/system/mysql.service the execution command has option "--skip-grant-tables" included. Which would allow any user to connect to the database as any user without providing a password. This option should be edited out, so that users need to provide passwords. 

### Unbound vulnerabilities  

Unbound has remore control enabled over IPv6 in file /etc/unbound/unbound.conf.d/remote-control.conf. This could allow a malicious actor to gain access. This should be disabled for security.  

