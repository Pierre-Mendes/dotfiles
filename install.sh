#!/usr/bin/env bash
# ============================================================
#  install.sh — instala a config de zsh do time
#  Funciona em macOS (Intel / Apple Silicon) e Debian/Ubuntu.
#  Pode ser rodado várias vezes sem quebrar nada (idempotente).
#
#  Uso:
#      ./install.sh
# ============================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------
# 1. Detectar sistema
# ------------------------------------------------------------
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      die "Sistema não suportado: $(uname -s)" ;;
esac
say "Sistema detectado: $OS"

# ------------------------------------------------------------
# 2. Dependências
# ------------------------------------------------------------
install_macos_deps() {
  if ! command -v brew >/dev/null 2>&1; then
    say "Homebrew não encontrado. Instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  say "Instalando pacotes via Homebrew..."
  # --quiet evita ruído; brew não reinstala o que já existe
  brew install --quiet git zsh fzf bat zoxide go || warn "Algum pacote falhou; siga e revise depois."

  # Opcional: não trava a instalação se falhar
  brew install --quiet golangci-lint 2>/dev/null || \
    warn "golangci-lint não instalado (opcional)."
}

install_linux_deps() {
  command -v apt-get >/dev/null 2>&1 || {
    warn "Gerenciador de pacotes não é apt. Instale manualmente: zsh git curl fzf bat zoxide go"
    return 0
  }

  say "Instalando pacotes via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq zsh git curl fzf bat command-not-found || \
    warn "Algum pacote falhou; siga e revise depois."

  # zoxide não existe em todos os repositórios
  if ! command -v zoxide >/dev/null 2>&1; then
    if ! sudo apt-get install -y -qq zoxide 2>/dev/null; then
      warn "zoxide não está no apt desta distro."
      warn "Instale com: curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
    fi
  fi

  if ! command -v go >/dev/null 2>&1; then
    warn "Go não encontrado. O apt costuma ter uma versão antiga."
    warn "Recomendado: baixe de https://go.dev/dl/ e extraia em /usr/local/go"
    warn "  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go<versao>.linux-amd64.tar.gz"
  fi

}

if [[ "$OS" == "macos" ]]; then
  install_macos_deps
else
  install_linux_deps
fi

command -v git >/dev/null 2>&1 || die "git é obrigatório e não foi instalado."

# ------------------------------------------------------------
# 3. Oh My Zsh
# ------------------------------------------------------------
if [[ -d "$ZSH_DIR" ]]; then
  say "Oh My Zsh já instalado."
else
  say "Instalando Oh My Zsh..."
  # RUNZSH=no impede que o instalador abra um zsh e interrompa o script
  # KEEP_ZSHRC=yes impede que ele sobrescreva o .zshrc
  RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# ------------------------------------------------------------
# 4. Plugins externos e tema
# ------------------------------------------------------------
clone_or_update() {
  local repo="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    say "Atualizando $(basename "$dest")..."
    git -C "$dest" pull --quiet --ff-only || warn "Falha ao atualizar $dest"
  else
    say "Clonando $(basename "$dest")..."
    git clone --depth=1 --quiet "$repo" "$dest"
  fi
}

mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

clone_or_update https://github.com/zsh-users/zsh-autosuggestions \
                "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting \
                "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_update https://github.com/zsh-users/zsh-history-substring-search \
                "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

clone_or_update https://github.com/spaceship-prompt/spaceship-prompt \
                "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -sfn "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" \
        "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# ------------------------------------------------------------
# 5. Symlink do .zshrc (com backup)
# ------------------------------------------------------------
link_file() {
  local src="$1" dest="$2"

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    say "$(basename "$dest") já aponta para o repositório."
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    say "Backup de $(basename "$dest") em $BACKUP_DIR/"
    mv "$dest" "$BACKUP_DIR/"
  fi

  ln -s "$src" "$dest"
  say "Link criado: $dest -> $src"
}

link_file "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"

# ------------------------------------------------------------
# 6. Arquivo local de segredos
# ------------------------------------------------------------
if [[ -f "$HOME/.zshrc.local" ]]; then
  say "~/.zshrc.local já existe — mantido como está."
else
  cp "$DOTFILES_DIR/zshrc.local.example" "$HOME/.zshrc.local"
  chmod 600 "$HOME/.zshrc.local"
  say "Criado ~/.zshrc.local a partir do exemplo (chmod 600)."
  warn "Edite ~/.zshrc.local para suas variáveis pessoais."
fi

# ------------------------------------------------------------
# 7. Shell padrão
# ------------------------------------------------------------
ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" && "${SHELL:-}" != "$ZSH_PATH" ]]; then
  warn "Seu shell padrão é ${SHELL:-desconhecido}."
  warn "Para trocar para zsh:  chsh -s $ZSH_PATH"
  if [[ "$OS" == "macos" ]] && ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    warn "Antes disso:  echo $ZSH_PATH | sudo tee -a /etc/shells"
  fi
fi

echo
say "Pronto. Abra um terminal novo ou rode: exec zsh"
say "Fonte recomendada para os ícones do prompt: uma Nerd Font (ex.: MesloLGS NF)."
say "Veja os atalhos disponíveis com: zhelp"
