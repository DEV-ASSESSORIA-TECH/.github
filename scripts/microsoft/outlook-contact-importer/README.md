# Instalador Outlook Contact Importer

Script `.bat` para baixar, configurar e executar o **Outlook Contact Importer** em máquinas Windows sem exigir instalação manual de Node.js ou npm.

O arquivo guia o usuário pelo processo de configuração, baixa os executáveis da release do GitHub, cria o arquivo `.env`, executa a geração do CSV de prévia e depois executa a importação dos contatos.

## Objetivo

Facilitar o uso do importador de contatos em máquinas de usuários comuns.

A pessoa precisa apenas executar o `.bat`. O script cuida de:

- Baixar os executáveis necessários
- Criar a pasta `data`
- Solicitar `TENANT_ID` e `CLIENT_ID`
- Criar o arquivo `.env`
- Executar o preview dos contatos
- Abrir o CSV para revisão
- Executar a importação após confirmação

## Requisitos

Antes de executar o `.bat`, é necessário ter um **App Registration** criado no Microsoft Entra ID.

O app deve ter as permissões delegadas:

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

Depois disso, o administrador deve conceder consentimento para o app.

## Arquivos baixados

O `.bat` baixa os executáveis da release mais recente do GitHub:

```txt
outlook-contacts-preview.exe
outlook-contacts-import.exe
```

Esses arquivos são baixados para a mesma pasta onde o `.bat` está sendo executado.

## Estrutura final esperada

Após a execução, a pasta ficará parecida com:

```txt
outlook-contact-importer/
├─ data/
│  └─ contacts-preview.csv
├─ .env
├─ outlook-contacts-preview.exe
├─ outlook-contacts-import.exe
└─ run-outlook-contact-importer.bat
```

## Como usar

Execute o arquivo:

```bat
run-outlook-contact-importer.bat
```

O script perguntará se o App Registration já foi criado e autorizado.

Depois, caso ainda não exista um `.env`, ele pedirá:

```txt
TENANT_ID
CLIENT_ID
```

Onde:

- `TENANT_ID` é o ID do diretório/locatário
- `CLIENT_ID` é o ID do aplicativo/cliente

## Fluxo de execução

O fluxo executado pelo `.bat` é:

```txt
1. Verifica se o App Registration já foi configurado
2. Cria a pasta data, se ela não existir
3. Baixa os executáveis da release do GitHub
4. Cria ou reutiliza o arquivo .env
5. Executa o preview
6. Gera data/contacts-preview.csv
7. Abre o CSV no Bloco de Notas
8. Aguarda revisão do usuário
9. Executa a importação
10. Finaliza o processo
```

## Preview dos contatos

Na primeira etapa, o script executa:

```txt
outlook-contacts-preview.exe
```

Esse executável lê mensagens da Caixa de Entrada e Itens Enviados da conta logada, extrai os contatos encontrados e gera:

```txt
data/contacts-preview.csv
```

Nenhum contato é criado nessa etapa.

## Revisão do CSV

Após o preview, o CSV será aberto automaticamente no Bloco de Notas.

Revise o arquivo antes de continuar.

Remova contatos indesejados, como:

```txt
no-reply
noreply
mailer-daemon
postmaster
notificações automáticas
sistemas
e-mails que não devem virar contato
```

## Importação dos contatos

Depois da revisão, o `.bat` pergunta se o usuário deseja continuar.

Se confirmado, ele executa:

```txt
outlook-contacts-import.exe
```

Dentro do importador, ainda será necessário digitar:

```txt
IMPORTAR
```

Essa confirmação evita criação acidental de contatos.

## Erros comuns

### Falha ao baixar executáveis

Verifique:

```txt
- Se a release existe no GitHub
- Se os assets têm os nomes corretos
- Se o repositório ou release está acessível
- Se a internet está funcionando
```

Assets esperados:

```txt
outlook-contacts-preview.exe
outlook-contacts-import.exe
```

### Erro no preview

Possíveis causas:

```txt
- TENANT_ID incorreto
- CLIENT_ID incorreto
- App Registration sem permissões corretas
- Consentimento de administrador não concedido
- Conta sem Exchange Online
- Problema de autenticação Microsoft
```

### Erro na importação

Possíveis causas:

```txt
- CSV inválido
- Permissão Contacts.ReadWrite ausente
- Consentimento de administrador ausente
- Conta sem permissão para criar contatos
- Erro de conexão com Microsoft Graph
```

### Arquivo .env incorreto

O `.env` deve seguir este formato:

```env
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

Sem aspas, sem espaços extras e sem ponto e vírgula.

## Observações

Este script não armazena senha do usuário.

A autenticação é feita pela Microsoft usando login via navegador/dispositivo.

O `.bat` apenas cria o arquivo `.env` com os IDs públicos necessários para identificar o App Registration.

## GitHub Release

Para o `.bat` funcionar corretamente, a release do GitHub precisa publicar os executáveis separadamente:

```txt
outlook-contacts-preview.exe
outlook-contacts-import.exe
```

O `.bat` usa a URL da release mais recente:

```txt
https://github.com/OWNER/REPO/releases/latest/download/NOME_DO_ARQUIVO.exe
```

Se o repositório for privado, o download direto pode falhar. Nesse caso, use links internos do SharePoint ou mantenha os executáveis em um local acessível pela rede.

## Status

Script auxiliar para distribuição simplificada do Outlook Contact Importer em ambientes Windows.
