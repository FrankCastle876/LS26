# Vulnerability report

### SMB service

SMB service was open on ports 445 and 139. This was not confirmed as malicious, but since it does not need to run (per instructions) it should be disabled to reduce the attack surface.  

### Port knocking

There is a port knocking service called "knockd" which is shut down but **enabled**. Said service could serve as access for attackers after reboot. This should be at least disabled.  

### Password hashing  

