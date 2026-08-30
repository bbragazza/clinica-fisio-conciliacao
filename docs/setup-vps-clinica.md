# Setup do ambiente — VPS Hostinger (Ubuntu + Coolify)

## Status em 30/08/2026

**✅ Já feito (terminal da Hostinger / host):**
- VPS Hostinger com Ubuntu 24.04
- Coolify instalado
- Claude Code CLI instalado (assinatura Pro) — mas o uso do dia a dia **não vai ser aqui**, ver seção 1
- Domínio `neria.tech`, DNS gerenciado no Cloudflare
- Subdomínios `coolify.neria.tech` (painel Coolify) e `code.neria.tech` (code-server)
- Code-server subido via Coolify
- API tokens gerados: Coolify e Cloudflare

**🔲 Falta (tudo dentro do terminal do code-server):** ver checklist na seção 3.

---

## 1. Terminologia: terminal do host vs terminal do container

Duas coisas com nomes parecidos, ambientes completamente separados:

| | Terminal da Hostinger (**host** / bare metal) | Terminal do code-server (**container**) |
|---|---|---|
| Como acessa | SSH `root@neria.tech` / painel da Hostinger | Navegador em `code.neria.tech` → terminal integrado do VS Code |
| O que é | Ubuntu 24.04 "puro" da VPS, sem isolamento | Ambiente isolado (Docker) rodando dentro do host, gerenciado pelo Coolify |
| Usuário | root (ou usuário com sudo pleno) | `coder`, com `sudo` sem senha pra tudo — na prática já é root completo pra qualquer comando |
| `docker ps` mostra... | Todos os containers da VPS (Coolify, code-server, banco, Traefik) | Nada — não tem acesso ao Docker do host (isolamento normal, não precisa mexer nisso) |
| Pra que serve | Manutenção de infraestrutura: Docker, Coolify, disco, rede, emergências | **Onde o Bruno trabalha no dia a dia**: `claude`, git, editar código, rodar o app |
| O que foi instalado lá **não existe** aqui | — | Por isso o Claude Code do terminal da Hostinger não aparece dentro do code-server — precisa instalar de novo, dentro do container |

```
┌──────────────────────────────────────────────────────────────┐
│ VPS Hostinger — Ubuntu 24.04  ("host" / bare metal)            │
│ Acesso: SSH root@neria.tech                                    │
│ ✅ Coolify instalado · ✅ Claude Code CLI instalado (uso raro)  │
│                                                                  │
│  Docker Engine roda aqui e gerencia os containers:              │
│  ┌─────────────────────┐   ┌──────────────────────────┐        │
│  │ Container: Coolify    │   │ Container: code-server     │        │
│  │ → coolify.neria.tech  │   │ → code.neria.tech          │        │
│  │                       │   │ user coder (+sudo NOPASSWD)│        │
│  │                       │   │ 🔲 Claude Code CLI          │        │
│  │                       │   │ 🔲 Superpowers               │        │
│  │                       │   │ 🔲 gh CLI + cofre ~/.secrets │        │
│  │                       │   │ 🔲 Node + Playwright         │        │
│  │                       │   │ 🔲 /workspace                │        │
│  └─────────────────────┘   └──────────────────────────┘        │
│  ┌─────────────────────┐                                       │
│  │ Container: Postgres    │  🔲 a provisionar                    │
│  └─────────────────────┘                                       │
│                                                                  │
│  Traefik (parte do Coolify) roteia os subdomínios por HTTPS —   │
│  DNS de neria.tech gerenciado no Cloudflare                     │
└──────────────────────────────────────────────────────────────┘
```

Comando rápido pra saber onde você está, a qualquer momento:
```bash
id; hostname; sudo -n true 2>/dev/null && echo "sudo: SIM" || echo "sudo: NAO"; command -v docker >/dev/null && docker ps >/dev/null 2>&1 && echo "docker: SIM (terminal Hostinger/host)" || echo "docker: NAO (dentro do container code-server)"
```

## 2. Sobre "acesso root" no code-server

A imagem oficial do code-server já roda com o usuário `coder`, que tem `sudo` **sem senha para qualquer comando** (`NOPASSWD:ALL`) — na prática, já é root completo para instalar pacotes, editar qualquer arquivo, etc. O processo web do code-server em si roda sem privilégio elevado, o que é mais seguro e não custa nada no uso do dia a dia. **Recomendação: manter assim**, em vez de forçar o container a rodar literalmente como root — não há ganho real e perde-se uma camada de proteção. Se algo específico exigir root "de verdade" mais adiante, revisitar.

## 3. Checklist do que falta (tudo dentro do terminal do code-server, em `code.neria.tech`)

### 3.1 ⚠️ Conferir o volume persistente ANTES de instalar qualquer coisa

