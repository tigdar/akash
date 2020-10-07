#!/bin/bash -e

# This script comes without warranties of any kind. Use at your own risk.

# The purpose of this script is to withdraw rewards (if any) and delegate them to an appointed validator. This way you can reinvest (compound) rewards.

# Requirements: akashctl (v0.8.2), curl and jq must be in the path.


##############################################################################################################################################################
# User settings. (Change these values to match your requirements)
##############################################################################################################################################################

KEY=""                                  # This is the key you wish to use for signing transactions, listed in first column of "akashctl keys list".
PASSPHRASE=""                           # Only populate if you want to run the script periodically. This is UNSAFE and should only be done if you know what you are doing.
DENOM="uakt"                           # Coin denominator is uakt ("microoakash"). 1 akt = 1000000 uakt.
MINIMUM_DELEGATION_AMOUNT="25000000"    # Only perform delegations above this amount of uakt. Default: 25akt.
RESERVATION_AMOUNT="100000000"          # Keep this amount of uatom in account. Default: 100akt.
VALIDATOR="akashvaloper1sqrcxk0zxx6uwpjl5ylug2pd467vyxzt4sqze7"        # Default is Tigdar Validator. Thank you for your patronage :-)

##############################################################################################################################################################


##############################################################################################################################################################
# Sensible defaults.
##############################################################################################################################################################

CHAIN_ID="akashnet-1"                                     # Current chain id. Empty means auto-detect.
NODE="tcp://rpc.v.boz.sh:26657"  # Either run a local full node or choose one you trust.
GAS_PRICES="0.025uakt"                         # Gas prices to pay for transaction.
GAS_ADJUSTMENT="1.30"                           # Adjustment for estimated gas
GAS_FLAGS="--gas auto --gas-prices ${GAS_PRICES} --gas-adjustment ${GAS_ADJUSTMENT}"

##############################################################################################################################################################

# --chain-id=akashnet-1
# Auto-detect chain-id if not specified.
if [ -z "${CHAIN_ID}" ]
then
  NODE_STATUS=$(curl -s --max-time 5 ${NODE}/status)
  CHAIN_ID=$(echo ${NODE_STATUS} | jq -r ".result.node_info.network")
fi

# Use first command line argument in case KEY is not defined.
if [ -z "${KEY}" ] && [ ! -z "${1}" ]
then
  KEY=${1}
fi

# Get information about key
KEY_STATUS=$(akashctl keys show ${KEY} --output json)
KEY_TYPE=$(echo ${KEY_STATUS} | jq -r ".type")
if [ "${KEY_TYPE}" == "ledger" ]
then
    SIGNING_FLAGS="--ledger"
fi



# Get current account balance.
ACCOUNT_ADDRESS=$(echo ${KEY_STATUS} | jq -r ".address")
ACCOUNT_STATUS=$(akashctl query account ${ACCOUNT_ADDRESS} --chain-id=${CHAIN_ID} --node=${NODE} --output json)
ACCOUNT_SEQUENCE=$(echo ${ACCOUNT_STATUS} | jq -r ".value.sequence")
ACCOUNT_BALANCE=$(echo ${ACCOUNT_STATUS} | jq -r ".value.coins[] | select(.denom == \"${DENOM}\") | .amount" || true)
if [ -z "${ACCOUNT_BALANCE}" ]
then
    # Empty response means zero balance.
    ACCOUNT_BALANCE=0
fi

# Get available rewards.
REWARDS_STATUS=$(akashctl query distribution rewards ${ACCOUNT_ADDRESS} --chain-id=${CHAIN_ID} --node=${NODE} --output json)
if [ "${REWARDS_STATUS}" == "null" ]
then
    # Empty response means zero balance.
    REWARDS_BALANCE="0"
else
    #REWARDS_BALANCE=$(echo ${REWARDS_STATUS} | jq -r ".[] | select(.denom == \"${DENOM}\") | .amount" || true)
    REWARDS_BALANCE=$(echo ${REWARDS_STATUS} | jq '.total[0].amount | tonumber' || true)
    if [ -z "${REWARDS_BALANCE}" ] || [ "${REWARDS_BALANCE}" == "null" ]
    then
        # Empty response means zero balance.
        REWARDS_BALANCE="0"
    else
        # Remove decimals.
        REWARDS_BALANCE=${REWARDS_BALANCE%.*}
    fi
fi


# Get available commission.
VALIDATOR_ADDRESS=$(akashctl keys show ${KEY} --bech val --address)
COMMISSION_STATUS=$(akashctl query distribution commission ${VALIDATOR_ADDRESS} --chain-id=${CHAIN_ID} --node=${NODE} --output json)
if [ "${COMMISSION_STATUS}" == "null" ]
then
    # Empty response means zero balance.
    COMMISSION_BALANCE="0"
