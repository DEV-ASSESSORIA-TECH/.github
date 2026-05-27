# Outlook Contact Importer

Importador assistido para reconstruir contatos do Outlook/Microsoft 365 a partir de e-mails já existentes na caixa do usuário.

A ideia é simples: o programa lê mensagens da **Caixa de Entrada** e dos **Itens Enviados**, encontra remetentes e destinatários, remove duplicados, gera um CSV para revisão e só cria contatos depois de uma confirmação manual.

## Visão geral

Este projeto foi feito para migrações pontuais em que os e-mails chegaram ao Microsoft 365, mas a agenda de contatos não veio junto. Ele ajuda a montar uma primeira lista de contatos reais usando o histórico de mensagens da própria conta.

O fluxo seguro é sempre em duas etapas:

| Etapa | O que acontece | Cria contatos? |
| --- | --- | --- |
| Preview | Lê e-mails e gera `data/contacts-preview.csv` | Não |
| Importação | Lê o CSV revisado e cria contatos faltantes | Sim, após confirmação |

> O login é feito pela Microsoft usando Device Code. O script não pede, não salva e não recebe a senha do usuário.

## Uso recomendado: pelo BAT

Para quem só precisa executar a importação, use o arquivo:

```txt
run-outlook-contact-importer.bat
```

Ele guia o processo inteiro no Windows, sem precisar instalar Node.js, npm ou abrir terminal manualmente.

### Antes de começar

Você precisa ter:

- Windows com acesso à internet
- Uma conta Microsoft 365 com caixa Exchange Online
- O arquivo `run-outlook-contact-importer.bat`
- Um App Registration criado e autorizado no Microsoft Entra ID
- Dois IDs do App Registration:
  - `TENANT_ID`: Directory/tenant ID, ou ID do diretório/locatário
  - `CLIENT_ID`: Application/client ID, ou ID do aplicativo/cliente

Se você não sabe onde encontrar `TENANT_ID` e `CLIENT_ID`, peça ao responsável técnico. Eles ficam no Microsoft Entra ID, dentro do registro do aplicativo, na tela **Visão geral**.

### Como executar

1. Crie uma pasta vazia no computador.
2. Coloque `run-outlook-contact-importer.bat` dentro dessa pasta.
3. Dê dois cliques no BAT.
4. Confirme que o App Registration já foi criado e autorizado.
5. Informe `TENANT_ID` e `CLIENT_ID` quando o assistente pedir.
6. Siga o link e o código exibidos pela Microsoft para fazer login.
7. Aguarde a geração do arquivo `data\contacts-preview.csv`.
8. Revise o CSV no Bloco de Notas, salve e feche.
9. Confirme a importação quando estiver tudo certo.

Durante a importação, o programa mostra um resumo e pede que você digite exatamente:

```txt
IMPORTAR
```

Se qualquer outra coisa for digitada, nenhum contato será criado.

### O que o BAT faz automaticamente

- Baixa os executáveis mais recentes da release do GitHub
- Cria a pasta `data`
- Cria ou reutiliza o arquivo `.env`
- Valida se `TENANT_ID` e `CLIENT_ID` parecem GUIDs válidos
- Executa o preview dos contatos
- Abre o CSV para revisão no Bloco de Notas
- Executa a importação
- Permite processar outra conta
- Oferece limpeza do `.env` e dos executáveis ao final

### Como revisar o CSV

O arquivo gerado fica em:

```txt
data\contacts-preview.csv
```

Ele tem as colunas:

```txt
name,email,sources
```

Na revisão, normalmente você deve remover linhas como:

- `no-reply`, `noreply`, `mailer-daemon` e `postmaster`
- notificações automáticas
- sistemas internos
- endereços inválidos
- contatos que não devem entrar na agenda

Mantenha a primeira linha do arquivo, com o cabeçalho `name,email,sources`. Para remover um contato, apague a linha inteira dele.

### Depois da importação

Os contatos criados podem ser conferidos em:

```txt
Outlook Web > Pessoas > Contatos
```

Ao final, o BAT pergunta se você deseja apagar `.env` e os executáveis baixados. É recomendado apagar o `.env` quando o processo terminar, principalmente em computadores compartilhados.

