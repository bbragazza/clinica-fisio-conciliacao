# Brief de negócio — App de Conciliação e Comissionamento (Clínica de Fisioterapia)

**Status:** aprovado pelo cliente (via terceiro, em nome do Bruno/Berta) em 29/08/2026 — pendente de revisão final por Bruno e Berta antes de virar spec técnica.
**Tipo de documento:** brief de negócio (propositalmente SEM decisão de stack, modelagem de dados ou telas — isso é para o Bruno decidir com o Claude Code, no computador da clínica, com contexto do ambiente dele).
**Este é o Item 1 de 2 de um projeto maior.** Item 2 (agente de IA para agendamento via WhatsApp) é um projeto separado, fora de escopo deste documento — só está registrado aqui como visão futura (seção 8) para não se perder.

---

## 1. Problema atual (as-is)

A clínica tem vários fisioterapeutas, cada um com sua agenda de pacientes. O processo hoje:

1. O fisioterapeuta usa o **ZenFisio** (app no celular) para ver sua agenda e confirmar, sessão a sessão, se o paciente compareceu.
2. Ao final do atendimento, o paciente **assina um papel** atestando que esteve na clínica naquela data.
3. Periodicamente, a **secretária concilia manualmente** o registro do ZenFisio com os papéis assinados, cruzando ainda com um resumo que o próprio fisioterapeuta apresenta descrevendo o que fez.
4. **Berta** pega o resultado dessa conciliação (quantas sessões cada paciente fez, quanto pagou) e calcula quanto repassar para cada fisioterapeuta, aplicando o **percentual de acordo individual** (a maioria é 50/50, mas há variações — 40/60, 45/55 etc.).
5. Berta faz as **transferências bancárias** manualmente.

**Dor principal:** o cruzamento manual (ZenFisio × papel × relato do fisioterapeuta) é o ponto mais sujeito a erro do processo — sessão contada errada, divergência entre o que o fisioterapeuta diz e o que foi de fato registrado. O cálculo manual do repasse por fisioterapeuta também consome tempo de Berta.

---

## 2. Atores e acesso (v1)

| Ator | Acesso ao app novo | Observação |
|---|---|---|
| Secretária(s) | Lança dados de atendimento e de pagamento | Entrada manual em v1 (ver seção 3) |
| Berta | Revisa a conciliação e o relatório de repasse | Decide/aprova antes de transferir |
| Fisioterapeutas | Nenhum acesso ao app novo em v1 | Continuam só no ZenFisio + papel, como hoje. Login próprio é visão futura (seção 8) |

Escala: entre **10 e 15 profissionais**. Uso por 1-2 pessoas (secretária + Berta), sem necessidade de acesso concorrente multiusuário na v1.

---

## 3. Escopo v1

- **Cadastro de fisioterapeutas**, cada um com seu **percentual de acordo** configurável (não é um valor fixo único para todos).
- **Registro de atendimentos** (fisioterapeuta, paciente, data/hora) — **entrada manual**: a secretária digita olhando o ZenFisio na tela. Nenhuma automação de extração de dados do ZenFisio em v1 (ver seção 4 sobre por quê).
- **Registro de pagamentos de pacientes** (valor, data, forma) — fonte exata ainda não confirmada com o Bruno (ver seção 6); entrada manual em v1 também.
- **Cálculo automático do repasse por fisioterapeuta**: sessões válidas × valor × percentual do acordo daquele profissional, com **detalhamento por paciente/sessão** para permitir auditoria (poder responder "por que esse valor?" abrindo o detalhe).
- **Relatório de repasse por fisioterapeuta** (visualização em tela + exportação, ex. PDF ou planilha). A transferência bancária em si continua manual, fora do app.
- **Ciclo de uso:** conciliação parcial **semanal** + fechamento **mensal**.
- **Ambiente:** roda em uma **VPS própria (Hostinger + Coolify)**, acessível via navegador através de um code-server — não é mais um único computador físico da clínica, mas o uso continua restrito a secretária(s) + Berta (ver seção 2), sem necessidade de acesso concorrente multiusuário na v1. (Decisão atualizada em 29/08/2026, ver `docs/setup-vps-clinica.md`.)

---

