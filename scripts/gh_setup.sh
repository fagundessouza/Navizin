#!/usr/bin/env bash
# Cria as labels padrão do Navizin no repositório do GitHub atual.
#
# Pré-requisitos: GitHub CLI (`gh`) instalado e autenticado (`gh auth login`).
# Uso:  scripts/gh_setup.sh            (aplica as labels)
#       scripts/gh_setup.sh --dry-run  (só mostra o que faria)
#
# Não cria issues nem altera o projeto: isso é feito manualmente ou em outra etapa,
# depois de revisar a lista.

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if ! $DRY_RUN && ! command -v gh >/dev/null 2>&1; then
  echo "Erro: GitHub CLI (gh) não encontrado. Instale e rode 'gh auth login'." >&2
  exit 1
fi

# nome | cor (hex sem #) | descrição
LABELS=(
  "epic|5319e7|Grande módulo que agrupa várias funcionalidades"
  "feature|0e8a16|Funcionalidade específica"
  "asset|fbca04|Geração e processamento de sprites"
  "infra|1d76db|Podman, banco de dados, observabilidade"
  "bug|d73a4a|Comportamento incorreto"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color description <<< "$entry"
  if $DRY_RUN; then
    echo "[dry-run] label: $name ($color) - $description"
  else
    gh label create "$name" --color "$color" --description "$description" --force
    echo "label aplicada: $name"
  fi
done