## Configuração do App Registration

O aplicativo no Microsoft Entra ID precisa ter permissões delegadas do Microsoft Graph:

```txt
User.Read
Mail.Read
Contacts.ReadWrite
```

Também é necessário ativar:

```txt
Permitir fluxos de cliente público
```

ou, em inglês:

```txt
Allow public client flows
```

Depois de adicionar as permissões, conceda o consentimento de administrador para o aplicativo.

## Limitações importantes

- Não acessa o cache interno de AutoComplete do Outlook.
- Cria contatos reais no Outlook, mas não garante sugestões imediatas no autocomplete.
- Não remove contatos existentes.
- Não atualiza contatos existentes.
- Não importa fotos de contatos.
- Não sincroniza contatos continuamente.
- Não processa múltiplas caixas automaticamente sem interação.
- No preview, o script lê até 200 mensagens da Caixa de Entrada e até 200 dos Itens Enviados.

## Erros comuns

### `invalid_client`

Verifique se `TENANT_ID` e `CLIENT_ID` estão corretos e se não foram invertidos. Confirme também se o App Registration permite fluxo de cliente público.

### Permissão negada

Confirme se o App Registration tem as permissões `User.Read`, `Mail.Read` e `Contacts.ReadWrite`, e se o consentimento de administrador foi concedido.

### CSV não encontrado

Execute primeiro o preview. O arquivo esperado é:

```txt
data\contacts-preview.csv
```

### O BAT não consegue baixar os executáveis

Confira a internet, o acesso ao GitHub e se a release mais recente contém estes arquivos:

```txt
outlook-contacts-preview.exe
outlook-contacts-import.exe
```

## Para desenvolvedores

Esta seção é para manutenção do projeto, execução local com Node.js e geração dos executáveis usados pelo BAT.

### Estrutura

```txt
outlook-contact-importer/
├─ data/
│  └─ output-example.csv
├─ import-contacts-preview.js
├─ import-contacts-apply.js
├─ run-outlook-contact-importer.bat
├─ package.json
├─ package-lock.json
└─ README.md
```

### Requisitos

- Node.js 22 ou superior
- npm
- Conta Microsoft 365 com Exchange Online
- App Registration no Microsoft Entra ID

### Configuração local

Crie um arquivo `.env` na raiz do projeto:

```env
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

Instale as dependências:

```bash
npm install
```

### Rodar em modo desenvolvimento

Gerar o CSV de preview:

```bash
npm run preview
```

Importar contatos a partir do CSV revisado:

```bash
npm run import
```

### Scripts disponíveis

```json
{
  "preview": "node import-contacts-preview.js",
  "import": "node import-contacts-apply.js",
  "build:preview": "pkg import-contacts-preview.js --targets node22-win-x64 --fallback-to-source --output dist/outlook-contacts-preview.exe",
  "build:import": "pkg import-contacts-apply.js --targets node22-win-x64 --fallback-to-source --output dist/outlook-contacts-import.exe",
  "build": "npm run build:preview && npm run build:import"
}
```

### Gerar executáveis

```bash
npm run build
```

Saída esperada:

```txt
dist/
├─ outlook-contacts-preview.exe
└─ outlook-contacts-import.exe
```

Para o BAT funcionar em máquinas sem Node.js, publique esses dois executáveis como assets da release mais recente do GitHub.

### Arquivos que não devem ser versionados

```txt
node_modules/
dist/
release/
.env
data/contacts-preview.csv
```

### Observações técnicas

- `import-contacts-preview.js` usa Microsoft Graph para ler `Inbox` e `SentItems`.
- `import-contacts-apply.js` lê `data/contacts-preview.csv`, compara com contatos existentes e cria apenas os que ainda não existem.
- O CSV precisa ter pelo menos as colunas `name` e `email`.
- A coluna `sources` é útil para auditoria, mas não é obrigatória na importação.
- Domínios e prefixos ignorados no preview ficam definidos no próprio script.

## Status

Ferramenta utilitária para migrações pontuais de contatos para Microsoft 365, com execução assistida, revisão manual e confirmação explícita antes de criar contatos.
