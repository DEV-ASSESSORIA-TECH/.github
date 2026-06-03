# Guia de Implantação — Tactical RMM
## Monitoramento e Auto-Remediação: OneDrive, Zabbix, Teams, TeamViewer

---

## Antes de começar

### Pré-requisitos obrigatórios
Antes de criar qualquer coisa no TRMM, você precisa ter em mãos:

1. **Zabbix**: IP/FQDN do servidor Zabbix. Ajuste `$ZabbixServer` em REMEDIATE_ZabbixAgent.ps1.
2. **TeamViewer**: MSI personalizado gerado pelo painel da sua conta TeamViewer
   (Management Console > Devices > Deploy > Custom configuration).
   Coloque o arquivo em `\\fileserver\rmm-repo\TeamViewer_Host.msi` ou ajuste o caminho.
3. **Teams**: Baixe o `teamsbootstrapper.exe` oficial:
   https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409
   Coloque em `C:\RMMCache\teamsbootstrapper.exe` em cada endpoint,
   OU distribua via script de onboarding (veja Passo 4).

---

## PASSO 1 — Criar os Scripts no Script Manager

**Navegue até:** `Settings > Scripts Manager`

Para cada script abaixo, clique em **New > New Script** e preencha exatamente assim:

---

### Script 1 — CHECK_ZabbixAgent

| Campo | Valor |
|---|---|
| Name | `CHECK - Zabbix Agent` |
| Description | Verifica se o servico Zabbix Agent esta instalado, habilitado e Running |
| Category | `Monitoring Checks` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `30` |

Cole o conteúdo de `CHECK_ZabbixAgent.ps1` no editor.

---

### Script 2 — REMEDIATE_ZabbixAgent

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - Zabbix Agent` |
| Description | Reabilita, inicia ou reinstala o Zabbix Agent conforme necessario |
| Category | `Monitoring Remediations` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `300` |

Cole o conteúdo de `REMEDIATE_ZabbixAgent.ps1` no editor.
**Lembre de ajustar `$ZabbixServer` e `$ZabbixMsiUrl` antes de salvar.**

---

### Script 3 — CHECK_TeamViewerHost

| Campo | Valor |
|---|---|
| Name | `CHECK - TeamViewer Host` |
| Description | Verifica servico TeamViewer instalado, habilitado e Running |
| Category | `Monitoring Checks` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `30` |

Cole o conteúdo de `CHECK_TeamViewerHost.ps1`.

---

### Script 4 — REMEDIATE_TeamViewerHost

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - TeamViewer Host` |
| Description | Reabilita, inicia ou reinstala o TeamViewer Host via MSI corporativo |
| Category | `Monitoring Remediations` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `300` |

Cole o conteúdo de `REMEDIATE_TeamViewerHost.ps1`.
**Ajuste `$TvMsiPath`, `$TvCustomConfigId` e `$TvAssignmentId` antes de salvar.**

---

### Script 5 — CHECK_TVMonitoring

| Campo | Valor |
|---|---|
| Name | `CHECK - TeamViewer Monitoring (1E Client)` |
| Description | Verifica se o servico 1E Client esta instalado e Running |
| Category | `Monitoring Checks` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `30` |

Cole o conteúdo de `CHECK_TVMonitoring.ps1`.

---

### Script 6 — REMEDIATE_TVMonitoring

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - TeamViewer Monitoring (1E Client)` |
| Description | Reabilita 1E Client ou reprovisiona via reinstalacao do TeamViewer Host |
| Category | `Monitoring Remediations` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `300` |

Cole o conteúdo de `REMEDIATE_TVMonitoring.ps1`.
**Ajuste `$TvMsiPath`, `$TvCustomConfigId` antes de salvar.**

---

### Script 7 — CHECK_OneDrive

| Campo | Valor |
|---|---|
| Name | `CHECK - OneDrive Sync` |
| Description | Verifica politica bloqueadora, instalacao e processo OneDrive.exe |
| Category | `Monitoring Checks` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `30` |

Cole o conteúdo de `CHECK_OneDrive.ps1`.

---

### Script 8 — REMEDIATE_OneDrive

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - OneDrive Sync` |
| Description | Remove politica bloqueadora, instala e reseta o OneDrive |
| Category | `Monitoring Remediations` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `300` |

Cole o conteúdo de `REMEDIATE_OneDrive.ps1`.

---

### Script 9 — CHECK_TeamsNew

