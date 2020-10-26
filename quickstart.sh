#!/usr/bin/env bash

SG_LOAD_LIBS=(gnusafe helpers trap_helper traplib)

# Run ShellCore auto-install if we can't detect an existing ShellCore load.sh file.
[[ -f "${HOME}/.pv-shcore/load.sh" ]] || [[ -f "/usr/local/share/pv-shcore/load.sh" ]] || \
    { curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail

# Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
[[ -d "${HOME}/.pv-shcore" ]] && source "${HOME}/.pv-shcore/load.sh" || \
    source "/usr/local/share/pv-shcore/load.sh" || _sc_fail

gnusafe || exit 1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

has_cmd() { command -v "$1" &> /dev/null; }

dkr() {
  (( EUID == 0 )) && docker "$@" || sudo docker "$@"
}

NL=$'\n'

error_control 0

if ! has_cmd docker; then
  msgerr bold red " [!!!] Docker isn't yet installed."
  msgerr bold yellow " [...] Please wait while we automatically install Docker for you :)"
  pkg_not_found curl curl
  curl -fsSL https://get.docker.com | bash
  msgerr bold green "\n\n [+++] Successfully installed Docker!\n"
fi

msgerr bold green " >>> Automatically updating / installing docker image 'privex/koinos-miner'"

dkr pull privex/koinos-miner

if [[ ! -f "${DIR}/.env" ]]; then
  msgerr yellow  " !!! It looks like you don't yet have a '.env' file. We'll help you make one :)\n"
  msgerr magenta "You'll need the following two pieces of information before you can setup your .env:\n"

  msgerr cyan    "        - The Ethereum address that you want your mining rewards to be paid into."
  msgerr cyan    "          An Ethereum address looks like this: ${BOLD}0x2e8687E5349f38e833F9111b25761B903902AdC0"
  msgerr
  msgerr cyan    "        - The ${BOLD}PRIVATE KEY${RESET}${CYAN} for an Ethereum address which is funded with some ETH.\n"

  msgerr cyan    "          We recommend that you have at least 0.05 ETH (\$20.00) to start with, as"
  msgerr cyan    "          each block that you mine will consume between 0.002 and 0.01 ETH in transaction fees"
  msgerr cyan    "          from the address linked to the private key you enter.\n"

  msgerr cyan    "          An Ethereum private key looks like this: ${BOLD}f3416f83f4b34379b6bcb50187f3f96171626540983958f01187f76f9c63a49c"

  sleep 3

  msgerr bold magenta "Let's get started on your .env file :)\n\n"

  read -p "${BOLD}${YELLOW}Please enter the PUBLIC Ethereum ADDRESS you'd like to be paid into${RESET}${NL}${NL} > " eth_pub
  echo
  echo
  read -p "${BOLD}${YELLOW}Please enter the PRIVATE KEY for a funded Ethereum address you want to use to pay for mining${RESET}${NL}${NL} > " eth_priv

  msgerr bold green "\n\n [+++] Thank you. You're ready to go!\n"
  msgerr green " --> Copying example.env file into .env ..."
  cp "${DIR}/example.env" "${DIR}/.env"

  msgerr green " --> Inserting your ETH address into the .env file: ${eth_pub} ..."
  sed -Ei "s/ADDRESS=0x2e8687E5349f38e833F9111b25761B903902AdC0/ADDRESS=${eth_pub}/" "${DIR}/.env"
  msgerr
  msgerr green " --> Inserting your ETH private key into the .env file: ${eth_priv} ..."
  sed -Ei "s/PRIVATE_KEY=000000000000000000000000000000000000000000000000000000000/PRIVATE_KEY=${eth_priv}/" "${DIR}/.env"
  msgerr
  msgerr bold green " [+++] All done.\n"
fi

msgerr yellow "\n ========================================================================= \n"
source "${DIR}/.env"

: ${MAX_CORES="$(nproc)"}

if grep -q "koinos" <<< "$(dkr ps)"; then
  msgerr bold yellow " [!!!] Error: It looks like your Koinos miner is already running."
  dkr ps
  msgerr yellow "\n [!!!] To restart your miner, first stop it using the command 'docker stop koinos'"
  msgerr yellow " [!!!] Then re-run this script to start the miner back up.\n"
  exit 1
fi

msgerr bold green " >>> Starting Koinos miner"

dkr run --cpus "$MAX_CORES" --name koinos --env-file "${DIR}/.env" --rm -itd privex/koinos-miner

msgerr bold green " [+++] Successfully started container 'koinos' :)"
msgerr bold green " [+++] If you want to monitor the logs, run the command: ${RESET}docker logs --tail=100 -f koinos\n"


