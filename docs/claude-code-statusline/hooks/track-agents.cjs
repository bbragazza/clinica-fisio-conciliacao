#!/usr/bin/env node
/**
 * Track Active Agents Hook — UserPromptSubmit
 *
 * Detecta quando um agente é ativado (@agent-name ou /AIOX:agents:name)
 * e rastreia os agentes ativos na sessão atual.
 *
 * Salva em: ~/.claude/sessions/{session_id}/active-agents.json
 */

const path = require('path');
const fs = require('fs');
const os = require('os');

const SESSION_DIR = path.join(os.homedir(), '.claude', 'sessions');
const AGENTS = ['dev', 'qa', 'architect', 'pm', 'po', 'sm', 'analyst', 'data-engineer', 'ux-design-expert', 'devops', 'aiox-master'];

/**
 * Lê JSON do stdin
 */
function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => {
      try { resolve(JSON.parse(data)); }
      catch (_) { resolve({}); }
    });
    process.stdin.on('error', (e) => reject(e));
  });
}

/**
 * Obtém ou cria arquivo de agentes para a sessão
 */
function getAgentsFilePath(sessionId) {
  const sessionDir = path.join(SESSION_DIR, sessionId);
  const agentsFile = path.join(sessionDir, 'active-agents.json');

  // Cria diretório se não existir
  if (!fs.existsSync(sessionDir)) {
    fs.mkdirSync(sessionDir, { recursive: true });
  }

  return agentsFile;
}

/**
 * Lê agentes ativos atuais
 */
function readActiveAgents(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      const data = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(data);
    }
  } catch (_) {}
  return { agents: [], timestamp: Date.now() };
}

/**
 * Detecta agentes mencionados no prompt
 * @agent-name ou /AIOX:agents:name
 */
function detectAgents(prompt) {
  const detected = [];

  // Padrão 1: @agent-name
  const atPattern = /@([\w-]+)/g;
  let match;
  while ((match = atPattern.exec(prompt)) !== null) {
    const agentName = match[1];
    if (AGENTS.includes(agentName)) {
      detected.push(agentName);
    }
  }

  // Padrão 2: /AIOX:agents:name
  const slashPattern = /\/AIOX:agents:([\w-]+)/g;
  while ((match = slashPattern.exec(prompt)) !== null) {
    const agentName = match[1];
    if (AGENTS.includes(agentName) && !detected.includes(agentName)) {
      detected.push(agentName);
    }
  }

  return detected;
}

/**
 * Main: rastreia agentes
 */
async function main() {
  try {
    const input = await readStdin();

    if (!input || !input.session_id) {
      // Sem session ID, não pode rastrear
      return;
    }

    const sessionId = input.session_id;
    const isSubagentStart = process.argv.includes('--subagent');

    let newAgents = [];

    if (isSubagentStart) {
      // Hook SubagentStart — extrai nome do agente do input
      // Formato: { "subagent_id": "devops", "subagent_name": "Gage", ... }
      const agentId = input.subagent_id || input.subagent_name || '';

      // Normaliza nome do agente (remove emojis, pega apenas palavra-chave)
      const match = agentId.match(/[\w-]+/);
      if (match && AGENTS.includes(match[0])) {
        newAgents = [match[0]];
      }

      // Detecta *exit no input se houver
      if (input.command && input.command.includes('*exit')) {
        const agentsFile = getAgentsFilePath(sessionId);
        const current = readActiveAgents(agentsFile);

        // Remove último agente (FIFO)
        if (current.agents.length > 0) {
          current.agents.pop();
          current.timestamp = Date.now();
          current.updated_at = new Date().toISOString();

          fs.writeFileSync(agentsFile, JSON.stringify(current, null, 2));
        }
        return;
      }
    } else {
      // Hook UserPromptSubmit — extrai agentes do prompt
      const prompt = input.prompt || '';
      newAgents = detectAgents(prompt);

      // Detecta *exit (sai de agente)
      if (prompt.includes('*exit')) {
        const agentsFile = getAgentsFilePath(sessionId);
        const current = readActiveAgents(agentsFile);

        // Remove último agente (FIFO)
        if (current.agents.length > 0) {
          current.agents.pop();
          current.timestamp = Date.now();
          current.updated_at = new Date().toISOString();

          fs.writeFileSync(agentsFile, JSON.stringify(current, null, 2));
        }
        return;
      }
    }

    // Se detectou agentes, atualiza arquivo
    if (newAgents.length > 0) {
      const agentsFile = getAgentsFilePath(sessionId);
      const current = readActiveAgents(agentsFile);

      // Adiciona novos agentes (evita duplicatas)
      current.agents = Array.from(new Set([...current.agents, ...newAgents]));
      current.timestamp = Date.now();
      current.updated_at = new Date().toISOString();

      fs.writeFileSync(agentsFile, JSON.stringify(current, null, 2));
    }

  } catch (_) {
    // Silent fail — nunca bloqueia
  }
}

if (require.main === module) {
  main().catch(() => {});
}

module.exports = { main };
