# ============================================================
#  alias-tool — aliases que se documentam sozinhos
#
#  Declarar:
#      ali gs 'git status' -g git -d 'Status do repositório'
#      doc gocov -g go -d 'Cobertura de testes'      # para funções
#
#  Usar:
#      zhelp                 lista tudo, agrupado
#      zhelp git             só o grupo git
#      zhelp gs              detalhe de um alias
#      zhelp -s docker       busca em nome, descrição e comando
#      znew                  assistente para criar um alias
#      znew gco 'git checkout' -g git -d 'Troca de branch'
#      zrm gco               remove
#      zedit                 abre o arquivo de aliases pessoais
# ============================================================

typeset -gA _ZA_CMD _ZA_DESC _ZA_GROUP _ZA_SRC

# Onde os aliases pessoais são gravados. Fica fora do repositório.
ZSH_ALIASES_LOCAL="${ZSH_ALIASES_LOCAL:-$HOME/.zsh_aliases.local}"

# ------------------------------------------------------------
# Declaração
# ------------------------------------------------------------

# ali <nome> <comando> [-g grupo] [-d descrição]
ali() {
  emulate -L zsh
  local group="geral" desc=""
  local -a pos

  while (( $# )); do
    case "$1" in
      -g|--group) group="${2:-geral}"; shift 2 ;;
      -d|--desc)  desc="${2:-}";       shift 2 ;;
      --)         shift; pos+=("$@"); break ;;
      *)          pos+=("$1"); shift ;;
    esac
  done

  local name="${pos[1]:-}" cmd="${pos[2]:-}"
  if [[ -z "$name" || -z "$cmd" ]]; then
    print -u2 "ali: uso: ali <nome> <comando> [-g grupo] [-d descrição]"
    return 1
  fi

  alias -- "$name=$cmd"
  _ZA_CMD[$name]="$cmd"
  _ZA_DESC[$name]="$desc"
  _ZA_GROUP[$name]="$group"
  _ZA_SRC[$name]="${_ZA_CURRENT_FILE:-?}"
}

# doc <nome-da-função> [-g grupo] [-d descrição]
# Registra uma função já definida para que ela apareça no zhelp.
doc() {
  emulate -L zsh
  local group="geral" desc=""
  local -a pos

  while (( $# )); do
    case "$1" in
      -g|--group) group="${2:-geral}"; shift 2 ;;
      -d|--desc)  desc="${2:-}";       shift 2 ;;
      *)          pos+=("$1"); shift ;;
    esac
  done

  local name="${pos[1]:-}"
  [[ -n "$name" ]] || { print -u2 "doc: uso: doc <nome> [-g grupo] [-d descrição]"; return 1; }

  _ZA_CMD[$name]="(função)"
  _ZA_DESC[$name]="$desc"
  _ZA_GROUP[$name]="$group"
  _ZA_SRC[$name]="${_ZA_CURRENT_FILE:-?}"
}

# Carrega um arquivo de aliases registrando a origem de cada um.
_za_source() {
  [[ -f "$1" ]] || return 0
  _ZA_CURRENT_FILE="$1"
  source "$1"
  unset _ZA_CURRENT_FILE
}

# ------------------------------------------------------------
# Auxiliares
# ------------------------------------------------------------

# Escapa % para não ser interpretado pelo print -P
_za_esc() { print -r -- "${1//\%/%%}"; }

_za_all_groups() {
  local -a gs
  local k
  for k in "${(@k)_ZA_GROUP}"; do gs+=("${_ZA_GROUP[$k]}"); done
  print -l -- "${(@on)${(@u)gs}}"
}

_za_names_in_group() {
  local g="$1"
  local -a names
  local k
  for k in "${(@k)_ZA_GROUP}"; do
    [[ "${_ZA_GROUP[$k]}" == "$g" ]] && names+=("$k")
  done
  print -l -- "${(@on)names}"
}