| Campo | Valor |
|---|---|
| Name | `CHECK - Microsoft Teams (New)` |
| Description | Verifica pacote AppX MSTeams e processo ms-teams.exe |
| Category | `Monitoring Checks` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `30` |

Cole o conteúdo de `CHECK_TeamsNew.ps1`.

---

### Script 10 — REMEDIATE_TeamsNew

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - Microsoft Teams (New)` |
| Description | Provisiona ou relanca o novo Teams via teamsbootstrapper |
| Category | `Monitoring Remediations` |
| Type | `PowerShell` |
| Script Arguments | *(deixar em branco)* |
| Default Timeout | `300` |

Cole o conteúdo de `REMEDIATE_TeamsNew.ps1`.

---

## PASSO 2 — Criar a Automation Policy

**Navegue até:** `Settings > Automation Manager`

Clique em **Add** e preencha:

| Campo | Valor |
|---|---|
| Name | `Política - Apps Críticos (Monitoramento)` |
| Description | Checks e remediação automática: Zabbix, TeamViewer, OneDrive, Teams |
| Enabled | ✅ Marcado |
| Enforced | ✅ Marcado (garante que conflitos com configs diretas de agente sejam sobrescritos) |

Clique em **Submit** para salvar a policy em branco. Os checks e tasks serão adicionados a ela nos próximos passos.

---

## PASSO 3 — Criar os Checks dentro da Automation Policy

Na policy criada, clique na aba **Checks** e depois em **Add Check**.
Repita para cada check abaixo:

---

### Check A — Zabbix Agent

| Campo | Valor |
|---|---|
| Check Type | `Script Check` |
| Name | `Zabbix Agent - Instalado e Running` |
| Script | `CHECK - Zabbix Agent` *(selecionar da lista)* |
| Run Check Every | `60` *(segundos)* |
| Timeout | `30` |
| Alert Severity | `Error` |
| Number of failures before alert | `1` |

---

### Check B — TeamViewer Host

| Campo | Valor |
|---|---|
| Check Type | `Script Check` |
| Name | `TeamViewer Host - Instalado e Running` |
| Script | `CHECK - TeamViewer Host` |
| Run Check Every | `60` |
| Timeout | `30` |
| Alert Severity | `Error` |
| Number of failures before alert | `1` |

---

### Check C — TeamViewer Monitoring (1E Client)

| Campo | Valor |
|---|---|
| Check Type | `Script Check` |
| Name | `TeamViewer Monitoring (1E) - Instalado e Running` |
| Script | `CHECK - TeamViewer Monitoring (1E Client)` |
| Run Check Every | `60` |
| Timeout | `30` |
| Alert Severity | `Warning` |
| Number of failures before alert | `2` |

*(Warning e 2 falhas porque o 1E pode demorar alguns minutos para ser provisionado pelo console TeamViewer após reinstalação.)*

---

### Check D — OneDrive Sync

| Campo | Valor |
|---|---|
| Check Type | `Script Check` |
| Name | `OneDrive - Ativo e sem política bloqueadora` |
| Script | `CHECK - OneDrive Sync` |
| Run Check Every | `60` |
| Timeout | `30` |
| Alert Severity | `Warning` |
| Number of failures before alert | `2` |

*(Warning e 2 falhas porque OneDrive não executa quando não há usuário logado — comportamento esperado.)*

---

### Check E — Microsoft Teams

| Campo | Valor |
|---|---|
| Check Type | `Script Check` |
| Name | `Teams (New) - Pacote instalado e processo ativo` |
| Script | `CHECK - Microsoft Teams (New)` |
| Run Check Every | `60` |
| Timeout | `30` |
| Alert Severity | `Warning` |
| Number of failures before alert | `2` |

*(Mesma razão do OneDrive: processo só existe com usuário logado.)*

---

## PASSO 4 — Criar as Tasks de Remediação (On Check Failure)

Na mesma Automation Policy, clique na aba **Tasks** e depois em **Add Task**.
Repita para cada task abaixo:

---

### Task A — Remediar Zabbix

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - Zabbix Agent` |
| Trigger | `On Check Failure` |
| Associated Check | `Zabbix Agent - Instalado e Running` |
| Script | `REMEDIATE - Zabbix Agent` |
| Timeout | `300` |
| Continue on Error | *(deixar padrão / desmarcado)* |

---

