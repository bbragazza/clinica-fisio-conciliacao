# Brief de negócio — App de Conciliação e Comissionamento (Clínica de Fisioterapia)

**Status:** aprovado pelo cliente (via terceiro, em nome do Bruno/Berta) em 29/08/2026 — pendente de revisão final por Bruno e Berta antes de virar spec técnica.
**Revisão de 30/08/2026:** decisão nova do cliente — **abandonar o ZenFisio por completo**. Mudou o escopo v1 (seções 2, 3, 4, 6, 7). Ver changelog no fim do arquivo.
**Tipo de documento:** brief de negócio (propositalmente SEM decisão de stack, modelagem de dados ou telas — isso é para o Bruno decidir com o Claude Code, na VPS da clínica, com contexto do ambiente dele).
**Este é o Item 1 de 2 de um projeto maior.** Item 2 (agente de IA para agendamento via WhatsApp) é um projeto separado, fora de escopo deste documento — só está registrado aqui como visão futura (seção 7) para não se perder. **Nota:** com a agenda passando a viver dentro do Item 1 (ver seção 3), o Item 2 passa a depender do modelo de dados de agenda daqui — não é mais totalmente independente.

---

## 1. Problema atual (as-is, histórico)

A clínica tem vários fisioterapeutas, cada um com sua agenda de pacientes. O processo até aqui:

1. O fisioterapeuta usa o **ZenFisio** (app no celular) para ver sua agenda e confirmar, sessão a sessão, se o paciente compareceu.
2. Ao final do atendimento, o paciente **assina um papel** atestando que esteve na clínica naquela data.
3. Periodicamente, a **secretária concilia manualmente** o registro do ZenFisio com os papéis assinados, cruzando ainda com um resumo que o próprio fisioterapeuta apresenta descrevendo o que fez.
4. **Berta** pega o resultado dessa conciliação (quantas sessões cada paciente fez, quanto pagou) e calcula quanto repassar para cada fisioterapeuta, aplicando o **percentual de acordo individual** (a maioria é 50/50, mas há variações — 40/60, 45/55 etc.).
5. Berta faz as **transferências bancárias** manualmente.

**Dor principal:** o cruzamento manual (ZenFisio × papel × relato do fisioterapeuta) é o ponto mais sujeito a erro do processo — sessão contada errada, divergência entre o que o fisioterapeuta diz e o que foi de fato registrado. O cálculo manual do repasse por fisioterapeuta também consome tempo de Berta.

**Defeito específico do ZenFisio que motiva a mudança:** ele soma o total de sessões do paciente (ex: "fez 12 sessões") mas **não registra as datas de cada sessão individualmente** — o que torna quase impossível auditar se aquelas 12 sessões realmente aconteceram nos dias em que o paciente esteve na clínica. É exatamente esse buraco que o check-in por QR code (seção 3), com confirmação datada sessão a sessão, resolve na raiz.

**Decisão de 30/08/2026:** em vez de automatizar por cima do ZenFisio, o cliente decidiu **substituí-lo inteiramente** pelo app novo — agenda, cadastro de profissionais e confirmação de atendimento passam a viver só aqui. Ver seção 3.

---

## 2. Atores e acesso (v1)

| Ator | Acesso ao app novo | Observação |
|---|---|---|
| Secretária(s) | Cria agendamentos, lança dados de pagamento, acompanha a conciliação | Interface de back-office (tela maior, VPS) |
| Berta | Revisa a conciliação e o relatório de repasse | Decide/aprova antes de transferir |
| **Fisioterapeutas** | **Acessam pelo próprio celular**: veem sua agenda de atendimentos e confirmam atendimento via leitura do QR code (seção 3) | **Novo em v1** — antes ficavam de fora, agora são usuários ativos do app, substituindo o uso do ZenFisio |
| Pacientes | Recebem/mostram o QR code do agendamento na chegada — não têm login/conta própria na v1 | Sem autoagendamento na v1 (ver seção 4) |

Escala: entre **10 e 15 profissionais**. Back-office usado por 1-2 pessoas (secretária + Berta); o acesso dos fisioterapeutas passa a ser por celular, individual, um por profissional.

---

## 3. Escopo v1

- **Cadastro de fisioterapeutas**, cada um com seu **percentual de acordo** configurável (não é um valor fixo único para todos), e login próprio para acesso pelo celular.
- **Agenda / agendamento** — **novo módulo, substitui o ZenFisio por completo**:
  - Secretária (ou Berta) cria o agendamento: paciente + fisioterapeuta + data/hora.
  - Fisioterapeuta acessa, pelo celular, a própria agenda (só os agendamentos atribuídos a ele).
  - **Sem autoagendamento do paciente na v1** — só a secretária/Berta marcam horário (ver seção 4).