_za_print_rows() {
  # Recebe nomes via argumentos, imprime "nome  descrição" alinhado
  local -a names=("$@")
  (( ${#names} )) || return
  local w=0 n
  for n in "${names[@]}"; do (( ${#n} > w )) && w=${#n}; done
  for n in "${names[@]}"; do
    print -P "  %F{cyan}${(r:$w:: :)n}%f  $(_za_esc "${_ZA_DESC[$n]:-}")"
  done
}

# ------------------------------------------------------------
# zhelp
# ------------------------------------------------------------
zhelp() {
  emulate -L zsh

  local term="" mode="list"
  case "${1:-}" in
    "")            mode="list" ;;
    -s|--search)   mode="search"; term="${2:-}" ;;
    -h|--help)     mode="usage" ;;
    *)             mode="auto";   term="$1" ;;
  esac

  if [[ "$mode" == "usage" ]]; then
    print -P "%BComandos%b"
    print "  zhelp               lista todos os atalhos, por grupo"
    print "  zhelp <grupo>       lista só um grupo"
    print "  zhelp <atalho>      detalhe de um atalho"
    print "  zhelp -s <termo>    busca em nome, descrição e comando"
    print "  znew                cria um atalho novo (assistente)"
    print "  zrm <atalho>        remove um atalho"
    print "  zedit               abre o arquivo de atalhos pessoais"
    return 0
  fi

  if (( ${#_ZA_CMD} == 0 )); then
    print -u2 "Nenhum atalho registrado ainda. Crie o primeiro com: znew"
    return 1
  fi

  # --- modo automático: nome exato > grupo > busca -----------
  if [[ "$mode" == "auto" ]]; then
    if [[ -n "${_ZA_CMD[$term]:-}" ]]; then
      mode="detail"
    elif _za_all_groups | grep -qx -- "$term"; then
      mode="group"
    else
      mode="search"
    fi
  fi

  case "$mode" in
    list)
      local g
      for g in ${(f)"$(_za_all_groups)"}; do
        print -P "\n%F{yellow}%B${g}%b%f"
        _za_print_rows ${(f)"$(_za_names_in_group "$g")"}
      done
      print -P "\n%F{244}${#_ZA_CMD} atalhos. Detalhe: zhelp <atalho> · Criar: znew · Ajuda: zhelp -h%f"
      ;;

    group)
      print -P "%F{yellow}%B${term}%b%f"
      _za_print_rows ${(f)"$(_za_names_in_group "$term")"}
      ;;

    detail)
      print -P "%F{cyan}%B${term}%b%f"
      print -P "  grupo       ${_ZA_GROUP[$term]}"
      [[ -n "${_ZA_DESC[$term]}" ]] && \
        print -P "  descrição   $(_za_esc "${_ZA_DESC[$term]}")"
      print -P "  expande     $(_za_esc "${_ZA_CMD[$term]}")"
      print -P "  definido em %F{244}$(_za_esc "${_ZA_SRC[$term]}")%f"
      if [[ "${_ZA_CMD[$term]}" == "(função)" ]]; then
        print -P "\n%F{244}Veja o corpo com: which ${term}%f"
      fi
      ;;

    search)
      if [[ -z "$term" ]]; then
        print -u2 "zhelp: informe o termo. Ex.: zhelp -s docker"
        return 1
      fi
      local -a hits
      local k
      for k in "${(@k)_ZA_CMD}"; do
        if [[ "$k" == *"$term"* ]] \
          || [[ "${_ZA_DESC[$k]:l}" == *"${term:l}"* ]] \
          || [[ "${_ZA_CMD[$k]:l}"  == *"${term:l}"* ]]; then
          hits+=("$k")
        fi
      done
      if (( ${#hits} == 0 )); then
        print -u2 "Nada encontrado para \"$term\". Veja tudo com: zhelp"
        return 1
      fi
      print -P "%F{yellow}%B${#hits} resultado(s) para \"$(_za_esc "$term")\"%b%f"
      _za_print_rows "${(@on)hits}"
      ;;
  esac
}

# ------------------------------------------------------------
# znew — cria um atalho e persiste
# ------------------------------------------------------------
znew() {
  emulate -L zsh

  local group="" desc="" target="$ZSH_ALIASES_LOCAL"
  local -a pos

  while (( $# )); do
    case "$1" in
      -g|--group) group="${2:-}"; shift 2 ;;
      -d|--desc)  desc="${2:-}";  shift 2 ;;
      --repo)     target="${ZSH_ALIASES_REPO:-$target}"; shift ;;
      -h|--help)
        print "uso: znew [<nome> <comando>] [-g grupo] [-d descrição] [--repo]"
        print "  sem argumentos, abre o assistente interativo"
        print "  --repo grava no arquivo versionado em vez do pessoal"
        return 0 ;;
      *) pos+=("$1"); shift ;;
    esac
  done

  local name="${pos[1]:-}" cmd="${pos[2]:-}"

  # --- assistente ------------------------------------------
  if [[ -z "$name" ]]; then
    print -P "%F{yellow}Novo atalho%f  (Ctrl+C cancela)"
    read -r "name?  nome      : "
    [[ -n "$name" ]] || { print -u2 "Cancelado: nome vazio."; return 1; }
    read -r "cmd?  comando   : "
    [[ -n "$cmd" ]] || { print -u2 "Cancelado: comando vazio."; return 1; }
    [[ -n "$group" ]] || read -r "group?  grupo     [geral]: "
    [[ -n "$desc"  ]] || read -r "desc?  descrição : "
  fi

  [[ -n "$cmd" ]] || { print -u2 "znew: falta o comando. Veja: znew -h"; return 1; }
  : "${group:=geral}"

  # --- validações ------------------------------------------
  if [[ "$name" == *[[:space:]]* ]]; then
    print -u2 "znew: o nome não pode conter espaços."
    return 1
  fi

  if [[ -n "${_ZA_CMD[$name]:-}" ]]; then
    print -u2 "znew: \"$name\" já existe e expande para: ${_ZA_CMD[$name]}"
    print -u2 "      Remova antes com: zrm $name"
    return 1
  fi

  # Avisa (sem bloquear) se o comando base não existir
  local base="${${(z)cmd}[1]}"
  if [[ -n "$base" ]] && ! command -v "$base" >/dev/null 2>&1 \
     && ! whence -w "$base" >/dev/null 2>&1; then
    print -P "%F{yellow}aviso:%f \"$base\" não foi encontrado neste sistema."
  fi

  if whence -w "$name" >/dev/null 2>&1; then
    local kind="${${(z)$(whence -w "$name")}[2]}"
    [[ "$kind" == "alias" ]] || \
      print -P "%F{yellow}aviso:%f \"$name\" já existe como $kind e será sombreado."
  fi

  # --- grava -----------------------------------------------
  if [[ ! -f "$target" ]]; then
    print "# Atalhos pessoais. Criados por znew, carregados pelo .zshrc." > "$target"
    print "# Este arquivo não é versionado." >> "$target"
    print "" >> "$target"
  fi

  printf 'ali %s %s -g %s -d %s\n' \
    "${(qq)name}" "${(qq)cmd}" "${(qq)group}" "${(qq)desc}" >> "$target"

  # Ativa na hora, sem precisar de terminal novo
  ali "$name" "$cmd" -g "$group" -d "$desc"
  _ZA_SRC[$name]="$target"

  print -P "%F{green}✓%f %B${name}%b → $(_za_esc "$cmd")"
  print -P "  %F{244}gravado em ${target}%f"
}

# ------------------------------------------------------------
# zrm — remove um atalho do arquivo e da sessão
# ------------------------------------------------------------
zrm() {
  emulate -L zsh
  local name="${1:-}"

  if [[ -z "$name" ]]; then
    print -u2 "zrm: uso: zrm <atalho>"
    return 1
  fi

  if [[ -z "${_ZA_CMD[$name]:-}" ]]; then
    print -u2 "zrm: \"$name\" não está registrado. Veja: zhelp"
    return 1
  fi

  local src="${_ZA_SRC[$name]}"
  if [[ ! -f "$src" ]]; then
    unalias "$name" 2>/dev/null
    unset "_ZA_CMD[$name]" "_ZA_DESC[$name]" "_ZA_GROUP[$name]" "_ZA_SRC[$name]"
    print -P "%F{green}✓%f ${name} removido da sessão (arquivo de origem não encontrado)."
    return 0
  fi

  # Remover um atalho versionado mexe num arquivo do repositório —
  # confirma antes, para não virar uma alteração não intencional no git.
  if [[ "$src" == "${ZSH_ALIASES_REPO:-}" ]]; then
    print -P "%F{yellow}\"$name\" é um atalho versionado%f (${src})."
    if [[ -t 0 ]]; then
      local reply
      read -q "reply?Remover mesmo assim? [s/N] " || true
      print
      [[ "$reply" == [sySY] ]] || { print "Cancelado."; return 1; }
    else
      print "Prosseguindo — lembre de commitar a alteração."
    fi
  fi

  # Filtra as linhas que declaram este atalho. Compara token a token,
  # para funcionar tanto no formato que o znew grava (ali 'gs' '...')
  # quanto no escrito à mão no repositório (ali gs 'git status').
  local -a kept
  local line first second
  local removed=0
  while IFS= read -r line; do
    local -a toks
    toks=( ${(z)line} )
    first="${toks[1]:-}"
    if [[ "$first" == "ali" || "$first" == "doc" ]]; then
      second="${(Q)${toks[2]:-}}"
      if [[ "$second" == "$name" ]]; then
        removed=1
        continue
      fi
    fi
    kept+=("$line")
  done < "$src"

  if (( ! removed )); then
    print -u2 "zrm: \"$name\" está ativo mas não foi encontrado em ${src}."
    print -u2 "     Ele pode ter sido definido à mão. Nada foi alterado no arquivo."
    unalias "$name" 2>/dev/null
    unset "_ZA_CMD[$name]" "_ZA_DESC[$name]" "_ZA_GROUP[$name]" "_ZA_SRC[$name]"
    print -u2 "     Removido apenas desta sessão."
    return 1
  fi

  cp "$src" "${src}.bak"
  print -l -- "${kept[@]}" > "$src"

  unalias "$name" 2>/dev/null
  unset "_ZA_CMD[$name]" "_ZA_DESC[$name]" "_ZA_GROUP[$name]" "_ZA_SRC[$name]"

  print -P "%F{green}✓%f ${name} removido de ${src}"
  print -P "  %F{244}backup em ${src}.bak%f"
}

# ------------------------------------------------------------
# zedit — abre o arquivo pessoal de atalhos
# ------------------------------------------------------------
zedit() {
  emulate -L zsh
  [[ -f "$ZSH_ALIASES_LOCAL" ]] || {
    print "# Atalhos pessoais. Criados por znew, carregados pelo .zshrc." > "$ZSH_ALIASES_LOCAL"
    print "# Este arquivo não é versionado." >> "$ZSH_ALIASES_LOCAL"
    print "" >> "$ZSH_ALIASES_LOCAL"
  }
  "${EDITOR:-vi}" "$ZSH_ALIASES_LOCAL"
  _za_source "$ZSH_ALIASES_LOCAL"
  print -P "%F{green}✓%f recarregado."
}