### Task B — Remediar TeamViewer Host

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - TeamViewer Host` |
| Trigger | `On Check Failure` |
| Associated Check | `TeamViewer Host - Instalado e Running` |
| Script | `REMEDIATE - TeamViewer Host` |
| Timeout | `300` |

---

### Task C — Remediar TV Monitoring

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - TeamViewer Monitoring` |
| Trigger | `On Check Failure` |
| Associated Check | `TeamViewer Monitoring (1E) - Instalado e Running` |
| Script | `REMEDIATE - TeamViewer Monitoring (1E Client)` |
| Timeout | `300` |

---

### Task D — Remediar OneDrive

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - OneDrive Sync` |
| Trigger | `On Check Failure` |
| Associated Check | `OneDrive - Ativo e sem política bloqueadora` |
| Script | `REMEDIATE - OneDrive Sync` |
| Timeout | `300` |

---

### Task E — Remediar Teams

| Campo | Valor |
|---|---|
| Name | `REMEDIATE - Microsoft Teams (New)` |
| Trigger | `On Check Failure` |
| Associated Check | `Teams (New) - Pacote instalado e processo ativo` |
| Script | `REMEDIATE - Microsoft Teams (New)` |
| Timeout | `300` |

---

## PASSO 5 — Associar a Policy aos Agentes

**Opção A — Por Site (recomendado para todos os endpoints de um cliente):**

1. No painel principal, expanda o cliente na árvore da esquerda.
2. Clique com o botão direito no **Site** desejado > **Edit Site**.
3. Na aba ou campo **Automation Policy**, selecione `Política - Apps Críticos (Monitoramento)`.
4. Salve.

**Opção B — Por Cliente inteiro:**

1. Clique com o botão direito no **Cliente** > **Edit Client**.
2. Campo **Automation Policy** > selecione a policy.
3. Salve.

**Opção C — Por Agent individual (para teste antes do rollout):**

1. Clique com o botão direito no agente > **Edit Agent**.
2. Aba **Automation Policies** > adicione a policy.
3. Salve.

---

## PASSO 6 — Staging do teamsbootstrapper.exe (Teams)

O script de remediação do Teams depende de `C:\RMMCache\teamsbootstrapper.exe` nos endpoints.
Para distribuir isso automaticamente, crie uma **Task de Onboarding** na mesma policy:

**Navegue até:** Policy > Tasks > Add Task

| Campo | Valor |
|---|---|
| Name | `ONBOARDING - Staging teamsbootstrapper` |
| Trigger | `Onboarding` |
| Type | `PowerShell` |
| Timeout | `120` |

Conteúdo da task:
```powershell
$dest = 'C:\RMMCache'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force }
$url = 'https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile "$dest\teamsbootstrapper.exe" -UseBasicParsing
Write-Output "teamsbootstrapper.exe staged em $dest"
```

Esta task roda **uma vez automaticamente** quando o agente é instalado em um novo endpoint.

---

## PASSO 7 — Verificação final

Após aplicar a policy aos agentes, aguarde ~2 minutos para a sincronização e então:

1. Clique em qualquer agente > aba **Checks** — você deve ver os 5 checks listados.
2. Clique com o botão direito em qualquer check > **Run Check Now** para testar manualmente.
3. Clique na aba **Tasks** — você deve ver as 5 tasks de remediação + a de onboarding.
4. Para forçar um teste completo: desinstale um dos apps monitorados, aguarde 60s e veja
   o check falhar e a task de remediação ser disparada automaticamente.

---

## Referência rápida — Estrutura final da Policy

```
Política - Apps Críticos (Monitoramento)
├── CHECKS
│   ├── Zabbix Agent - Instalado e Running           [60s | Error  | 1 falha]
│   ├── TeamViewer Host - Instalado e Running        [60s | Error  | 1 falha]
│   ├── TeamViewer Monitoring (1E) - Running         [60s | Warning| 2 falhas]
│   ├── OneDrive - Ativo e sem política bloqueadora  [60s | Warning| 2 falhas]
│   └── Teams (New) - Pacote instalado e processo    [60s | Warning| 2 falhas]
└── TASKS (On Check Failure)
    ├── REMEDIATE - Zabbix Agent
    ├── REMEDIATE - TeamViewer Host
    ├── REMEDIATE - TeamViewer Monitoring
    ├── REMEDIATE - OneDrive Sync
    ├── REMEDIATE - Microsoft Teams (New)
    └── ONBOARDING - Staging teamsbootstrapper        [Trigger: Onboarding]
```
