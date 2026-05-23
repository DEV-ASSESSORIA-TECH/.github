# Importador de Contatos Outlook

Script em Node.js para recuperar contatos a partir dos e-mails existentes em uma conta Microsoft 365.

Ele lê mensagens da **Caixa de Entrada** e dos **Itens Enviados**, extrai remetentes e destinatários, remove e-mails duplicados, gera uma prévia em CSV e, após confirmação manual, cria os contatos no Outlook.

## Funcionalidades

- Login individual via Microsoft Device Code
- Leitura de e-mails da conta logada
- Extração de contatos da Caixa de Entrada e Itens Enviados
- Remoção de contatos duplicados
- Geração de arquivo `contacts-preview.csv`
- Importação de contatos somente após confirmação no terminal
- Verificação de contatos já existentes antes de criar novos

## Requisitos

- Node.js instalado
- Conta Microsoft 365 com Exchange Online
- App Registration no Microsoft Entra ID
- Permissões delegadas no Microsoft Graph:
  - `User.Read`
  - `Mail.Read`
  - `Contacts.ReadWrite`

## Configuração do App Registration

No Microsoft Entra Admin Center:

1. Acesse **Registros de aplicativo**
2. Crie ou abra o app do importador
3. Copie:
   - **ID do aplicativo (cliente)**
   - **ID do diretório (locatário)**
4. Vá em **Autenticação**
5. Ative **Permitir fluxos de cliente público**

## Instalação

```bash
npm install
```

Caso esteja criando o projeto do zero:

```bash
npm init -y
npm install @azure/identity @microsoft/microsoft-graph-client isomorphic-fetch
```

## Configuração

Nos arquivos `import-contacts-preview.js` e `import-contacts-apply.js`, configure:

```js
const TENANT_ID = "SEU_ID_DO_LOCATARIO";
const CLIENT_ID = "SEU_ID_DO_APLICATIVO_CLIENTE";
```

Atenção:

- `TENANT_ID` é o ID do locatário/diretório.
- `CLIENT_ID` é o ID do aplicativo cliente.
- Não use o ID do locatário no lugar do Client ID.

## Scripts

No `package.json`:

```json
{
  "type": "module",
  "scripts": {
    "preview": "node import-contacts-preview.js",
    "import": "node import-contacts-apply.js"
  },
  "dependencies": {
    "@azure/identity": "^4.0.0",
    "@microsoft/microsoft-graph-client": "^3.0.0",
    "isomorphic-fetch": "^3.0.0"
  }
}
```

## Como usar

### 1. Gerar prévia dos contatos

```bash
npm run preview
```

O script vai solicitar login pelo navegador usando um código da Microsoft.

Após o login, será gerado o arquivo:

```txt
contacts-preview.csv
```

Nenhum contato será criado nessa etapa.

### 2. Revisar o CSV

Abra o arquivo gerado e remova contatos indesejados, como:

- `no-reply`
- `noreply`
- `mailer-daemon`
- notificações automáticas
- sistemas
- e-mails que não devem virar contato

No Windows:

```powershell
notepad contacts-preview.csv
```

### 3. Importar os contatos

Depois de revisar o CSV:

```bash
npm run import
```

O script irá mostrar um resumo e pedir confirmação.

Para confirmar, digite exatamente:

```txt
IMPORTAR
```

Se qualquer outro texto for digitado, a importação será cancelada.

## Estrutura sugerida

```txt
script/
├─ import-contacts-preview.js
├─ import-contacts-apply.js
├─ contacts-preview.csv
├─ package.json
└─ README.md
```

## Fluxo resumido

```txt
npm run preview
revisar contacts-preview.csv
npm run import
digitar IMPORTAR
```

## Observações

Este script cria contatos reais no Outlook, mas não manipula diretamente o cache de AutoComplete.

Mesmo assim, contatos criados no Outlook podem ajudar o usuário a encontrar endereços ao começar a digitar destinatários.

## Erros comuns

### `invalid_client`

Verifique se o App Registration está com a opção abaixo habilitada:

```txt
Permitir fluxos de cliente público: Sim
```

### Erro de permissão

Confirme se o app possui as permissões delegadas:

```txt
User.Read
Mail.Read
Contacts.ReadWrite
```

### CSV não encontrado

Confirme se você executou antes:

```bash
npm run preview
```

E se está rodando os comandos na mesma pasta do projeto.

## Status

Projeto simples para uso manual e controlado em migrações pontuais de contatos para Microsoft 365.