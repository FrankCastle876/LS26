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

