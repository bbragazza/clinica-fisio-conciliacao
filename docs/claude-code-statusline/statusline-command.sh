#!/bin/bash
# Claude Code statusLine — custom configuration
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')

# Estratégia 1: Ler de .agent.name (se disponível no contexto)
AGENT=$(echo "$input" | jq -r '.agent.name // ""')

# Estratégia 2: Ler agentes rastreados da sessão atual
if [ -z "$AGENT" ] || [ "$AGENT" = "null" ]; then
  SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
  if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ]; then
    AGENTS_FILE="$HOME/.claude/sessions/$SESSION_ID/active-agents.json"
    if [ -f "$AGENTS_FILE" ]; then
      # Lê último agente da lista (mais recente)
      AGENT=$(jq -r '.agents[-1] // ""' "$AGENTS_FILE" 2>/dev/null)
      # Se houver múltiplos, mostra todos separados por " + "
      AGENT_COUNT=$(jq -r '.agents | length' "$AGENTS_FILE" 2>/dev/null)
      if [ "$AGENT_COUNT" -gt 1 ]; then
        AGENT=$(jq -r '.agents | join(" + ")' "$AGENTS_FILE" 2>/dev/null)
      fi
    fi
  fi
fi

# Estratégia 3: Fallback para arquivo legado
if [ -z "$AGENT" ] || [ "$AGENT" = "null" ]; then
  if [ -f "$HOME/.claude/active-agent.txt" ]; then
    AGENT=$(cat "$HOME/.claude/active-agent.txt" 2>/dev/null | tr -d '[:space:]')
  fi
fi

# Estratégia 4: Variável de ambiente (fallback final)
if [ -z "$AGENT" ] || [ "$AGENT" = "null" ]; then
  AGENT="${AIOX_ACTIVE_AGENT:-}"
fi

# ctx% = used_percentage fornecido pelo Claude Code — é exatamente o mesmo valor
# que o Claude Code usa internamente para decidir o autocompact (dispara ao atingir ~95%).
# Fallback: (input_tokens + cache_read) / context_window_size sem output nem cache_creation,
# pois o critério de compactação é baseado no tamanho do contexto de entrada.
PCT=$(echo "$input" | jq -r '
  .context_window.used_percentage //
  (
    (
      (.context_window.current_usage.input_tokens // 0) +
      (.context_window.current_usage.cache_read_input_tokens // 0)
    ) * 100 / (.context_window.context_window_size // 1000000)
  )
' | cut -d. -f1)

COST=$(printf '$%.2f' "$(echo "$input" | jq -r '.cost.total_cost_usd // 0')")
BRANCH=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir // "."')" branch --show-current 2>/dev/null || echo "-")

# Rate limits (5h and 7d windows)
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // ""' | cut -d. -f1)
RATE_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // ""' | cut -d. -f1)
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')

# Build status line: modelo | agent(s) | current_dir | branch | custo | ctx | 5h | 7d
LINE="\e[1;35m${MODEL}\e[0m"

if [ -n "$AGENT" ] && [ "$AGENT" != "null" ] && [ "$AGENT" != "" ]; then
  # Agente ativo: colorir em amarelo/dourado
  LINE="${LINE} | \e[1;33m${AGENT}\e[0m"
else
  # Nenhum agente ativo
  LINE="${LINE} | \e[0;90m-\e[0m"
fi

if [ -n "$CURRENT_DIR" ] && [ "$CURRENT_DIR" != "null" ]; then
  LINE="${LINE} | \e[0;37m${CURRENT_DIR}\e[0m"
fi

LINE="${LINE} | \e[1;32m${BRANCH}\e[0m"
LINE="${LINE} | ${COST}"
# Color code context: green <70%, yellow 70-85%, red >85%
if [ "$PCT" -ge 85 ] 2>/dev/null; then
  CTX_COLOR="1;31"
elif [ "$PCT" -ge 70 ] 2>/dev/null; then
  CTX_COLOR="1;33"
else
  CTX_COLOR="1;36"
fi
LINE="${LINE} | ctx:\e[${CTX_COLOR}m${PCT}%\e[0m\n"

# Rate limit resets (Brazil timezone)
if [ -n "$RATE_5H" ] && [ "$RATE_5H" != "null" ]; then
  RESET_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // ""')
  if [ -n "$RESET_5H" ] && [ "$RESET_5H" != "null" ] && [ "$RESET_5H" != "" ]; then
    RESET_5H_BR=$(TZ="America/Sao_Paulo" date -d "@${RESET_5H}" +"%H:%M" 2>/dev/null || echo "")
    [ -n "$RESET_5H_BR" ] && RESET_5H_LABEL=" (reset ${RESET_5H_BR})" || RESET_5H_LABEL=""
  else
    RESET_5H_LABEL=""
  fi
  LINE="${LINE}5h:\e[1;34m${RATE_5H}%\e[0m\e[0;34m${RESET_5H_LABEL}\e[0m"
fi

if [ -n "$RATE_7D" ] && [ "$RATE_7D" != "null" ]; then
  RESET_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // ""')
  if [ -n "$RESET_7D" ] && [ "$RESET_7D" != "null" ] && [ "$RESET_7D" != "" ]; then
    RESET_7D_BR=$(TZ="America/Sao_Paulo" date -d "@${RESET_7D}" +"%d/%m %H:%M" 2>/dev/null || echo "")
    [ -n "$RESET_7D_BR" ] && RESET_7D_LABEL=" (reset ${RESET_7D_BR})" || RESET_7D_LABEL=""
  else
    RESET_7D_LABEL=""
  fi
  LINE="${LINE} | 7d:\e[1;34m${RATE_7D}%\e[0m\e[0;34m${RESET_7D_LABEL}\e[0m"
fi

# Session duration from cost.total_duration_ms
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | cut -d. -f1)
if [ "$DURATION_MS" -gt 0 ] 2>/dev/null; then
  ELAPSED=$(( DURATION_MS / 1000 ))
  SESS_H=$(( ELAPSED / 3600 ))
  SESS_M=$(( (ELAPSED % 3600) / 60 ))
  SESS_LABEL=$(printf "%02d:%02d" "$SESS_H" "$SESS_M")
  LINE="${LINE} | sessão: \e[0;33m${SESS_LABEL}\e[0m"
fi

echo -e "$LINE"
