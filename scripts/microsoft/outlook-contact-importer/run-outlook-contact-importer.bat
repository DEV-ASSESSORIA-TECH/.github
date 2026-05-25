@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Outlook Contact Importer

REM ============================================================
REM Configuracao dos downloads
REM ============================================================
REM Para release "latest":
set "GITHUB_OWNER=DEV-ASSESSORIA-TECH"
set "GITHUB_REPO=.github"
set "RELEASE_BASE_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/latest/download"

REM Nomes dos arquivos anexados na release do GitHub
set "PREVIEW_EXE=outlook-contacts-preview.exe"
set "IMPORT_EXE=outlook-contacts-import.exe"

REM Pasta onde o .bat esta sendo executado
set "APP_DIR=%~dp0"
set "DATA_DIR=%APP_DIR%data"
set "ENV_FILE=%APP_DIR%.env"

REM URLs finais dos arquivos
set "PREVIEW_URL=%RELEASE_BASE_URL%/%PREVIEW_EXE%"
set "IMPORT_URL=%RELEASE_BASE_URL%/%IMPORT_EXE%"

cd /d "%APP_DIR%"

echo ============================================================
echo  Outlook Contact Importer
echo ============================================================
echo.
echo Este assistente vai:
echo.
echo  1. Baixar os executaveis da release do GitHub
echo  2. Criar o arquivo .env com TENANT_ID e CLIENT_ID
echo  3. Gerar o CSV de preview dos contatos
echo  4. Abrir o CSV para revisao
echo  5. Executar a importacao dos contatos
echo.
echo IMPORTANTE:
echo Antes de continuar, tenha um App Registration criado no Microsoft Entra.
echo.
echo Permissoes delegadas necessarias:
echo  - User.Read
echo  - Mail.Read
echo  - Contacts.ReadWrite
echo.
echo Tambem ative:
echo  - Permitir fluxos de cliente publico
echo.
echo Depois conceda consentimento de administrador para o app.
echo.

choice /C SN /M "O App Registration ja foi criado e autorizado"
if errorlevel 2 (
  echo.
  echo Configure o App Registration primeiro e execute este arquivo novamente.
  echo.
  pause
  exit /b 0
)

echo.
echo ============================================================
echo  Preparando pastas
echo ============================================================
echo.

if not exist "%DATA_DIR%" (
  mkdir "%DATA_DIR%"
  if errorlevel 1 (
    echo ERRO: Nao foi possivel criar a pasta data.
    echo Pasta: "%DATA_DIR%"
    echo.
    pause
    exit /b 1
  )
)

echo Pasta de trabalho:
echo "%APP_DIR%"
echo.

REM ============================================================
REM Funcao simples de download via PowerShell
REM ============================================================

echo ============================================================
echo  Verificando executaveis
echo ============================================================
echo.

if not exist "%APP_DIR%%PREVIEW_EXE%" (
  echo Baixando %PREVIEW_EXE%...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%PREVIEW_URL%' -OutFile '%APP_DIR%%PREVIEW_EXE%' -UseBasicParsing } catch { exit 1 }"

  if errorlevel 1 (
    echo.
    echo ERRO: Nao foi possivel baixar %PREVIEW_EXE%.
    echo.
    echo Verifique:
    echo  - Se a release existe no GitHub
    echo  - Se o asset tem exatamente este nome: %PREVIEW_EXE%
    echo  - Se o repositorio/release esta publico ou acessivel
    echo  - Se a internet esta funcionando
    echo.
    echo URL usada:
    echo %PREVIEW_URL%
    echo.
    pause
    exit /b 1
  )
) else (
  echo %PREVIEW_EXE% ja existe. Pulando download.
)

if not exist "%APP_DIR%%IMPORT_EXE%" (
  echo Baixando %IMPORT_EXE%...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%IMPORT_URL%' -OutFile '%APP_DIR%%IMPORT_EXE%' -UseBasicParsing } catch { exit 1 }"

  if errorlevel 1 (
    echo.
    echo ERRO: Nao foi possivel baixar %IMPORT_EXE%.
    echo.
    echo Verifique:
    echo  - Se a release existe no GitHub
    echo  - Se o asset tem exatamente este nome: %IMPORT_EXE%
    echo  - Se o repositorio/release esta publico ou acessivel
    echo  - Se a internet esta funcionando
    echo.
    echo URL usada:
    echo %IMPORT_URL%
    echo.
    pause
    exit /b 1
  )
) else (
  echo %IMPORT_EXE% ja existe. Pulando download.
)

echo.
echo Executaveis prontos.
echo.

REM ============================================================
REM Configuracao do .env
REM ============================================================

echo ============================================================
echo  Configuracao do .env
echo ============================================================
echo.

