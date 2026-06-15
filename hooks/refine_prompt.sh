#!/bin/bash
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // ""')

# Only trigger on >>> prefix
[[ "$prompt" =~ ^'>>' ]] || exit 0

text="${prompt#>>}"
text="${text#"${text%%[![:space:]]*}"}"
[ -z "$text" ] && { echo '{"decision":"block","reason":"Nothing to refine. Provide text after >>."}'; exit 0; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
system=$(cat "$script_dir/refine_prompt.txt")

result=$(CLAUDECODE= claude -p --model haiku <<EOF
$system

Rewrite this:
$text
EOF
) || { echo "{\"decision\":\"block\",\"reason\":\"Refinement error\"}"; exit 0; }

if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$result" | pbcopy
    message="Refined (copied):"$'\n'"$result"
else
    message="Refined:"$'\n'"$result"
fi

jq -n --arg reason "$message" '{decision:"block",reason:$reason}'
