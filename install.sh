#!/usr/bin/env bash
# Installs skills, agents and commands to the user's home directory for each detected provider.
# Usage: ./install.sh [--yes|-y]

set -euo pipefail

AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
SKILLS_DIR="$SCRIPT_DIR/skills"
COMMANDS_DIR="$SCRIPT_DIR/commands"
CONFIG="$SCRIPT_DIR/providers/configurations.json"

expand_path() {
  echo "${1/#\~/$HOME}"
}

yaml_from_json() {
  local provider="$1"
  local agent="$2"
  local filter
  # Top-level scalars and arrays are emitted as JSON (valid YAML) so values
  # containing ':' (e.g. descriptions) stay safe and claude-code 'skills' becomes
  # a flow sequence. Nested objects (opencode 'permission') quote keys
  # ('pillbox_*' needs it) and stringify values (allow/deny). jq keeps key order,
  # which matters because the last matching permission rule wins.
  filter=$(cat <<'EOF'
.[$ENV.PROVIDER].agents[$ENV.AGENT] | to_entries[] |
if (.value | type) == "object" then
  if (.value | length) > 0 then
    (.key + ":"),
    (.value | to_entries[] | "  " + (.key | @json) + ": " + (.value | tostring))
  else empty end
else
  .key + ": " + (.value | @json)
end
EOF
)
  PROVIDER="$provider" AGENT="$agent" jq -r "$filter" "$CONFIG"
}

# Detect installed providers
detected=()
all_providers=$(jq -r 'keys[]' "$CONFIG")

for provider in $all_providers; do
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
if [ "$AUTO_YES" = true ]; then
  selection="a"
else
  read -rp "Install to which providers? (e.g. 1 2 or a): " selection
fi

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
echo "Install the 'pillbox' skill? (recommended — persistent per-project memory for AI agents)"
if [ "$AUTO_YES" = true ]; then
  install_pillbox="y"
  echo "  [Y/n]: y (auto)"
else
  read -rp "  [Y/n]: " install_pillbox
  install_pillbox=$(echo "${install_pillbox:-y}" | tr '[:upper:]' '[:lower:]')
fi

# Ask about sdd skill, agents and commands
echo ""
echo "Install the 'sdd' skill, its agents and commands? (recommended)"
echo ""
echo "  SDD (Spec-Driven Development) is Pillbox's official workflow:"
echo "  explore → decision → design → implementation → verification."
echo "  Includes the 'sdd' and 'code-quality' skills and the specialized agents (sdd-explorer, sdd-implementer, etc.)"
echo ""
echo "  Advanced option: if you prefer your own development workflows, answer 'n'."
echo "  Keep in mind that Pillbox is designed and tested on top of SDD, so adapting"
echo "  your own workflows requires knowing its capabilities well — a minimum quality"
echo "  of operation is not guaranteed without that knowledge."
if [ "$AUTO_YES" = true ]; then
  install_sdd="y"
  echo "  [Y/n]: y (auto)"
else
  read -rp "  [Y/n]: " install_sdd
  install_sdd=$(echo "${install_sdd:-y}" | tr '[:upper:]' '[:lower:]')
fi

# Build filters
install_skills=()
install_agents=()
install_commands=()

if [ "$install_pillbox" != "n" ]; then
  install_skills+=("pillbox")
fi

if [ "$install_sdd" != "n" ]; then
  install_skills+=("sdd" "code-quality")
  install_agents+=("sdd")
  install_commands+=("sdd")
fi

if [ ${#install_skills[@]} -eq 0 ] && [ ${#install_agents[@]} -eq 0 ] && [ ${#install_commands[@]} -eq 0 ]; then
  echo ""
  echo "No skill, agent or command selected. Exiting."
  exit 0
fi

# Install
for provider in "${selected[@]}"; do
  agents_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.agents" "$CONFIG")")
  skills_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.skills" "$CONFIG")")
  commands_path=$(expand_path "$(jq -r ".[\"$provider\"].paths.commands" "$CONFIG")")
  # Unexpanded skills path (keeps ~) for substitution into agent and command bodies.
  skills_path_raw=$(jq -r ".[\"$provider\"].paths.skills" "$CONFIG")

  echo ""
  echo "Installing $provider"

  # Agents
  if [ ${#install_agents[@]} -gt 0 ]; then
    mkdir -p "$agents_path"
    # Remove agents from previous versions that no longer exist in the config.
    for legacy in sdd-proposer sdd-specifier sdd-architect sdd-planner sdd-archiver sdd-committer; do
      if [ -f "$agents_path/$legacy.md" ]; then
        rm -f "$agents_path/$legacy.md"
        echo "  ✗ agents/$legacy.md removed (no longer part of SDD)"
      fi
    done
    agents=$(jq -r ".[\"$provider\"].agents | keys[]" "$CONFIG")
    for agent in $agents; do
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
        sed "s|__SKILL_DIR__|$skills_path_raw|g" "$content_file"
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

  # Commands
  if [ ${#install_commands[@]} -gt 0 ]; then
    for cmd_dir in "$COMMANDS_DIR"/*/; do
      cmd_name=$(basename "$cmd_dir")

      should_install=false
      for name in "${install_commands[@]}"; do
        if [ "$cmd_name" = "$name" ]; then
          should_install=true
          break
        fi
      done
      if [ "$should_install" = false ]; then continue; fi

      mkdir -p "$commands_path/$cmd_name"
      # Substitute the per-provider skills path into command bodies so each
      # command points at the right SKILL.md location for its provider.
      for cmd_file in "$cmd_dir"*.md; do
        sed "s|__SKILL_DIR__|$skills_path_raw|g" "$cmd_file" \
          > "$commands_path/$cmd_name/$(basename "$cmd_file")"
      done
      echo "  ✓ commands/$cmd_name/ → $commands_path/$cmd_name"
    done
  fi
done

echo ""
echo "Done."
