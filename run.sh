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

install_image() {
    msgerr bold green " >>> Automatically updating / installing docker image 'privex/koinos-miner'"

    dkr pull privex/koinos-miner
}

setup_env() {
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
}

_l() {
  msgerr yellow "\n ========================================================================= \n"
}

: ${ENV_FILE="${DIR}/.env"}

[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}" || true

# Controls the --cpus argument to docker run
# Rather than limiting the actual physical cores it can run on, it limits the container to a certain % on all available CPUs.
# For example, if you have 12 total "cpus" (e.g. 6c/12t), and you set MAX_CORES=6, then the container will use on average up to 50%
# of all 12 "cpus".
: ${MAX_CORES=""}
# Controls the physical CPUs that the container can run on. Note that this uses 0 start index. So 0 = the first core/thread.
# For example, CPU_SET=0,2,3,8-11 would allow the container to use the cores: 1, 3, 4, 9, 10, 11 12
: ${CPU_SET=""}
# Controls the number of "CPU shares" the container gets. Shares control CPU priority relative to other containers,
# e.g. a container with 1000 shares has twice the priority to use the CPU than a container with 500 shares.
: ${CPU_SHARES=""}

: ${DOCKER_NAME="koinos"}
: ${DOCKER_IMAGE="privex/koinos-miner"}
: ${DOCKER_RESTART="always"}
: ${DOCKER_RM=1}

ct_running() {
    grep -q "$DOCKER_NAME" <<< "$(dkr ps)"
}
ct_exists() {
    grep -q "$DOCKER_NAME" <<< "$(dkr ps -a)"
}

ct_stop() {
  if ct_running; then
    msgerr red " [...] Stopping container: $DOCKER_NAME"
    docker stop "$DOCKER_NAME"
    msgerr green "\n [+++] Stopped container: $DOCKER_NAME \n"
  fi
  if ct_exists; then
    msgerr red " [...] Removing container: $DOCKER_NAME"
    docker rm "$DOCKER_NAME"
    msgerr green "\n [+++] Removed container: $DOCKER_NAME \n"
  fi
}

ct_start() {
    if ct_running; then
      msgerr bold yellow " [!!!] Error: It looks like your Koinos miner is already running."
      dkr ps
      msgerr yellow "\n [!!!] To restart your miner, first stop it using the command 'docker stop ${DOCKER_NAME}'"
      msgerr yellow " [!!!] Then re-run this script to start the miner back up.\n"
      exit 1
    fi
    DK_ARGS=()

    if [[ -n "$MAX_CORES" ]]; then DK_ARGS+=("--cpus" "$MAX_CORES"); fi
    if [[ -n "$CPU_SET" ]]; then DK_ARGS+=("--cpuset-cpus" "$CPU_SET"); fi
    if [[ -n "$CPU_SHARES" ]]; then DK_ARGS+=("--cpu-shares", "$CPU_SHARES"); fi

    DK_ARGS+=("--name" "$DOCKER_NAME" "--env-file" "${ENV_FILE}" )
    if (( DOCKER_RM )); then 
      DK_ARGS+=("--rm")
    elif [[ -n "$DOCKER_RESTART" ]]; then
      DK_ARGS+=("--restart" "${DOCKER_RESTART}")
    fi

    DK_ARGS+=("-itd" "$DOCKER_IMAGE")

    msgerr bold green " >>> Starting Koinos miner"
    msgerr cyan " --- Docker command args: docker run ${DK_ARGS[*]}"
    sleep 1

    dkr run "${DK_ARGS[@]}"

    # dkr run --cpus "$MAX_CORES" --name koinos --env-file "${DIR}/.env" --rm -itd privex/koinos-miner

    msgerr bold green " [+++] Successfully started container '${DOCKER_NAME}' :)"
    msgerr bold green " [+++] If you want to monitor the logs, run the command: ${RESET}docker logs --tail=100 -f ${DOCKER_NAME}\n"
}

print_help() {
      msgerr green "Privex Koinos Miner - Docker Controller Script"
      msgerr yellow "Part of the open source fork of koinos-miner: https://github.com/Privex/koinos-miner"
      msgerr yellow "(C) 2020 Privex Inc. - https://www.privex.io - BUY A SERVER TODAY!\n"
      _l

      msgerr bold cyan "Commands:\n"
      msgerr cyan "\t - stop/remove/rm/exit/delete - stop and remove the container"
      msgerr cyan "\t - start/START/run/RUN        - start the container"
      msgerr cyan "\t - restart/reset/reboot       - stop the container if it's running and remove it - then start it again"
      msgerr cyan "\t - log/logs/LOG/LOGS          - view and monitor the logs of the container if it's running"
      msgerr cyan "\t - install/update/upgrade     - download the latest code from github and update the docker image"
      msgerr
      _l
}

_l

if [[ ! -f "${DIR}/.env" ]]; then
  setup_env
fi

if (( $# )); then
  case "$1" in
    stop|STOP|remove|REMOVE|rm|RM|exit|EXIT|delete|DELETE)
      ct_stop
      ;;
    start|START|run|RUN)
      ct_start
      ;;
    restart|RESTART|reset|RESET|reboot|REBOOT)
      ct_stop
      ct_start
      ;;
    log*|LOG*)
      if ! ct_running; then
        msgerr red "ERROR: Container $DOCKER_NAME isn't running"
        error_control 2
        exit 1
      fi
      docker logs --tail=100 -f "$DOCKER_NAME"
      ;;
    inst*|INST*|upd*|UPD*|upg*|UPG*)
      git pull
      install_image
      ;;
    help|HELP|'-?'|'-h'|'--help')
      print_help
      ;;
    *)
      msgerr red "Invalid command: $1"
      print_help
      error_control 2
      exit 1
      ;;
  esac
else
  install_image
  ct_start
fi


