#!/bin/bash

CYAN='\033[0;36m'
LIGHTBLUE='\033[1;34m'
RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

curl -s https://raw.githubusercontent.com/zunxbt/logo/main/logo.sh | bash
sleep 3

echo -e "\n${CYAN}${BOLD}---- CHECKING DOCKER INSTALLATION ----${RESET}\n"
if ! command -v docker &> /dev/null; then
  echo -e "${RED}${BOLD}Docker is not installed and cannot install it without root permissions.${RESET}"
  echo -e "${RED}${BOLD}Please install Docker manually or run this script as root.${RESET}"
  exit 1
fi

echo -e "${GREEN}${BOLD}Docker is installed!${RESET}"

if ! docker info &>/dev/null; then
  echo -e "${RED}${BOLD}Docker is not accessible (needs root or proper group permissions).${RESET}"
  echo -e "${RED}${BOLD}Either run this script as root or configure Docker access manually.${RESET}"
  exit 1
fi

echo -e "${GREEN}${BOLD}Docker is accessible and working without sudo.${RESET}"

echo -e "\n${CYAN}${BOLD}---- INSTALLING DEPENDENCIES ----${RESET}\n"
if ! command -v apt-get &> /dev/null; then
  echo -e "${RED}${BOLD}apt-get not available. Please install dependencies manually (curl, screen, net-tools, psmisc, jq).${RESET}"
else
  apt-get update
  apt-get install -y curl screen net-tools psmisc jq
fi

[ -d "$HOME/.aztec/alpha-testnet" ] && rm -r "$HOME/.aztec/alpha-testnet"

AZTEC_PATH=$HOME/.aztec
BIN_PATH=$AZTEC_PATH/bin
mkdir -p $BIN_PATH

echo -e "\n${CYAN}${BOLD}---- INSTALLING AZTEC TOOLKIT ----${RESET}\n"
curl -fsSL https://install.aztec.network | bash

if ! command -v aztec >/dev/null 2>&1; then
    echo -e "${LIGHTBLUE}${BOLD}Aztec CLI not found in PATH. Adding it for current session...${RESET}"
    export PATH="$PATH:$HOME/.aztec/bin"
    
    if ! grep -Fxq 'export PATH=$PATH:$HOME/.aztec/bin' "$HOME/.bashrc"; then
        echo 'export PATH=$PATH:$HOME/.aztec/bin' >> "$HOME/.bashrc"
        echo -e "${GREEN}${BOLD}Added Aztec to PATH in .bashrc${RESET}"
    fi
fi

[ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile"
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
export PATH="$PATH:$HOME/.aztec/bin"

if ! command -v aztec &> /dev/null; then
  echo -e "${RED}${BOLD}ERROR: Aztec installation failed. Please check the logs above.${RESET}"
  exit 1
fi

echo -e "\n${CYAN}${BOLD}---- UPDATING AZTEC TO ALPHA-TESTNET ----${RESET}\n"
aztec-up alpha-testnet

echo -e "\n${CYAN}${BOLD}---- CONFIGURING NODE ----${RESET}\n"
IP=$(curl -s https://api.ipify.org)
[ -z "$IP" ] && IP=$(curl -s http://checkip.amazonaws.com)
[ -z "$IP" ] && IP=$(curl -s https://ifconfig.me)
[ -z "$IP" ] && read -p "Could not detect IP. Enter manually: " IP

echo -e "${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://dashboard.alchemy.com/apps${RESET}${LIGHTBLUE}${BOLD} or ${PURPLE}https://developer.metamask.io/register${RESET}${LIGHTBLUE}${BOLD} to get Sepolia RPC.${RESET}"
read -p "Enter Sepolia Ethereum RPC URL: " L1_RPC_URL

echo -e "\n${LIGHTBLUE}${BOLD}Visit ${PURPLE}https://chainstack.com/global-nodes${RESET}${LIGHTBLUE}${BOLD} to get BEACON URL.${RESET}"
read -p "Enter Sepolia Ethereum BEACON URL: " L1_CONSENSUS_URL

echo -e "\n${LIGHTBLUE}${BOLD}Provide your EVM wallet private key (funded with Sepolia ETH).${RESET}"
read -p "Enter wallet private key (0x...): " VALIDATOR_PRIVATE_KEY
read -p "Enter wallet address: " COINBASE_ADDRESS

echo -e "\n${CYAN}${BOLD}---- CHECKING PORT AVAILABILITY ----${RESET}\n"
if netstat -tuln | grep -q ":8080 "; then
    echo -e "${RED}${BOLD}Port 8080 is in use. Cannot free it without root access.${RESET}"
    echo -e "${RED}${BOLD}Please stop the conflicting process manually or run with elevated permissions.${RESET}"
    exit 1
else
    echo -e "${GREEN}${BOLD}Port 8080 is available.${RESET}"
fi

echo -e "\n${CYAN}${BOLD}---- STARTING AZTEC NODE ----${RESET}\n"
cat > "$HOME/start_aztec_node.sh" << EOL
#!/bin/bash
export PATH=\$PATH:\$HOME/.aztec/bin
aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --port 8080 \\
  --l1-rpc-urls $L1_RPC_URL \\
  --l1-consensus-host-urls $L1_CONSENSUS_URL \\
  --sequencer.validatorPrivateKey $VALIDATOR_PRIVATE_KEY \\
  --sequencer.coinbase $COINBASE_ADDRESS \\
  --p2p.p2pIp $IP \\
  --p2p.maxTxPoolSize 1000000000
EOL

chmod +x "$HOME/start_aztec_node.sh"
screen -dmS aztec "$HOME/start_aztec_node.sh"

echo -e "${GREEN}${BOLD}Aztec node started successfully in a screen session.${RESET}\n"
