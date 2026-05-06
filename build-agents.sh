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

# Install
for provider in "${selected[@]}"; do
  agents_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.agents" "$CONFIG")")
  skills_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.skills" "$CONFIG")")

  echo ""
  echo "Installing $provider"

  # Agents
  mkdir -p "$agents_path"
  agents=$(jq -r ".[\"$provider\"].agents | keys[]" "$CONFIG")
  for agent in $agents; do
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

  # Skills
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"
    if [ ! -f "$skill_file" ]; then continue; fi
    mkdir -p "$skills_path/$skill_name"
    cp "$skill_file" "$skills_path/$skill_name/SKILL.md"
    echo "  ✓ skills/$skill_name/SKILL.md → $skills_path/$skill_name"
  done
done

echo ""
echo "Done."
