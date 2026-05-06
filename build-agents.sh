#!/usr/bin/env bash
# Installs skills and agents to the user's home directory for each detected provider.
# Usage: ./build-agents.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
SKILLS_DIR="$SCRIPT_DIR/skills"
CONFIG="$SCRIPT_DIR/providers/configurations.json"

expand_path() {
  echo "${1/#\~/$HOME}"
}

yaml_from_json() {
  local provider="$1"
  local agent="$2"
  local filter
  filter=$(cat <<'EOF'
.[$ENV.PROVIDER].agents[$ENV.AGENT] | to_entries[] |
if (.value | type) == "object" then
  if (.value | length) > 0 then
    (.key + ":"),
    (.value | to_entries[] | "  " + .key + ": " + .value)
  else empty end
else
  .key + ": " + (.value | @json | ltrimstr("\"") | rtrimstr("\""))
end
EOF
)
  PROVIDER="$provider" AGENT="$agent" jq -r "$filter" "$CONFIG"
}

# Detect installed providers
detected=()
all_providers=$(jq -r 'keys[]' "$CONFIG")

for provider in $all_providers; do
  detect_path=$(expand_path "$(jq -r ".[$provider].detect" "$CONFIG")")  # use quotes
  detect_path=$(expand_path "$(jq -r ".[\"$provider\"].detect" "$CONFIG")")
  if [ -d "$detect_path" ]; then
    detected+=("$provider")
  fi
done

if [ ${#detected[@]} -eq 0 ]; then
  echo "No supported providers detected. Exiting."
  exit 0
fi

# Let user select providers
echo "Detected providers:"
for i in "${!detected[@]}"; do
  echo "  [$((i+1))] ${detected[$i]}"
done
echo "  [a] All"
echo ""
read -rp "Install to which providers? (e.g. 1 2 or a): " selection

selected=()
if [ "$selection" = "a" ]; then
  selected=("${detected[@]}")
else
  for s in $selection; do
    idx=$((s-1))
    if [ -n "${detected[$idx]:-}" ]; then
      selected+=("${detected[$idx]}")
    fi
  done
fi

if [ ${#selected[@]} -eq 0 ]; then
  echo "No valid selection. Exiting."
  exit 1
fi

# Ask about pillbox skill
echo ""
echo "¿Instalar la skill 'pillbox'? (recomendado — memoria persistente por proyecto para agentes IA)"
read -rp "  [S/n]: " install_pillbox
install_pillbox=$(echo "${install_pillbox:-s}" | tr '[:upper:]' '[:lower:]')

# Ask about sdd skill and agents
echo ""
echo "¿Instalar la skill 'sdd' y sus agentes? (recomendado si no tienes tus propios flujos de desarrollo guiado por specs)"
read -rp "  [S/n]: " install_sdd
install_sdd=$(echo "${install_sdd:-s}" | tr '[:upper:]' '[:lower:]')

# Build skill and agent filters
install_skills=()
install_agents=()

if [ "$install_pillbox" != "n" ]; then
  install_skills+=("pillbox")
fi

if [ "$install_sdd" != "n" ]; then
  install_skills+=("sdd")
  install_agents+=("sdd")
fi

if [ ${#install_skills[@]} -eq 0 ] && [ ${#install_agents[@]} -eq 0 ]; then
  echo ""
  echo "No se seleccionó ninguna skill ni agente. Saliendo."
  exit 0
fi

# Install
for provider in "${selected[@]}"; do
  agents_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.agents" "$CONFIG")")
  skills_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.skills" "$CONFIG")")

  echo ""
  echo "Installing $provider"

  # Agents
  if [ ${#install_agents[@]} -gt 0 ]; then
    mkdir -p "$agents_path"
    agents=$(jq -r ".[\"$provider\"].agents | keys[]" "$CONFIG")
    for agent in $agents; do
      # Filter: only install agents whose name starts with a selected prefix
      should_install=false
      for prefix in "${install_agents[@]}"; do
        if [[ "$agent" == "$prefix"* ]]; then
          should_install=true
          break
        fi
      done
      if [ "$should_install" = false ]; then continue; fi

      content_file="$AGENTS_DIR/$agent.md"
      if [ ! -f "$content_file" ]; then
        echo "  Warning: agents/$agent.md not found, skipping"
        continue
      fi
      {
        echo "---"
        yaml_from_json "$provider" "$agent"
        echo "---"
        echo ""
        cat "$content_file"
      } > "$agents_path/$agent.md"
      echo "  ✓ agents/$agent.md → $agents_path"
    done
  fi

  # Skills
  if [ ${#install_skills[@]} -gt 0 ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
      skill_name=$(basename "$skill_dir")
      skill_file="$skill_dir/SKILL.md"
      if [ ! -f "$skill_file" ]; then continue; fi

      should_install=false
      for name in "${install_skills[@]}"; do
        if [ "$skill_name" = "$name" ]; then
          should_install=true
          break
        fi
      done
      if [ "$should_install" = false ]; then continue; fi

      mkdir -p "$skills_path/$skill_name"
      cp "$skill_file" "$skills_path/$skill_name/SKILL.md"
      echo "  ✓ skills/$skill_name/SKILL.md → $skills_path/$skill_name"
    done
  fi
done

echo ""
echo "Done."
