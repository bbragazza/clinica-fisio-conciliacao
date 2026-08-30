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

**🔲 Falta:** ver checklist na seção 3.

## Como executar este checklist

**Não** dá pra simplesmente colar este arquivo inteiro no Claude Code do terminal da Hostinger e pedir pra ele fazer tudo — a maior parte dos itens é específica do filesystem do container (código instalado, login interativo, segredos) e fica mais limpo rodar direto de dentro do code-server, não via `docker exec` remoto. A sequência certa:

1. **No Claude Code do terminal da Hostinger (host):** resolver só os itens **3.1** e **3.9** — são ações via API do Coolify (checar volume, provisionar Postgres), não tocam no filesystem do container nem exigem login interativo.
2. **No terminal do code-server (`code.neria.tech`), manualmente:** só o item **3.2** (instalar e logar o `claude` — uns 2 minutos; o `git clone` do 3.3 não precisa de login, o repo é público).
3. **De volta na mesma sessão do Claude Code, agora rodando dentro do container:** apontar ela pra este arquivo e pedir pra seguir o checklist a partir do **3.3** em diante. A partir daqui ela se constrói sozinha, incluindo pedir pro Bruno completar as partes interativas (`gh auth login`, colar a chave pública do bridge SSH no host).

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
│  │                       │   │ 🔲 chave SSH → root do host  │        │
│  └─────────────────────┘   └──────────┬───────────────────┘        │
│                                        │ ssh (chave dedicada)        │
│                                        ▼                             │
│                              acessa/gerencia os containers            │
│                              irmãos como se estivesse no host         │
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

### 3.8 Bridge SSH: code-server → host (pra gerenciar containers "como se estivesse no host")

É a mesma dor que já resolvemos neste workspace aqui — a mecânica é simples: uma **chave SSH dedicada**, gerada dentro do container, com a chave pública autorizada no `root` do host. Nada de montar o socket do Docker dentro do container (isso equivaleria a dar root do host pra qualquer processo do code-server, superfície de ataque bem maior). Como o Bruno tem só **uma VPS** (diferente daqui, que tem duas com um hop via Tailscale no meio), o setup dele é mais direto: a chave aponta pro próprio host onde o code-server roda.

**Dentro do container (code-server):**
```bash
ssh-keygen -t ed25519 -C "code-server@neria" -f ~/.ssh/id_ed25519_host -N ""
cat ~/.ssh/id_ed25519_host.pub   # copiar a saída
```

**No terminal da Hostinger (host):**
```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "<colar a chave pública copiada acima>" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

**De volta no code-server, testar:**
```bash
ssh -i ~/.ssh/id_ed25519_host root@neria.tech "docker ps"
```
(ou usar o IP público da VPS em vez do domínio — funciona igual). Se quiser evitar digitar `-i` toda hora, adicionar um `Host` alias em `~/.ssh/config`:
```
Host host-vps
  HostName neria.tech
  User root
  IdentityFile ~/.ssh/id_ed25519_host
