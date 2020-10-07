# akash
## Utilities for Akash Network


### akash-delegate.sh

A script which lets to claim rewards and re-delegate back to your validator.

#### Pre-requisites

1. akashctl, curl, jq are installed and available on path.

#### Instructions.

1. Download the script. Change permissions. `curl https://raw.githubusercontent.com/tigdar/akash/main/akash-redelegate.sh && chmod +x akash-redelegate.sh`
2. Edit the script and modify the parameters mentioned in "User Settings" section. Bare minimum settings are - your local akash wallet name and validator name.
3. Execute the script `./akash-redelegate.sh`

#### Optional

Script can be scheduled via cron to run at frequent intervals to collect rewards and re-delegate.

Tested on Ubuntu 20.04 LTS
