platform-helper is a collection of Bash shell scripts that provide several helper functions in a platform independant manner.

# Credential Management
- **cred manager unlock** using ssh, has to run interactively using --interactive, otherwise credential manager locks when SSH is done
```
SshHelper -i pi1 'cred manager lock'

# stays unlocked
SshHelper --credential --interactive pi1 'credential manager unlock;'

# locks after 10 seconds, not interactive
SshHelper --credential pi1 'credential manager unlock; credential manager status; sleep 10'
```