## 4. Fora de escopo v1 (decisão deliberada, registrada para não se perder)

### 4.1 v1.1 — Automação de extração de dados
Não existe API pública do ZenFisio. A forma cogitada de automatizar a extração é **engenharia reversa via DevTools do navegador** (com uma credencial de admin), inspecionando as requisições que o painel web faz — mesma abordagem já usada anteriormente com a Unimed — e depois **automatizando com Playwright**. Essa automação (tanto do lado ZenFisio quanto de uma eventual integração com o sistema de pagamentos) **fica fora da v1** e vira o próximo passo (v1.1), depois que o núcleo do app (cadastro, cálculo, relatório) já estiver funcionando com entrada manual. Motivo da decisão: reduzir o risco de o início do projeto ficar travado numa investigação técnica incerta antes de existir algo utilizável.

### 4.2 Outros itens explicitamente fora da v1
- **Geração de arquivo de pagamento em lote** (Pix em lote / CNAB) — v1 só gera o relatório; a transferência em si é manual, no banco da Berta.
- **Login e visão própria para fisioterapeutas** (ver seus próprios atendimentos/comissões) — pode entrar em versão futura, não na v1.
- **Item 2 completo** (agente de IA para interação/agendamento via WhatsApp) — projeto separado, terá seu próprio brief quando chegar a vez.

---

## 5. Critérios de sucesso da v1

Os dois pesam igual:

1. **Reduzir/eliminar a divergência na conciliação** atendimento-vs-pagamento — ter um registro único, confiável e auditável de quem atendeu quem, quando, e quanto foi pago, com o mínimo de retrabalho de cruzar papel/relato/app.
2. **Agilizar o cálculo de repasse** — eliminar o trabalho manual de Berta para apurar quanto pagar a cada fisioterapeuta a cada ciclo.

---

## 6. Incógnitas a investigar cedo (não bloqueiam o início do trabalho, mas precisam de resposta logo)

- **Onde vive hoje o registro de pagamento dos pacientes?** Hipótese é que seja um sistema ou planilha separada — a confirmar com o Bruno. O app precisa, no mínimo, de uma tela para lançar esse dado manualmente enquanto isso não é confirmado/integrado.
- **Lista completa dos fisioterapeutas e o percentual de acordo de cada um** — confirmar com Berta.
- **Formato de exportação do relatório de repasse** que for mais útil pra Berta (PDF? Excel? os dois?) — decidir com ela ao ver o primeiro protótipo.

---

## 7. Visão futura (fora do escopo desta spec, registrada para contexto)

Ainda dentro do "Item 1" (processo de conciliação/pagamento), a ideia de médio prazo é digitalizar o check-in do paciente na clínica — hoje feito por assinatura em papel — por algo como um **QR code** (com apoio de geolocalização para confirmar presença física), que o fisioterapeuta valida no próprio ZenFisio (ou em uma tela própria), eliminando de vez a etapa de papel e facilitando a conciliação automática do "quem atendeu quem, quando". Essa evolução **não faz parte da v1** e só deve ser desenhada depois que o núcleo (cadastro, cálculo, relatório) estiver validado em uso real.

Separadamente, o **Item 2** do projeto maior é um agente de IA para interação/agendamento de pacientes via WhatsApp — projeto próprio, com seu próprio brief e ciclo de brainstorming, a ser iniciado depois que o Item 1 estiver estável.

---

## 8. Próximos passos sugeridos (para o Bruno, no computador da clínica)

1. Instalar Claude Code CLI (ver `docs/setup-windows-clinica.md` neste mesmo repositório).
2. Abrir o Claude Code nesta pasta do projeto e pedir para ele **ler este brief**.
3. Rodar um novo ciclo de brainstorming a partir daqui — agora sim decidindo, junto com o Claude Code local: stack técnica, modelo de dados, telas. O Superpowers vai puxar a skill de brainstorming automaticamente.
4. Confirmar com Berta as incógnitas da seção 6 antes ou durante essa conversa.
5. Tratar isso como a v1: cadastro + entrada manual + cálculo + relatório. Resistir à tentação de já entrar na automação do ZenFisio (seção 4.1) antes de ter a v1 rodando de ponta a ponta.
