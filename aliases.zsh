# ============================================================
#  Atalhos versionados.
#
#  Formato:  ali <nome> <comando> -g <grupo> -d <descrição>
#  A descrição é o que aparece no `zhelp`, então vale escrever.
#
#  Atalhos pessoais vão em ~/.zsh_aliases.local (via `znew`),
#  que não é versionado.
# ============================================================

# ------------------------------------------------------------
# Arquivos
# ------------------------------------------------------------
# GNU ls usa --color, BSD ls (padrão do macOS) usa -G.
if ls --version >/dev/null 2>&1; then
  ali ll 'ls -lah --color=auto' -g arquivos -d 'Lista tudo, com detalhes e ocultos'
  ali ls 'ls --color=auto'      -g arquivos -d 'ls colorido'
else
  ali ll 'ls -lahG'             -g arquivos -d 'Lista tudo, com detalhes e ocultos'
  export CLICOLOR=1
fi

# ------------------------------------------------------------
# Git
# ------------------------------------------------------------
ali gs  'git status'                      -g git -d 'Status do repositório'
ali gd  'git diff'                        -g git -d 'Diff do que ainda não foi staged'
ali gds 'git diff --staged'               -g git -d 'Diff do que já está staged'
ali gl  'git log --oneline --graph -20'   -g git -d 'Últimos 20 commits em grafo'
ali gco 'git checkout'                    -g git -d 'Troca de branch ou restaura arquivo'
ali gcb 'git checkout -b'                 -g git -d 'Cria e já entra numa branch nova'

# ------------------------------------------------------------
# Docker
# ------------------------------------------------------------
ali dps  'docker ps'                      -g docker -d 'Containers rodando'
ali dpsa 'docker ps -a'                   -g docker -d 'Todos os containers, inclusive parados'
ali dc   'docker compose'                 -g docker -d 'Prefixo do docker compose'
ali dcu  'docker compose up -d'           -g docker -d 'Sobe os serviços em background'
ali dcd  'docker compose down'            -g docker -d 'Derruba os serviços'
ali dcl  'docker compose logs -f --tail=100' -g docker -d 'Acompanha os logs dos serviços'

# ------------------------------------------------------------
# Go — só registra se o Go estiver instalado
# ------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
  ali gob       'go build ./...' -g go -d 'Compila todos os pacotes'
  ali gor       'go run .'       -g go -d 'Roda o pacote do diretório atual'
  ali got       'go test ./...'  -g go -d 'Roda todos os testes'
  ali gotv      'go test -v ./...' -g go -d 'Testes com saída detalhada'
  ali gomt      'go mod tidy'    -g go -d 'Limpa e organiza as dependências'
  ali gofmtall  'go fmt ./...'   -g go -d 'Formata todos os pacotes'
  ali gol       'golangci-lint run' -g go -d 'Roda o linter'

  doc gocov     -g go -d 'Cobertura de testes, resumo por função (-html abre o relatório)'
  doc gocov-min -g go -d 'Falha se a cobertura total ficar abaixo do mínimo. Ex.: gocov-min 80'
fi

# ------------------------------------------------------------
# Shell
# ------------------------------------------------------------
ali zreload 'exec zsh' -g shell -d 'Recarrega o shell do zero'

doc zhelp -g shell -d 'Lista, busca e detalha os atalhos disponíveis'
doc znew  -g shell -d 'Cria um atalho novo e já deixa ativo'
doc zrm   -g shell -d 'Remove um atalho'
doc zedit -g shell -d 'Abre o arquivo de atalhos pessoais no editor'
