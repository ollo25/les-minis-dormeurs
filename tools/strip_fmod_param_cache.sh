#!/usr/bin/env bash
# strip_fmod_param_cache.sh — remède au crash du plugin FMOD 6.1.0 après une reconstruction de banque.
#
# Le plugin met en cache dans chaque scène un identifiant numérique de paramètre (fmod_parameters/<Nom>/id = …)
# qui change à chaque build de banque FMOD. Avec un identifiant périmé, l'éditeur Godot plante (signal 11)
# à la sauvegarde, au clic sur un FmodEventEmitter, ou à l'ouverture de la scène. Ce script supprime ces lignes
# de cache dans tous les .tscn du projet ; le plugin les régénère au prochain clic sur l'émetteur.
#
# Usage, GODOT FERMÉ, depuis le dossier du projet (ou avec le chemin du projet en argument) :
#   tools/strip_fmod_param_cache.sh            # Mac / Linux
#   tools/strip_fmod_param_cache.sh --dry-run  # montre ce qui serait supprimé, sans rien modifier
# À relancer après chaque build de banque (FMOD Studio) ou après un git pull qui amène une nouvelle Master.bank.
# Détail : docs/FMOD-PIEGES.md § 2b.
set -euo pipefail
DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
PROJECT_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$PROJECT_ROOT"
[ -f project.godot ] || { echo "Pas de project.godot dans $PROJECT_ROOT" >&2; exit 1; }

PATTERN='^fmod_parameters/[A-Za-z_][A-Za-z0-9_ ]*(/(id|labels|variant_type))? *= '
n=0
while IFS= read -r -d '' f; do
  c=$(grep -cE "$PATTERN" "$f" || true)
  [ "$c" -eq 0 ] && continue
  n=$((n+c))
  if [ "$DRY" -eq 1 ]; then
    echo "$f : $c ligne(s) de cache"; grep -nE "$PATTERN" "$f" | sed 's/^/    /'
  else
    tmp="$f.strip.tmp"; grep -vE "$PATTERN" "$f" > "$tmp" && mv "$tmp" "$f"; echo "$f : $c ligne(s) supprimée(s)"
  fi
done < <(find . -name "*.tscn" -not -path "./.godot/*" -not -path "./addons/*" -print0)
if [ "$DRY" -eq 1 ]; then echo "Total : $n ligne(s) seraient supprimées (rien modifié)."; else echo "Total : $n ligne(s) supprimées. Tu peux rouvrir Godot ; clique sur chaque FmodEventEmitter pour régénérer le cache, puis sauvegarde."; fi
