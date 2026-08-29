# Setup do ambiente — VPS Hostinger (Ubuntu + Coolify)

Substitui o plano anterior de rodar local no Windows da clínica. Agora: VPS própria na Hostinger, Ubuntu já instalado, painel **Coolify** já instalado. Falta subir um **code-server** (VS Code no navegador) via Coolify pra o Bruno trabalhar de qualquer lugar, e a partir dali instalar o Claude Code.

## 0. Pré-requisitos já feitos
- [x] VPS Hostinger contratada
- [x] Ubuntu instalado
- [x] Coolify instalado e painel acessível

## 1. Subir o code-server via Coolify

No painel do Coolify:

1. **New Resource → Docker Image** (não precisa de repositório GitHub pra isso, é uma imagem pronta).
2. Imagem: `codercom/code-server:latest`.
3. **Variáveis de ambiente obrigatórias:**
   - `PASSWORD=<uma senha forte>` — sem isso, ou com senha fraca, o code-server fica exposto na internet com acesso de shell completo. Gerar uma senha longa e aleatória (ex: `openssl rand -base64 24` em qualquer terminal) e guardar num cofre de senhas.
   - (Opcional, mais seguro que `PASSWORD`) `HASHED_PASSWORD` com um hash argon2 — ver [docs oficiais do code-server](https://coder.com/docs/code-server/FAQ#can-i-hash-my-password).
4. **Porta:** o code-server escuta na `8080` internamente — configurar isso como a porta exposta pelo Coolify.
5. **Volume persistente:** mapear algo como `/home/coder/project` (ou o `$HOME` inteiro) pra um volume — sem isso, um redeploy do container apaga o trabalho.
6. **Domínio:** se ainda não tiver um domínio pra clínica, não é bloqueante — o Coolify gera automaticamente uma URL tipo `algo.sslip.io` com HTTPS via Let's Encrypt. Dá pra trocar por um domínio próprio depois, sem re-trabalho.
7. Deploy.

⚠️ **Segurança:** isso deixa uma IDE completa (com terminal) exposta na internet, protegida só pela senha do passo 3. Pra hoje já é suficiente pra começar, mas vale, quando sobrar tempo, adicionar uma segunda camada — ex. IP allowlist no firewall do Coolify/Hostinger, ou basic auth do Traefik por cima (o próprio CLAUDE.md deste workspace tem um exemplo desse padrão, se quiser copiar a ideia).

## 2. Entrar no code-server

Abrir a URL gerada pelo Coolify no navegador, digitar a senha do passo 1.3. Vai abrir um VS Code completo, com terminal integrado — é ali que o resto acontece.

## 3. Instalar o Claude Code CLI

A imagem `codercom/code-server` já vem com `git`, `curl` e `sudo` sem senha para o usuário padrão (`coder`) — não precisa instalar nada disso.

No terminal integrado do code-server:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Isso instala o binário em `~/.local/bin/claude`, sem precisar de Node.js. Se depois de instalar o comando `claude` não for reconhecido, adicionar ao PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Rodar:

```bash
claude --version
claude
```

Na primeira vez, o `claude` mostra um link de login — abrir esse link em qualquer navegador (celular, notebook, não precisa ser na mesma máquina) e logar com a conta Claude do Bruno (assinatura **Pro** já é suficiente pra começar, ver conversa anterior). A sessão no terminal completa sozinha depois do login.

## 4. GitHub — instalar o `gh` CLI e autenticar

```bash
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y
gh auth login
```

`gh auth login` abre um fluxo por código (device flow) — mostra um código no terminal, você abre `github.com/login/device` em qualquer navegador e digita. Autentica como a própria conta do Bruno.

> **Nota:** hoje o repositório `clinica-fisio-conciliacao` é público, então dar `git clone` **não exige login nenhum** — o `gh auth login` só é necessário se/quando o Bruno for **enviar (push)** mudanças de volta pro repositório (o que exige virar colaborador, ou trabalhar num fork — combinar isso quando chegar a hora).

## 5. Clonar o projeto

```bash
git clone https://github.com/bbragazza/clinica-fisio-conciliacao.git ~/project
cd ~/project
```

(O caminho `~/project` já costuma ser o diretório padrão que o code-server abre — ajustar se necessário.)

## 6. Instalar o plugin Superpowers

Dentro da pasta do projeto, rodar `claude` para abrir uma sessão. Dentro dela:

1. Checar se já vem disponível por padrão:
   ```
   /plugin
   ```
   Se "superpowers" aparecer disponível em `claude-plugins-official`, instalar direto:
   ```
   /plugin install superpowers@claude-plugins-official
   ```
2. Se não aparecer, registrar a marketplace original do autor e instalar de lá:
   ```
   /plugin marketplace add obra/superpowers-marketplace
   /plugin install superpowers@superpowers-marketplace
   ```
3. **Não fazer os dois ao mesmo tempo** — bug conhecido de colisão de nome quando o plugin existe em duas marketplaces simultaneamente (dá erro falso de "já instalado"). Se acontecer, conferir primeiro com `/plugin` qual marketplace já tem o plugin antes de adicionar a outra.
4. Verificar: `/help` deve listar comandos como `/brainstorm`.

Como o ambiente aqui já é Linux/Ubuntu nativo, não existe a ressalva de Git Bash que valia pro Windows — as skills do Superpowers (estilo Unix) rodam de forma nativa.

## 7. Primeira interação sugerida

Dentro da pasta do projeto, com o Claude Code aberto:

> "Lê o brief em `docs/superpowers/specs/2026-08-29-conciliacao-comissionamento-design.md` e vamos começar o brainstorming técnico da v1 a partir dele."

Isso deve puxar a skill de brainstorming automaticamente e levar a uma conversa sobre stack técnica, modelo de dados e telas — já com o Bruno no controle, com contexto real da VPS (Ubuntu + Coolify disponíveis para deploy, se quiser publicar a v1 em vez de rodar só localmente na VPS).

## 8. Para depois (v1.1 — não fazer hoje)

Quando chegar a hora de investigar a automação do ZenFisio (seção 4.1 do brief):

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g playwright
npx playwright install --with-deps
```

Não instalar isso agora — só quando o núcleo da v1 (cadastro, cálculo, relatório) já estiver rodando.