else
    COMMISSION_BALANCE=$(echo ${COMMISSION_STATUS} | jq -r ".[] | select(.denom == \"${DENOM}\") | .amount" || true)
    if [ -z "${COMMISSION_BALANCE}" ]
    then
        # Empty response means zero balance.
        COMMISSION_BALANCE="0"
    else
        # Remove decimals.
        COMMISSION_BALANCE=${COMMISSION_BALANCE%.*}
    fi
fi

# Calculate net balance and amount to delegate.
NET_BALANCE=$((${ACCOUNT_BALANCE} + ${REWARDS_BALANCE} + ${COMMISSION_BALANCE}))
if [ "${NET_BALANCE}" -gt $((${MINIMUM_DELEGATION_AMOUNT} + ${RESERVATION_AMOUNT})) ]
then
    DELEGATION_AMOUNT=$((${NET_BALANCE} - ${RESERVATION_AMOUNT}))
else
    DELEGATION_AMOUNT="0"
fi

# Display what we know so far.
echo "======================================================"
echo "Account: ${KEY} (${KEY_TYPE})"
echo "Address: ${ACCOUNT_ADDRESS}"
echo "======================================================"
echo "Account balance:      ${ACCOUNT_BALANCE}${DENOM}"
echo "Available rewards:    ${REWARDS_BALANCE}${DENOM}"
echo "Available commission: ${COMMISSION_BALANCE}${DENOM}"
echo "Net balance:          ${NET_BALANCE}${DENOM}"
echo "Reservation:          ${RESERVATION_AMOUNT}${DENOM}"
echo

if [ "${DELEGATION_AMOUNT}" -eq 0 ]
then
    echo "Nothing to delegate."
    exit 0
fi

# Display delegation information.
VALIDATOR_STATUS=$(akashctl query staking validator ${VALIDATOR} --chain-id=${CHAIN_ID} --node=${NODE} --trust-node --output json)
VALIDATOR_MONIKER=$(echo ${VALIDATOR_STATUS} | jq -r ".description.moniker")
VALIDATOR_DETAILS=$(echo ${VALIDATOR_STATUS} | jq -r ".description.details")
echo "You are about to delegate ${DELEGATION_AMOUNT}${DENOM} to ${VALIDATOR}:"
echo "  Moniker: ${VALIDATOR_MONIKER}"
echo "  Details: ${VALIDATOR_DETAILS}"
echo

# Ask for passphrase to sign transactions.
if [ -z "${SIGNING_FLAGS}" ] && [ -z "${PASSPHRASE}" ]
then
    read -s -p "Enter passphrase required to sign for \"${KEY}\": " PASSPHRASE
    echo ""
fi

# Run transactions
MEMO=$'Reinvesting rewards @ Validator\xF0\x9F\x8C\x90Network'
if [ "${REWARDS_BALANCE}" -gt 0 ]
then
    printf "Withdrawing rewards... "
    echo ${PASSPHRASE} | akashctl tx distribution withdraw-all-rewards --yes --from ${KEY} --sequence ${ACCOUNT_SEQUENCE} --chain-id=${CHAIN_ID} --node=${NODE} ${GAS_FLAGS} ${SIGNING_FLAGS} --memo "${MEMO}" --broadcast-mode async
    ACCOUNT_SEQUENCE=$((ACCOUNT_SEQUENCE + 1))
fi

if [ "${COMMISSION_BALANCE}" -gt 0 ]
then
    printf "Withdrawing commission... "
    echo ${PASSPHRASE} | akashctl tx distribution withdraw-rewards ${VALIDATOR_ADDRESS} --commission --yes --from ${KEY} --sequence ${ACCOUNT_SEQUENCE} --chain-id=${CHAIN_ID} --node=${NODE} ${GAS_FLAGS} ${SIGNING_FLAGS} --memo "${MEMO}" --broadcast-mode async
    ACCOUNT_SEQUENCE=$((ACCOUNT_SEQUENCE + 1))
fi

printf "Delegating... "
echo ${PASSPHRASE} | akashctl tx staking delegate ${VALIDATOR} ${DELEGATION_AMOUNT}${DENOM} --yes --from ${KEY} --sequence ${ACCOUNT_SEQUENCE} --chain-id=${CHAIN_ID} --node=${NODE} ${GAS_FLAGS} ${SIGNING_FLAGS} --memo "${MEMO}" --broadcast-mode async

echo
echo "Thank you for powering Akash Network!"