```
Depois é só `ssh host-vps "docker ps"`.

⚠️ **Trade-off consciente:** essa chave dá acesso root **completo** ao host a partir de dentro de um container exposto na internet (code-server). Se o code-server for comprometido, o host vai junto. Vale considerar, quando sobrar tempo: restringir a chave no `authorized_keys` com `command="..."` forçado (limitando a comandos tipo `docker ps`/`docker exec` em vez de shell livre) — não bloqueante pra começar, mas registrar como hardening futuro (ver seção 5).

### 3.9 Banco de dados

Provisionar um **PostgreSQL** via Coolify (`New Resource → Database → PostgreSQL`), no mesmo Project/Environment do code-server para compartilhar a rede Docker interna. Isso só entrega um banco vazio com uma `DATABASE_URL` — a modelagem de dados e o ORM continuam sendo decisão do Bruno junto com o Claude Code local, na sessão de brainstorming técnico (assumindo Postgres por ser o padrão de todos os outros projetos deste workspace; se preferirem outro banco, é só trocar aqui). Guardar a `DATABASE_URL` também em `~/.secrets/` (mesmo padrão do passo 3.4).

## 4. Primeira interação sugerida

Dentro de `~/workspace/clinica-fisio-conciliacao`, com o Claude Code aberto:

> "Lê o brief em `docs/superpowers/specs/2026-08-29-conciliacao-comissionamento-design.md` e vamos começar o brainstorming técnico da v1 a partir dele."

## 4.1 Planilhas reais da clínica (modalidades de pagamento, conciliação, etc.) — NUNCA neste repositório

O repositório `clinica-fisio-conciliacao` é **público** e é pra ficar só com spec e documentação de setup — sem dado de paciente/pagamento. As planilhas reais que a Berta e as secretárias administram devem ficar direto na VPS, **fora da pasta clonada do repo**:

```bash
mkdir -p ~/workspace/dados-clinica-fisio
```

Sugestão de organização por tipo (ajustar conforme forem chegando):
```
~/workspace/dados-clinica-fisio/
├── modalidades-pagamento/
├── conciliacao/
└── (outras conforme aparecerem)
```

Pra subir os arquivos: arrastar e soltar direto no explorador de arquivos do code-server (navegador), sem precisar de `scp` nem nada externo.

**Defesa extra, mesmo assim:** adicionar ao `.gitignore` do repo clonado uma trava contra erro humano (alguém colar um arquivo dentro da pasta do projeto por hábito):
```bash
echo -e "\n# nunca versionar dado real de paciente/pagamento\ndados-clinica-fisio/\n*.xlsx\n*.xls\n*.csv" >> ~/workspace/clinica-fisio-conciliacao/.gitignore
```

Quando for desenhar o modelo de dados com o Claude Code, é só apontar pra essa pasta como referência (ex: "olha os exemplos em `~/workspace/dados-clinica-fisio/` pra desenhar o schema de modalidades de pagamento").

## 5. Pendente pra depois — segurança da VPS e backups diários

**Não bloqueia o início do desenvolvimento**, mas não pode ficar esquecido — revisitar antes de a VPS guardar dado real de paciente/pagamento (ou seja, ainda durante a v1, não depois). Itens a cobrir quando chegar a hora:

**Segurança:**
- SSH key-only no host: desabilitar `PasswordAuthentication` e configurar `PermitRootLogin prohibit-password` (ou melhor, criar um usuário próprio com sudo pra login humano e deixar root só pra automação, ex. o bridge da seção 3.8)
- Firewall (`ufw`) no host — **atenção**: o Docker fura regras do `ufw` por padrão, então portas publicadas por container ficam expostas mesmo com o firewall "ativo". Precisa do `ufw-docker` (ou equivalente) pra fechar isso de verdade
- `fail2ban` (ou similar) contra brute-force de SSH
- Atualizações automáticas de segurança do Ubuntu (`unattended-upgrades`)
- Restringir/considerar `command=` forçado na chave do bridge SSH da seção 3.8 (hardening do acesso root completo)
- 2FA nas contas que controlam a infra: Hostinger, Cloudflare, GitHub (nível de conta, fora da VPS em si)
- Revisão periódica dos tokens de API gerados (Coolify, Cloudflare) — rotacionar se algum vazar ou ficar tempo demais sem revisão

**Backups diários:**
- Banco de dados (Postgres) — `pg_dump` automatizado diário, ou usar o backup nativo do Coolify se o plano/versão oferecer
- **Backup off-site obrigatório** — não deixar o backup só na mesma VPS; se a VPS cair ou for comprometida, perde o dado e o backup junto
- Código-fonte já está coberto pelo GitHub (não precisa de backup adicional)
- Secrets (`~/.secrets/`, chaves SSH) — considerar um backup criptografado separado, já que não vivem no Git
- Monitorar espaço em disco (backup falho por disco cheio é um clássico)
