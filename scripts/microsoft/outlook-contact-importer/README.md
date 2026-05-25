# Outlook Contact Importer

Ferramenta em Node.js para recuperar contatos a partir de e-mails existentes em uma conta Microsoft 365.

O projeto lê mensagens da **Caixa de Entrada** e dos **Itens Enviados**, extrai remetentes e destinatários, remove duplicados, gera um CSV para revisão e, após confirmação manual, cria os contatos no Outlook.

## Objetivo

Este script foi criado para cenários de migração de e-mails, especialmente quando mensagens foram migradas de outro provedor, como cPanel, mas os contatos do usuário não foram importados.

Ele ajuda a reconstruir uma lista inicial de contatos a partir dos próprios e-mails enviados e recebidos.

## Funcionalidades

- Login individual com conta Microsoft 365
- Autenticação via Device Code
- Leitura da Caixa de Entrada
- Leitura dos Itens Enviados
- Extração de remetentes e destinatários
- Remoção de e-mails duplicados
- Filtros para ignorar e-mails automáticos
- Geração de CSV para revisão
- Importação de contatos somente após confirmação
- Verificação de contatos já existentes no Outlook
- Geração de executáveis `.exe` para Windows
- Suporte a execução sem Node.js/npm na máquina final
- Workflow de release via GitHub Actions

## Estrutura do projeto

```txt
outlook-contact-importer/
├─ data/
│  └─ output-example.csv
├─ import-contacts-preview.js
├─ import-contacts-apply.js
├─ run-outlook-contact-importer.bat
├─ package.json
├─ package-lock.json
├─ .env.example
├─ .gitignore
└─ README.md
```

## Requisitos para desenvolvimento

- Node.js 22 ou superior
- npm
- Conta Microsoft 365 com Exchange Online
- App Registration no Microsoft Entra ID

## App Registration

No Microsoft Entra ID, crie um App Registration para o importador.

Permissões delegadas necessárias no Microsoft Graph:

```txt
User.Read
Mail.Read
Contacts.ReadWrite
```

Também é necessário ativar:

```txt
Permitir fluxos de cliente público
```

ou:

```txt
Allow public client flows
```

Após adicionar as permissões, conceda consentimento de administrador para o aplicativo.

## Configuração local

Crie um arquivo `.env` na raiz do projeto com base no `.env.example`:

