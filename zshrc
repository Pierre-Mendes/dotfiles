# ============================================================
#  ~/.zshrc — Oh My Zsh + Spaceship
#  Roda em macOS, Linux e WSL2. As diferenças entre sistemas são
#  detectadas em tempo de execução, não há arquivo por plataforma.
#
#  Configuração pessoal (tokens, hosts, variáveis de projeto) vai
#  em ~/.zshrc.local. Atalhos pessoais, em ~/.zsh_aliases.local.
#  Nenhum dos dois é versionado.
# ============================================================

# ------------------------------------------------------------
# Homebrew (macOS) — precisa vir antes de tudo que usa PATH
# ------------------------------------------------------------
if [[ "$OSTYPE" == darwin* ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"      # Intel
  fi
fi

# Diretório deste repositório, resolvendo o symlink de ~/.zshrc
ZDOTREPO="${${(%):-%N}:A:h}"

# ------------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

ZSH_THEME="spaceship"

zstyle ':omz:update' mode reminder
zstyle ':omz:update' frequency 14

# --- Plugins -------------------------------------------------
# Ordem importa: zsh-syntax-highlighting perto do fim e
# zsh-history-substring-search logo depois dele.
plugins=(
  git
  docker
  docker-compose
  sudo
  colored-man-pages
  extract
  laravel
  composer
  npm
  nvm
  golang
  git-auto-fetch
  dotenv
  web-search
  zoxide
  gitignore
  jsontools
  copyfile
  copypath
)

if [[ "$OSTYPE" == darwin* ]]; then
  plugins+=(macos brew)
else
  plugins+=(command-not-found)   # só existe com o pacote do Debian/Ubuntu
fi

plugins+=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source "$ZSH/oh-my-zsh.sh"

# ------------------------------------------------------------
# Histórico
# ------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY        # grava timestamp de cada comando
setopt HIST_EXPIRE_DUPS_FIRST  # remove duplicados antigos primeiro
setopt HIST_IGNORE_DUPS        # não grava comando repetido em sequência
setopt HIST_IGNORE_ALL_DUPS    # remove ocorrências antigas de um repetido
setopt HIST_IGNORE_SPACE       # comando iniciado com espaço não entra no histórico
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY           # compartilha histórico entre abas/sessões
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# ------------------------------------------------------------
# Teclas
# ------------------------------------------------------------
# Busca no histórico pelo que já foi digitado, com ↑ ↓.
# Os dois conjuntos cobrem terminal em modo normal e em application
# mode (Terminal.app e iTerm2 mandam ^[OA / ^[OB em alguns casos).
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[3~' delete-char

# ------------------------------------------------------------
# fzf — Ctrl+R (histórico fuzzy) e Ctrl+T (buscar arquivo)
# ------------------------------------------------------------
# Feito à mão em vez de usar o plugin `fzf` do Oh My Zsh: aquele plugin
# dá `source` sem checar se o arquivo existe e polui o terminal com erro
# em distros cujo pacote não traz os bindings.
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)          # fzf >= 0.48
  else
    _fzf_loaded=0
    for _fzf_dir in \
      /usr/share/doc/fzf/examples \
      /usr/share/fzf \
      /usr/share/fzf/shell \
      /usr/share/zsh/vendor-completions \
      "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell" \
      /usr/local/opt/fzf/shell
    do
      if [[ -f "$_fzf_dir/key-bindings.zsh" ]]; then
        source "$_fzf_dir/key-bindings.zsh"
        _fzf_loaded=1
      fi
      [[ -f "$_fzf_dir/completion.zsh" ]] && source "$_fzf_dir/completion.zsh"
    done

    # Alguns pacotes trazem só o binário. Nesse caso Ctrl+R/Ctrl+T não
    # existem; `fzfhelp` explica como resolver, sem poluir todo prompt.
    if (( ! _fzf_loaded )); then
      fzfhelp() {
        print "fzf $(fzf --version) sem integração de shell instalada."
        print "Atualize para fzf >= 0.48 (que traz 'fzf --zsh'):"
        print "  macOS:  brew install fzf"
        print "  Linux:  git clone --depth 1 https://github.com/junegunn/fzf ~/.fzf && ~/.fzf/install"
      }
    fi
    unset _fzf_dir _fzf_loaded
  fi
fi

# ------------------------------------------------------------
# Go
# ------------------------------------------------------------
# Instalação oficial no Linux fica em /usr/local/go; no macOS o Homebrew
# já põe o binário no PATH via shellenv.
[[ -d /usr/local/go/bin ]] && export PATH="/usr/local/go/bin:$PATH"

if command -v go >/dev/null 2>&1; then
  export GOPATH="${GOPATH:-$(go env GOPATH)}"
  export GOBIN="${GOBIN:-$GOPATH/bin}"
  export PATH="$PATH:$GOBIN"
  export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"

  # Cobertura de testes.
  #   gocov            -> cobertura de ./... e total no terminal
  #   gocov ./pkg/...  -> cobertura só desse pacote
  #   gocov -html      -> abre o relatório navegável no browser
  gocov() {
    local html=0 args=()
    local a
    for a in "$@"; do
      case "$a" in
        -html|--html) html=1 ;;
        *) args+=("$a") ;;
      esac
    done
    (( ${#args} == 0 )) && args=(./...)

    local profile="${TMPDIR:-/tmp}/gocov-${PWD:t}-$$.out"

    go test -covermode=atomic -coverprofile="$profile" "${args[@]}" || return $?

    echo
    go tool cover -func="$profile" | tail -n 20

    if (( html )); then
      local report="${profile%.out}.html"
      go tool cover -html="$profile" -o "$report"
      echo "\nRelatório: $report"
      open_urls "file://$report"
    else
      echo "\nPara o relatório navegável: gocov -html ${args[*]}"
    fi

    rm -f "$profile"
  }

  # Falha se a cobertura total ficar abaixo do mínimo. Útil em pre-commit/CI.
  #   gocov-min 80
  gocov-min() {
    local min="${1:-80}"
    local profile="${TMPDIR:-/tmp}/gocov-min-$$.out"
    go test -covermode=atomic -coverprofile="$profile" ./... >/dev/null || return $?

    local total
    total="$(go tool cover -func="$profile" | awk '/^total:/ {gsub(/%/,"",$3); print $3}')"
    rm -f "$profile"

    echo "Cobertura total: ${total}% (mínimo: ${min}%)"
    awk -v t="$total" -v m="$min" 'BEGIN { exit (t+0 >= m+0) ? 0 : 1 }'
  }
fi

# ------------------------------------------------------------
# cat com syntax highlight (bat)
# No Debian/Ubuntu o binário se chama batcat; no Homebrew, bat.
# ------------------------------------------------------------
if command -v batcat >/dev/null 2>&1; then
  export BAT_CMD="batcat"
elif command -v bat >/dev/null 2>&1; then
  export BAT_CMD="bat"
fi

if [[ -n "$BAT_CMD" ]]; then
  # Tema do bat, combinando com o Dracula do terminal. Para usar outro,
  # defina BAT_THEME no ~/.zshrc.local. Nome de tema desconhecido não
  # quebra nada: o bat avisa no stderr e cai no tema padrão.
  # Veja os disponíveis com: $BAT_CMD --list-themes
  export BAT_THEME="${BAT_THEME:-Dracula}"

  cat() {
    # Em pipe ou redirecionamento, usa o cat real para não quebrar scripts
    if [[ ! -t 1 ]]; then
      command cat "$@"
      return
    fi
    "$BAT_CMD" --paging=never --style=plain "$@" 2>/dev/null || command cat "$@"
  }
fi

# ------------------------------------------------------------
# Abrir URLs no navegador (open no macOS, xdg-open no Linux/WSL)
# ------------------------------------------------------------
open_urls() {
  if [[ "$OSTYPE" == darwin* ]]; then
    open -a "Google Chrome" "$@" 2>/dev/null || open "$@"
  elif command -v wslview >/dev/null 2>&1; then
    local _url
    for _url in "$@"; do wslview "$_url" >/dev/null 2>&1; done
  elif command -v google-chrome >/dev/null 2>&1; then
    google-chrome "$@" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    local _url
    for _url in "$@"; do xdg-open "$_url" >/dev/null 2>&1 & done
  else
    print -u2 "Nenhum navegador encontrado. Abra manualmente: $*"
  fi
}

# ------------------------------------------------------------
# Atalhos — ferramenta e definições
# ------------------------------------------------------------
# lib/alias-tool.zsh dá os comandos zhelp, znew, zrm e zedit.
# aliases.zsh traz os atalhos versionados.
# ~/.zsh_aliases.local traz os seus, criados com `znew`.
[[ -f "$ZDOTREPO/lib/alias-tool.zsh" ]] && source "$ZDOTREPO/lib/alias-tool.zsh"

if (( $+functions[_za_source] )); then
  ZSH_ALIASES_REPO="$ZDOTREPO/aliases.zsh"
  _za_source "$ZSH_ALIASES_REPO"
  _za_source "$ZSH_ALIASES_LOCAL"
fi

# ------------------------------------------------------------
# Spaceship prompt
# ------------------------------------------------------------
SPACESHIP_PROMPT_ORDER=(
  user           # Usuário
  dir            # Diretório atual
  host           # Hostname (só aparece em SSH)
  git            # Branch + status do git
  package        # Versão do package.json
  node           # Node.js
  php            # PHP
  golang         # Go
  docker         # Docker
  docker_compose # Seção customizada abaixo
  exec_time      # Tempo de execução do último comando
  line_sep       # Quebra de linha
  exit_code      # Código de saída se der erro
  char           # Símbolo final ➜
)
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="➜ "
SPACESHIP_CHAR_SUFFIX=" "

# --- Seção customizada: docker compose -----------------------
# Mostra "compose 🐙 <rodando>/<total>" quando há um compose file na árvore.
#
# ATENÇÃO (performance): roda dois comandos `docker compose` a cada
# prompt dentro de um projeto com compose. Em máquina lenta, ou com
# Docker Desktop no macOS/WSL, custa algumas centenas de ms por prompt.
# Para desligar, coloque no ~/.zshrc.local:
#     SPACESHIP_DOCKER_COMPOSE_SHOW=false
SPACESHIP_DOCKER_COMPOSE_SHOW="${SPACESHIP_DOCKER_COMPOSE_SHOW=true}"
SPACESHIP_DOCKER_COMPOSE_PREFIX="${SPACESHIP_DOCKER_COMPOSE_PREFIX="compose "}"
SPACESHIP_DOCKER_COMPOSE_SYMBOL="${SPACESHIP_DOCKER_COMPOSE_SYMBOL="🐙 "}"
SPACESHIP_DOCKER_COMPOSE_COLOR="${SPACESHIP_DOCKER_COMPOSE_COLOR="yellow"}"

spaceship_docker_compose() {
  [[ $SPACESHIP_DOCKER_COMPOSE_SHOW == false ]] && return
  spaceship::exists docker || return

  local compose_file
  compose_file="$(spaceship::upsearch docker-compose.yml docker-compose.yaml compose.yml compose.yaml)"
  [[ -n "$compose_file" ]] || return

  local running total
  running="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')"
  total="$(docker compose config --services 2>/dev/null | wc -l | tr -d ' ')"

  [[ -z "$total" || "$total" == "0" ]] && return

  local color="$SPACESHIP_DOCKER_COMPOSE_COLOR"
  # Fica vermelho se tiver algum serviço parado, pra chamar atenção
  [[ "$running" != "$total" ]] && color="red"

  spaceship::section \
    --color "$color" \
    --prefix "$SPACESHIP_DOCKER_COMPOSE_PREFIX" \
    --symbol "$SPACESHIP_DOCKER_COMPOSE_SYMBOL" \
    "${running}/${total}"
}

# ------------------------------------------------------------
# Credenciais — deixar comentado neste arquivo
# ------------------------------------------------------------
# Este arquivo é versionado. Preencha no ~/.zshrc.local.
#
# export CR_PAT=""              # GitHub PAT (ghcr.io, repos privados)
# export ANTHROPIC_BASE_URL=""
# export ANTHROPIC_API_KEY=""

# ------------------------------------------------------------
# Configuração local — sempre por último
# ------------------------------------------------------------
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