Se o volume do container do code-server no Coolify está mapeado só pra `/home/coder/project` (e não pro `$HOME` inteiro), tudo que for instalado fora dessa pasta — o binário do Claude Code (`~/.local/bin`), a autenticação do `gh` (`~/.config/gh`), o cofre de secrets (`~/.secrets`) — **some no próximo redeploy do container**. No painel do Coolify, no resource do code-server, conferir/ajustar o volume para cobrir `/home/coder` inteiro antes de seguir.

### 3.2 Instalar o Claude Code CLI (agora dentro do container)

```bash
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
claude --version
claude   # segue o link de login (Pro já é suficiente)
```

### 3.3 Estrutura de diretórios em `/workspace`

Sugestão — o mesmo padrão usado neste workspace aqui (um `CLAUDE.md` global + uma pasta por projeto):

```
/home/coder/workspace/
├── CLAUDE.md                      ← contexto global (ver esqueleto abaixo)
└── clinica-fisio-conciliacao/     ← git clone do repo (item 1)
    (futuramente: clinica-fisio-whatsapp/  ← item 2, quando chegar a vez)
```

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/bbragazza/clinica-fisio-conciliacao.git
```

Esqueleto sugerido pro `~/workspace/CLAUDE.md` (contexto que toda sessão de Claude Code ali vai carregar automaticamente — resolve de vez a confusão host×container pro Bruno, porque fica documentado e é lido sozinho no início de cada sessão):

```markdown
# Contexto do workspace — VPS neria.tech

- Ambiente: code-server (container Docker via Coolify), acessível em code.neria.tech
- Terminal da Hostinger (host, SSH root@neria.tech) é só pra manutenção de infra
  (Docker/Coolify/disco) — o trabalho do dia a dia é sempre aqui dentro
- Painel Coolify: coolify.neria.tech
- Secrets em ~/.secrets/ (carregado automaticamente pelo .bashrc)
- Projetos:
  - clinica-fisio-conciliacao — app de conciliação/comissionamento (item 1)
```

### 3.4 Cofre de secrets (Coolify + Cloudflare)

Mesmo padrão de `~/.secrets/` usado neste workspace aqui — dá pra copiar a ideia direto:

```bash
mkdir -p ~/.secrets && chmod 700 ~/.secrets

cat > ~/.secrets/coolify.env << 'EOF'
export COOLIFY_API_TOKEN="<colar aqui>"
export COOLIFY_URL="https://coolify.neria.tech"
EOF

cat > ~/.secrets/cloudflare.env << 'EOF'
export CLOUDFLARE_API_TOKEN="<colar aqui>"
EOF

chmod 600 ~/.secrets/*.env

# carregar automaticamente em todo terminal novo
echo 'set -a; for f in ~/.secrets/*.env; do [ -f "$f" ] && source "$f"; done; set +a' >> ~/.bashrc
source ~/.bashrc
```

(O token do GitHub **não** precisa entrar aqui — o `gh auth login`, no próximo passo, guarda a própria autenticação em `~/.config/gh`, e isso já basta pro `gh`/`git` funcionarem.)

### 3.5 GitHub CLI

```bash
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y
gh auth login
```

Fluxo por código (device flow): mostra um código no terminal, abrir `github.com/login/device` em qualquer navegador e digitar. Necessário pra **push** no repositório — hoje ele é público, então `git clone` (feito no passo 3.3) já funciona sem login nenhum.

### 3.6 Plugin Superpowers

Dentro de `~/workspace/clinica-fisio-conciliacao`, rodar `claude` e, na sessão:

```
/plugin
```
Se "superpowers" já aparecer em `claude-plugins-official`, instalar direto:
```
/plugin install superpowers@claude-plugins-official
```
Senão, registrar a marketplace do autor:
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```
**Não fazer os dois** — bug conhecido de colisão quando o plugin existe em duas marketplaces ao mesmo tempo (dá erro falso de "já instalado"). Verificar com `/help` (deve listar `/brainstorm`).

### 3.7 Node.js + Playwright

Adiantando a dependência de v1.1 (extração automatizada do ZenFisio, seção 4.1 do brief) já que estamos deixando o ambiente pronto — o uso em si continua sendo depois:

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g playwright
npx playwright install --with-deps
```

### 3.8 Banco de dados

Provisionar um **PostgreSQL** via Coolify (`New Resource → Database → PostgreSQL`), no mesmo Project/Environment do code-server para compartilhar a rede Docker interna. Isso só entrega um banco vazio com uma `DATABASE_URL` — a modelagem de dados e o ORM continuam sendo decisão do Bruno junto com o Claude Code local, na sessão de brainstorming técnico (assumindo Postgres por ser o padrão de todos os outros projetos deste workspace; se preferirem outro banco, é só trocar aqui). Guardar a `DATABASE_URL` também em `~/.secrets/` (mesmo padrão do passo 3.4).

## 4. Primeira interação sugerida

Dentro de `~/workspace/clinica-fisio-conciliacao`, com o Claude Code aberto:

> "Lê o brief em `docs/superpowers/specs/2026-08-29-conciliacao-comissionamento-design.md` e vamos começar o brainstorming técnico da v1 a partir dele."