if exist "%ENV_FILE%" (
  echo Arquivo .env encontrado.
  echo.

  choice /C SN /M "Deseja recriar o arquivo .env"
  if errorlevel 2 goto ENV_OK
)

echo.
echo Informe os dados do App Registration.
echo.
echo TENANT_ID = ID do diretorio/locatario
echo CLIENT_ID = ID do aplicativo/cliente
echo.

set "TENANT_ID="
set "CLIENT_ID="

set /p "TENANT_ID=Digite o TENANT_ID: "
set /p "CLIENT_ID=Digite o CLIENT_ID: "

if "%TENANT_ID%"=="" (
  echo.
  echo ERRO: TENANT_ID nao informado.
  pause
  exit /b 1
)

if "%CLIENT_ID%"=="" (
  echo.
  echo ERRO: CLIENT_ID nao informado.
  pause
  exit /b 1
)

(
  echo TENANT_ID=%TENANT_ID%
  echo CLIENT_ID=%CLIENT_ID%
) > "%ENV_FILE%"

if errorlevel 1 (
  echo.
  echo ERRO: Nao foi possivel criar o arquivo .env.
  echo.
  pause
  exit /b 1
)

echo.
echo Arquivo .env criado com sucesso.
echo.

:ENV_OK

REM ============================================================
REM Preview
REM ============================================================

echo ============================================================
echo  Etapa 1 - Gerar preview dos contatos
echo ============================================================
echo.
echo O programa vai solicitar login Microsoft pelo navegador.
echo Depois do login, sera gerado:
echo.
echo data\contacts-preview.csv
echo.
echo Nenhum contato sera criado nesta etapa.
echo.

choice /C SN /M "Deseja executar o preview agora"
if errorlevel 2 (
  echo.
  echo Processo interrompido antes do preview.
  pause
  exit /b 0
)

"%APP_DIR%%PREVIEW_EXE%"

if errorlevel 1 (
  echo.
  echo ERRO: O preview falhou.
  echo.
  echo Possiveis causas:
  echo  - TENANT_ID ou CLIENT_ID incorreto
  echo  - App Registration sem permissoes corretas
  echo  - Falta de consentimento de administrador
  echo  - Conta sem caixa Exchange Online
  echo  - Erro de conexao com a Microsoft
  echo.
  echo Confira o erro exibido acima e tente novamente.
  echo.
  pause
  exit /b 1
)

echo.
echo Preview finalizado com sucesso.
echo.

if not exist "%DATA_DIR%\contacts-preview.csv" (
  echo ERRO: O arquivo data\contacts-preview.csv nao foi encontrado.
  echo.
  echo O preview pode ter finalizado sem gerar o CSV.
  echo Confira as mensagens acima.
  echo.
  pause
  exit /b 1
)

echo Abrindo CSV para revisao...
notepad "%DATA_DIR%\contacts-preview.csv"

echo.
echo Revise o CSV antes de continuar.
echo Remova contatos indesejados, como:
echo.
echo  - no-reply
echo  - noreply
echo  - mailer-daemon
echo  - notificacoes automaticas
echo  - sistemas
echo  - emails que nao devem virar contato
echo.

choice /C SN /M "Depois de revisar e salvar o CSV, deseja continuar para a importacao"
if errorlevel 2 (
  echo.
  echo Importacao cancelada pelo usuario.
  echo O CSV ficou salvo em:
  echo "%DATA_DIR%\contacts-preview.csv"
  echo.
  pause
  exit /b 0
)

REM ============================================================
REM Importacao
REM ============================================================

echo.
echo ============================================================
echo  Etapa 2 - Importar contatos
echo ============================================================
echo.
echo O importador vai ler o CSV revisado e consultar contatos existentes.
echo.
echo Dentro do importador, ainda sera necessario digitar:
echo.
echo IMPORTAR
echo.
echo Isso evita criacao acidental de contatos.
echo.

choice /C SN /M "Deseja abrir o importador agora"
if errorlevel 2 (
  echo.
  echo Importacao cancelada antes da execucao.
  pause
  exit /b 0
)

"%APP_DIR%%IMPORT_EXE%"

if errorlevel 1 (
  echo.
  echo ERRO: A importacao falhou.
  echo.
  echo Possiveis causas:
  echo  - CSV invalido ou mal formatado
  echo  - Permissao Contacts.ReadWrite ausente
  echo  - Consentimento de administrador ausente
  echo  - Conta sem permissao para criar contatos
  echo  - Erro de conexao com a Microsoft
  echo.
  echo Confira o erro exibido acima.
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo  Processo finalizado
echo ============================================================
echo.
echo Se contatos foram criados, confira no Outlook em:
echo.
echo  Outlook Web ^> Pessoas ^> Contatos
echo.
echo ou pesquise algum email importado.
echo.
pause
exit /b 0