- **Check-in e confirmação de atendimento via QR code** — substitui de vez a assinatura em papel:
  - Cada agendamento gera **um QR code único**.
  - **Na chegada:** o paciente mostra esse QR (a recepção lê) → marca "paciente chegou" naquele agendamento.
  - **No fim da sessão:** o **fisioterapeuta** lê o **mesmo QR**, pelo celular → confirma "atendimento realizado", fechando o ciclo daquele agendamento específico.
  - **Sem geolocalização na v1** — só o QR mesmo (geolocalização combinada foi considerada e fica pra depois, ver seção 4).
  - Essa confirmação do fisioterapeuta **é** o registro de atendimento — não existe mais entrada manual olhando o ZenFisio na tela, porque o ZenFisio deixa de ser usado.
- **Catálogo de modalidades de pagamento**, configurável, cobrindo pelo menos as que já existem hoje:
  - **Plano** (mensal / trimestral / semestral) — pago **antecipadamente**; regra de corte comum: precisa ser adquirido até o **dia 5 do mês** pra valer no mês corrente (confirmar se essa regra vale igual pra todos os planos ou varia por modalidade — ver seção 6).
  - **Avulso** — paciente paga logo depois de cada consulta.
  - **Pós-pago mensal** — paciente acumula as sessões do mês e paga tudo no fechamento.
  - Cada modalidade tem seu(s) valor(es) associado(s), e **cada paciente é vinculado a uma modalidade** específica.
  - Berta já tem uma **planilha própria** (fora do ZenFisio) com o catálogo completo de modalidades e valores — dá pra exportar/importar direto pra popular esse cadastro na v1, sem digitação manual do catálogo.
- **Registro dos pagamentos efetivamente realizados** (valor, data, por paciente) — fonte exata ainda não 100% confirmada (ver seção 6); **entrada manual em v1**.
- **Cálculo automático do repasse por fisioterapeuta**: sessões confirmadas via QR × valor × percentual do acordo daquele profissional, com **detalhamento por paciente/sessão** para permitir auditoria (poder responder "por que esse valor?" abrindo o detalhe).
- **Relatório de repasse por fisioterapeuta** (visualização em tela + exportação, ex. PDF ou planilha). A transferência bancária em si continua manual, fora do app.
- **Migração inicial de dados do ZenFisio** (cadastro de profissionais e agendas existentes) — ver seção 4.1 sobre como.
- **Ciclo de uso da conciliação/repasse:** parcial **semanal** + fechamento **mensal**. (A agenda em si é usada continuamente, todo dia.)
- **Ambiente:** roda em uma **VPS própria (Hostinger + Coolify)**, acessível via navegador através de um code-server para o desenvolvimento; o app em produção precisa ser acessível também **pelo celular dos fisioterapeutas** (a forma exata — PWA, web responsivo, app nativo — é decisão técnica do Bruno na sessão local, não deste brief).

---

## 4. Fora de escopo v1 (decisão deliberada, registrada para não se perder)

### 4.1 Migração de dados existentes (não é mais "automação contínua")
Como o ZenFisio deixa de ser usado, o problema muda de figura: não precisa mais de extração contínua pra validar atendimento (esse papel passa a ser do QR code, seção 3) — precisa só de uma **migração pontual**, antes do go-live. E são **fontes distintas**, a confirmar cada uma:

- **ZenFisio** — tem cadastro de profissionais e catálogo de atividades/valores. Confirmado que existe lá.
- **Agenda (datas dos agendamentos)** — Berta acredita que a agenda de fato vive no **Google Calendar**, não no ZenFisio (a confirmar). Se for isso, a migração da agenda pode depender de exportação/API do Google Calendar em vez do ZenFisio.
- **Catálogo de modalidades de pagamento e valores** — já existe numa planilha própria da Berta, fora do ZenFisio — exportação direta, sem necessidade de investigação técnica.

**Primeiro passo, antes de decidir a técnica:** confirmar exatamente onde cada um desses três conjuntos vive hoje, e se há exportação nativa (CSV/Excel/relatório) em cada um — especialmente ZenFisio e Google Calendar. Se não houver exportação nativa em algum deles, plano B é engenharia reversa via DevTools do navegador (com credencial de admin) + **Playwright**, mas só para uma extração pontual de migração, não uma automação recorrente — risco e esforço bem menores que o cenário original.

### 4.2 Outros itens explicitamente fora da v1
- **Autoagendamento do paciente** — considerado e descartado para v1: só secretária/Berta criam agendamentos (ver seção 2). Pode entrar em versão futura.
- **Geolocalização combinada com o QR code** — considerado e descartado para v1: o check-in usa só a leitura do QR, sem validar localização física do paciente. Pode entrar em versão futura, se fraude/erro de check-in virar problema real.
- **Geração de arquivo de pagamento em lote** (Pix em lote / CNAB) — v1 só gera o relatório; a transferência em si é manual, no banco da Berta.
- **Item 2 completo** (agente de IA para interação/agendamento via WhatsApp) — projeto separado, terá seu próprio brief quando chegar a vez. Como agora existe um módulo de agenda no Item 1, o Item 2 vai precisar se integrar a ele (criar agendamentos via WhatsApp na mesma base) — não é mais um projeto isolado, mas o design detalhado disso fica pra quando chegar a vez.

