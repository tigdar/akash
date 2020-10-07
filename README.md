# akash
## Utilities for Akash Network


### akash-delegate.sh

A script which lets to claim rewards and re-delegate back to your validator.

#### Pre-requisites

1. akashctl, curl, jq are installed and available on path.

#### Instructions.

1. Download the script. Change permissions. `curl -LO https://raw.githubusercontent.com/tigdar/akash/main/akash-redelegate.sh && chmod +x akash-redelegate.sh`
2. Edit the script and modify the parameters mentioned in "User Settings" section. Bare minimum settings are - your local akash wallet name and validator name.
3. Execute the script `./akash-redelegate.sh`


#### To be improved...
On Ubuntu 20.04 LTS using Gnome Keyring, the default passphrase is saved to keyring backed and hence, if you configure the PASSPHRASE param in the script, it will auto-execute with no more prompts.

However, on Ubuntu 18.04 LTS server (since there is no keyring backend configured by default), `akashctl keys show $KEY --output json` will prompt for passphrase.