```env
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

Onde:

- `TENANT_ID` é o ID do locatário/diretório
- `CLIENT_ID` é o ID do aplicativo/cliente

## Instalação

```bash
npm install
```

## Scripts disponíveis

```json
{
  "preview": "node import-contacts-preview.js",
  "import": "node import-contacts-apply.js",
  "build:preview": "pkg import-contacts-preview.js --targets node22-win-x64 --fallback-to-source --output dist/outlook-contacts-preview.exe",
  "build:import": "pkg import-contacts-apply.js --targets node22-win-x64 --fallback-to-source --output dist/outlook-contacts-import.exe",
  "build": "npm run build:preview && npm run build:import"
}
```

## Uso em desenvolvimento

### 1. Gerar prévia dos contatos

```bash
npm run preview
```

O script solicitará login Microsoft pelo navegador.

Após a autenticação, será gerado:

```txt
data/contacts-preview.csv
```

Nenhum contato é criado nessa etapa.

### 2. Revisar o CSV

Abra o arquivo gerado:

```powershell
notepad .\data\contacts-preview.csv
```

Remova contatos indesejados, como:

```txt
no-reply
noreply
mailer-daemon
postmaster
notificações automáticas
sistemas
e-mails inválidos
e-mails que não devem virar contato
```

### 3. Importar contatos

Após revisar o CSV:

```bash
npm run import
```

O script mostrará um resumo da importação.

Para confirmar, digite exatamente:

```txt
IMPORTAR
```

Se qualquer outro valor for informado, a importação será cancelada.

## Uso em máquinas sem Node.js

O projeto pode gerar executáveis Windows:

```bash
npm run build
```

Os arquivos serão criados em:

```txt
dist/
├─ outlook-contacts-preview.exe
└─ outlook-contacts-import.exe
```

Esses executáveis podem ser usados em máquinas sem Node.js ou npm.

A máquina final precisa apenas ter:

```txt
.env
data/
outlook-contacts-preview.exe
outlook-contacts-import.exe
```

## Execução assistida via BAT

O arquivo:

```txt
run-outlook-contact-importer.bat
```

pode ser usado para facilitar o processo em máquinas Windows.

Ele pode:

- Baixar os executáveis da release do GitHub
- Criar a pasta `data`
- Solicitar `TENANT_ID` e `CLIENT_ID`
- Criar o arquivo `.env`
- Executar o preview
- Abrir o CSV para revisão
- Executar a importação

## Build

Para gerar os executáveis localmente:

```bash
npm run build
```

Saída esperada:

```txt
dist/
├─ outlook-contacts-preview.exe
└─ outlook-contacts-import.exe
```

## Release via GitHub Actions

O projeto pode ser publicado por tag usando GitHub Actions.

Padrão de tag:

```txt
outlook-contact-importer-v1.0.0
```

Exemplo:

```powershell
git tag outlook-contact-importer-v1.0.0
git push origin outlook-contact-importer-v1.0.0
```

A release deve publicar os seguintes assets:

```txt
outlook-contacts-preview.exe
outlook-contacts-import.exe
outlook-contact-importer-windows.zip
```

Os executáveis separados são importantes para permitir que o `.bat` baixe apenas os arquivos necessários.

## Arquivos que não devem ser versionados

Não suba para o GitHub:

```txt
node_modules/
dist/
release/
.env
data/contacts-preview.csv
```

Esses arquivos devem ficar no `.gitignore`.

## Arquivos que devem ser versionados

Suba para o GitHub:

```txt
import-contacts-preview.js
import-contacts-apply.js
run-outlook-contact-importer.bat
package.json
package-lock.json
.env.example
README.md
data/output-example.csv
.gitignore
```

## Exemplo de .gitignore

```gitignore
node_modules/
dist/
release/
.env

data/contacts-preview.csv
data/*.local.csv
data/*.private.csv

.DS_Store
Thumbs.db
```

## Diferença entre contatos e AutoComplete

O Outlook possui uma lista de sugestões que aparece quando o usuário começa a digitar um endereço.

Essa lista não é exatamente a mesma coisa que a lista de contatos.

Este projeto cria contatos reais no Outlook. Esses contatos podem ajudar nas sugestões futuras, mas o script não manipula diretamente o cache interno de AutoComplete do Outlook.

## Limitações

- Não acessa diretamente o cache de AutoComplete
- Não remove contatos existentes
- Não atualiza contatos já existentes
- Não importa fotos de contatos
- Não sincroniza contatos continuamente
- Não executa em múltiplas caixas automaticamente
- Não substitui uma ferramenta corporativa de migração

## Erros comuns

### `invalid_client`

Verifique se o App Registration está com fluxo de cliente público habilitado:

```txt
Permitir fluxos de cliente público: Sim
```

### Permissão negada

Confirme se o app possui as permissões delegadas:

```txt
User.Read
Mail.Read
Contacts.ReadWrite
```

E se o consentimento de administrador foi concedido.

### CSV não encontrado

Execute primeiro:

```bash
npm run preview
```

Ou confirme se o arquivo existe em:

```txt
data/contacts-preview.csv
```

### Executável não encontra `.env`

O arquivo `.env` deve estar na mesma pasta em que o executável está sendo executado.

Exemplo:

```txt
outlook-contact-importer/
├─ .env
├─ data/
├─ outlook-contacts-preview.exe
└─ outlook-contacts-import.exe
```

## Status

Projeto utilitário para migrações pontuais de contatos para Microsoft 365, com execução manual, revisão prévia e confirmação antes da criação dos contatos.