---

## 5. Critérios de sucesso da v1

Os dois pesam igual:

1. **Reduzir/eliminar a divergência na conciliação** atendimento-vs-pagamento — ter um registro único, confiável e auditável de quem atendeu quem, quando, e quanto foi pago, sem depender de papel nem de conciliação manual entre sistemas.
2. **Agilizar o cálculo de repasse** — eliminar o trabalho manual de Berta para apurar quanto pagar a cada fisioterapeuta a cada ciclo.

---

## 6. Incógnitas a investigar cedo (não bloqueiam o início do trabalho, mas precisam de resposta logo)

- **O ZenFisio tem função de exportação de cadastro/atividades?** (CSV, Excel, relatório) — decide se a migração desses dados (seção 4.1) é simples ou exige engenharia reversa.
- **A agenda (datas dos agendamentos) vive de fato onde?** Berta acredita que seja no **Google Calendar**, não no ZenFisio, mas não tem certeza — confirmar. Se for Google Calendar, verificar exportação/API de lá também.
- **A planilha de modalidades/valores da Berta também registra os pagamentos efetivamente realizados** (data, valor, por paciente), ou só o catálogo de planos e a modalidade escolhida por cada paciente? Se só o catálogo, o lançamento do pagamento em si (avulso pós-consulta, ou fechamento do mês) ainda precisa de um local de registro — provavelmente entrada manual no app na v1.
- **A regra do "dia 5 do mês" pra aderir a um plano** — vale igual pra mensal, trimestral e semestral, ou varia por modalidade?
- **Lista completa dos fisioterapeutas e o percentual de acordo de cada um** — confirmar com Berta.
- **Formato de exportação do relatório de repasse** que for mais útil pra Berta (PDF? Excel? os dois?) — decidir com ela ao ver o primeiro protótipo.
- **Como o fisioterapeuta vai acessar o app pelo celular** (PWA, web responsivo, app nativo) — decisão técnica do Bruno na sessão local, mas registrar aqui que é um requisito de negócio (precisa funcionar bem no celular), não um "nice to have".

---

## 7. Visão futura (fora do escopo desta spec, registrada para contexto)

- **Autoagendamento do paciente** (seção 4.2) — paciente escolhe horário disponível direto, sem depender da secretária.
- **Geolocalização combinada ao QR code** (seção 4.2) — camada extra de confirmação de presença física.
- **Geração de arquivo de pagamento em lote** — automatizar a transferência bancária em si, não só o relatório.
- **Item 2** — agente de IA para interação/agendamento de pacientes via WhatsApp, criando agendamentos na mesma agenda do Item 1. Projeto próprio, com seu próprio brief e ciclo de brainstorming, a ser iniciado depois que o Item 1 estiver estável.

---

## 8. Próximos passos sugeridos (para o Bruno, na VPS da clínica)

1. Setup do ambiente: ver `docs/setup-vps-clinica.md` neste mesmo repositório.
2. Abrir o Claude Code na pasta do projeto e pedir para ele **ler este brief**.
3. Rodar um novo ciclo de brainstorming a partir daqui — agora sim decidindo, junto com o Claude Code local: stack técnica, modelo de dados (agenda + QR + comissionamento), telas, e como o fisioterapeuta vai acessar pelo celular. O Superpowers vai puxar a skill de brainstorming automaticamente.
4. Investigar cedo as três fontes de migração — ZenFisio (cadastro/atividades), Google Calendar (agenda, a confirmar) e a planilha da Berta (modalidades de pagamento) — seção 6, decide o tamanho do trabalho de migração antes de fechar o modelo de dados.
5. Confirmar com Berta as demais incógnitas da seção 6 antes ou durante essa conversa.
6. Tratar como v1: cadastro + agenda + QR check-in/confirmação + pagamento manual + cálculo + relatório. Autoagendamento, geolocalização e o Item 2 ficam pra depois (seção 7).

---

## Changelog

- **29/08/2026** — versão inicial: back-office (secretária + Berta), entrada manual olhando ZenFisio, sem agenda própria, sem acesso de fisioterapeuta.
- **30/08/2026** — cliente decide abandonar o ZenFisio por completo. Agenda e confirmação de atendimento via QR code passam a ser parte do núcleo da v1; fisioterapeuta vira usuário ativo (celular). Migração de dados do ZenFisio substitui a automação de extração contínua que estava planejada.
- **30/08/2026 (2)** — detalhamento das modalidades de pagamento (plano mensal/trimestral/semestral antecipado com regra do dia 5, avulso, pós-pago mensal) e catálogo próprio da Berta pra importar. Identificado que a agenda pode viver no Google Calendar em vez do ZenFisio (a confirmar) — migração passa a ter três fontes possíveis em vez de uma só.
