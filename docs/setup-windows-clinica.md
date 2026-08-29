# Setup do ambiente — PC Windows da clínica

Guia passo a passo para o Bruno preparar o computador da clínica e começar a trabalhar com o Claude Code. Testado/validado com base na documentação oficial em agosto/2026 — se algo já não bater (o Claude Code atualiza rápido), seguir o que o próprio instalador disser.

## 1. Claude Code CLI (instalador nativo — não precisa de Node.js nem WSL)

Abrir o **PowerShell** (não precisa ser administrador) e rodar:

```powershell
irm https://claude.ai/install.ps1 | iex
```

Abrir um **novo** terminal depois de instalar (pra pegar o PATH atualizado) e rodar:

```powershell
claude
```

Isso abre o navegador para login (usar a conta Anthropic/Claude do Bruno). Depois de logado, a sessão já funciona.

> Fonte: [morphllm.com — Install Claude Code](https://www.morphllm.com/install-claude-code), [thepromptshelf.dev — Native Install Guide](https://thepromptshelf.dev/blog/claude-code-windows-native-install-2026/)

## 2. Git for Windows (necessário — não é opcional)

Baixar e instalar de [git-scm.com](https://git-scm.com/download/win) (aceitar as opções padrão do instalador).

**Por quê é necessário:** sem o Git for Windows instalado, o Claude Code no Windows cai para PowerShell puro para rodar comandos — e boa parte das skills do Superpowers (que vamos instalar no passo 4) espera um shell estilo Unix (bash, grep, sed etc.). Com o Git for Windows instalado, o Claude Code usa o **Git Bash** dele automaticamente para o Bash tool, o que evita atrito.

> Fonte: [claudecodeguides.com — Windows Git Bash Required](https://claudecodeguides.com/claude-code-windows-git-bash-required-fix/)

Depois de instalar, configurar a identidade do Git (rodar no PowerShell ou Git Bash):

```bash
git config --global user.name "Bruno <sobrenome>"
git config --global user.email "email-do-bruno@..."
```

## 3. VS Code (recomendado, não obrigatório)

Baixar em [code.visualstudio.com](https://code.visualstudio.com/). Serve como editor com terminal integrado — dá pra rodar `claude` direto no terminal integrado do VS Code, o que é mais confortável do que ficar trocando de janela.

## 4. Criar a pasta do projeto e trazer o brief

1. Criar uma pasta local, por exemplo `C:\Users\<usuario>\projetos\clinica-fisio-conciliacao`.
2. Copiar este repositório inteiro pra lá — o jeito mais simples é criar um repositório (privado) no GitHub e dar `git clone` na máquina da clínica. Se não quiser lidar com GitHub agora, também dá para simplesmente copiar a pasta `docs/` por pen-drive ou e-mail.
3. Confirmar que o arquivo `docs/superpowers/specs/2026-08-29-conciliacao-comissionamento-design.md` está lá dentro — é o brief de negócio que vai servir de ponto de partida.

## 5. Instalar o plugin Superpowers

Dentro da pasta do projeto, abrir o terminal e rodar `claude` para entrar numa sessão. Dentro da sessão:

1. Primeiro, checar se o Superpowers já vem disponível por padrão (ele pode já estar embutido na marketplace oficial do Claude Code, dependendo da versão):
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
3. **Não fazer os dois ao mesmo tempo.** Há um bug conhecido de colisão de nome quando o mesmo plugin existe em duas marketplaces (`claude-plugins-official` e `superpowers-marketplace` simultaneamente) — o instalador confunde qual é qual e pode dar erro de "já instalado" mesmo sem estar. Se isso acontecer, não insistir tentando instalar de novo — conferir primeiro qual marketplace já tem o plugin (`/plugin`) antes de adicionar a outra.
4. Verificar que funcionou: `/help` deve listar comandos como `/brainstorm`.

> Fonte: [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace), [workaround do bug de colisão](https://gist.github.com/gwpl/cd6dcd899ca0acce1b4a1bc486d56a9e)

## 6. Primeira interação sugerida

Com o Claude Code aberto dentro da pasta do projeto:

> "Lê o brief em `docs/superpowers/specs/2026-08-29-conciliacao-comissionamento-design.md` e vamos começar o brainstorming técnico da v1 a partir dele."

Isso deve puxar a skill de brainstorming automaticamente (via Superpowers) e levar a uma conversa sobre stack técnica, modelo de dados e telas — dessa vez já com o Bruno no controle e com contexto real do ambiente Windows da clínica.

## 7. Para depois (v1.1 — não fazer hoje)

Quando chegar a hora de investigar a automação do ZenFisio (seção 4.1 do brief), vai ser necessário:
- **Node.js LTS** (para rodar Playwright)
- **Playwright**: `npm install -g playwright` (ou como dependência do projeto) + `npx playwright install`

Não instalar isso agora — só quando o núcleo da v1 (cadastro, cálculo, relatório) já estiver rodando.
