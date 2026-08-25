#!/usr/bin/env bash

# shellcheck shell=bash

vpb_ai_status() {
    printf 'AI integrations are opt-in. VPS Buddy never sends workspace data automatically.\n\n'
    printf '%-18s %s\n' PROVIDER STATUS
    printf '%-18s %s\n' OpenAI "$([[ -n "${OPENAI_API_KEY:-}" ]] && printf configured || printf not-configured)"
    printf '%-18s %s\n' Anthropic "$([[ -n "${ANTHROPIC_API_KEY:-}" ]] && printf configured || printf not-configured)"
    printf '%-18s %s\n' Gemini "$([[ -n "${GEMINI_API_KEY:-}" ]] && printf configured || printf not-configured)"
    printf '%-18s %s\n' Ollama "$([[ -x "$(command -v ollama 2>/dev/null || true)" ]] && printf available || printf not-installed)"
}

vpb_ai_redact() {
    local input=$1 output=${2:-} input_path output_path temp
    [[ -f "$input" ]] || die "Input file not found: $input"
    local expression='s/(Authorization:).*/\1 [REDACTED]/Ig; s/((api[_-]?key|token|secret|password)[" ]*[:=][" ]*)[^ ,"]+/\1[REDACTED]/Ig; s/(Cookie:).*/\1 [REDACTED]/Ig'
    if [[ -n "$output" ]]; then
        input_path=$(readlink -f "$input")
        output_path=$(readlink -m "$output")
        [[ "$input_path" != "$output_path" ]] || die "Refusing to overwrite the input file; choose a different output path."
        [[ -d "$(dirname "$output_path")" ]] || die "Output directory does not exist: $(dirname "$output_path")"
        temp=$(mktemp "$(dirname "$output_path")/.vpsbuddy-redacted.XXXXXX")
        if ! sed -E "$expression" "$input_path" >"$temp"; then
            rm -f "$temp"
            return 1
        fi
        chmod 600 "$temp"
        mv "$temp" "$output_path"
        success "Wrote redacted copy to $output"
    else
        sed -E "$expression" "$input"
    fi
}

vpb_ai_brief() {
    local workspace=$1 root
    root="$VPB_WORKSPACES_DIR/$workspace"
    [[ -d "$root" ]] || die "Workspace not found: $workspace"
    printf '# Analysis brief: %s\n\n' "$workspace"
    printf 'Use only the authorized scope and the supplied redacted evidence. Do not invent requests, responses, impact, or reproduction steps. Separate observations from hypotheses. Flag any secret-like material instead of repeating it.\n\n'
    printf '## Workspace inventory\n\n'
    while IFS= read -r path; do
        printf -- '- %s\n' "${path#"$root"/}"
    done < <(find "$root" -type f -print | sort)
    printf '\n## Requested output\n\n1. Asset and endpoint clusters\n2. High-signal anomalies\n3. Missing evidence\n4. Safe manual validation steps\n5. Draft finding outline only where evidence supports it\n'
}
