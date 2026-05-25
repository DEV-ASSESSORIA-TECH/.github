@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "NODE_OPTIONS=--no-deprecation"
title Outlook Contact Importer

REM ============================================================
REM Configuracao dos downloads
REM ============================================================
set "GITHUB_OWNER=DEV-ASSESSORIA-TECH"
set "GITHUB_REPO=.github"
set "RELEASE_BASE_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/latest/download"

set "PREVIEW_EXE=outlook-contacts-preview.exe"
set "IMPORT_EXE=outlook-contacts-import.exe"

set "APP_DIR=%~dp0"
set "DATA_DIR=%APP_DIR%data"
set "ENV_FILE=%APP_DIR%.env"

set "PREVIEW_URL=%RELEASE_BASE_URL%/%PREVIEW_EXE%"
set "IMPORT_URL=%RELEASE_BASE_URL%/%IMPORT_EXE%"

cd /d "%APP_DIR%"

goto MAIN

REM ============================================================
REM Funcoes auxiliares
REM ============================================================

:LINE
echo ============================================================
exit /b 0

:HEADER
cls
call :LINE
echo  %~1
call :LINE
echo.
exit /b 0

:ERROR_PAUSE
echo.
echo ERRO: %~1
echo.
pause
exit /b 1

:LOAD_ENV_FILE
set "TENANT_ID="
set "CLIENT_ID="

if not exist "%ENV_FILE%" (
  echo ERRO: Arquivo .env nao encontrado.
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  if /I "%%A"=="TENANT_ID" set "TENANT_ID=%%B"
  if /I "%%A"=="CLIENT_ID" set "CLIENT_ID=%%B"
)

set "TENANT_ID=%TENANT_ID: =%"
set "CLIENT_ID=%CLIENT_ID: =%"

exit /b 0

:VALIDATE_GUID_VALUE
set "GUID_VAR=%~1"
set "GUID_LABEL=%~2"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$v=[Environment]::GetEnvironmentVariable('%GUID_VAR%','Process'); if ($v -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { exit 0 } else { exit 1 }" >nul 2>&1

if errorlevel 1 (
  echo ERRO: %GUID_LABEL% nao parece ser um GUID valido.
  echo Valor informado: !%GUID_VAR%!
  echo.
  exit /b 1
)

exit /b 0

:VALIDATE_ENV_IDS
if "%TENANT_ID%"=="" (
  echo ERRO: TENANT_ID nao informado.
  echo.
  exit /b 1
)

if "%CLIENT_ID%"=="" (
  echo ERRO: CLIENT_ID nao informado.
  echo.
  exit /b 1
)

call :VALIDATE_GUID_VALUE "TENANT_ID" "TENANT_ID"
if errorlevel 1 exit /b 1

call :VALIDATE_GUID_VALUE "CLIENT_ID" "CLIENT_ID"
if errorlevel 1 exit /b 1

exit /b 0

:SHOW_ENV_SUMMARY
echo TENANT_ID atual:
echo  !TENANT_ID:~0,8!...!TENANT_ID:~-4!  ^(Directory / tenant ID / locatario^)
echo CLIENT_ID atual:
echo  !CLIENT_ID:~0,8!...!CLIENT_ID:~-4!  ^(Application / client ID / aplicativo^)
echo.
exit /b 0

:DOWNLOAD_FILE
set "DOWNLOAD_URL=%~1"
set "DOWNLOAD_OUTPUT=%~2"
set "DOWNLOAD_NAME=%~3"

echo Baixando %DOWNLOAD_NAME%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%DOWNLOAD_OUTPUT%' -UseBasicParsing } catch { exit 1 }"

if errorlevel 1 (
  echo.
  echo ERRO: Nao foi possivel baixar %DOWNLOAD_NAME%.
  echo.
  echo Verifique:
  echo  - Se a internet esta funcionando
  echo  - Se o GitHub esta acessivel
  echo  - Se a release existe
  echo  - Se o asset tem exatamente este nome: %DOWNLOAD_NAME%
  echo  - Se o repositorio/release esta publico ou acessivel
  echo.
  echo URL usada:
  echo %DOWNLOAD_URL%
  echo.
  pause
  exit /b 1
)

exit /b 0

:PREPARE_FOLDERS
call :HEADER "Preparando pastas"

if not exist "%DATA_DIR%" (
  mkdir "%DATA_DIR%"
  if errorlevel 1 (
    call :ERROR_PAUSE "Nao foi possivel criar a pasta data."
    exit /b 1
  )
)

echo Pasta de trabalho:
echo "%APP_DIR%"
echo.
exit /b 0

:CHECK_DOWNLOADS
call :HEADER "Verificando executaveis"

if not exist "%APP_DIR%%PREVIEW_EXE%" (
  call :DOWNLOAD_FILE "%PREVIEW_URL%" "%APP_DIR%%PREVIEW_EXE%" "%PREVIEW_EXE%"
  if errorlevel 1 exit /b 1
) else (
  echo %PREVIEW_EXE% ja existe. Pulando download.
)

if not exist "%APP_DIR%%IMPORT_EXE%" (
  call :DOWNLOAD_FILE "%IMPORT_URL%" "%APP_DIR%%IMPORT_EXE%" "%IMPORT_EXE%"
  if errorlevel 1 exit /b 1
) else (
  echo %IMPORT_EXE% ja existe. Pulando download.
)

echo.
echo Executaveis prontos.
echo.
exit /b 0

:CONFIGURE_ENV
call :HEADER "Configuracao do App Registration"

if exist "%ENV_FILE%" (
  echo Arquivo .env encontrado.
  echo.

  call :LOAD_ENV_FILE
  if errorlevel 1 (
    echo O arquivo .env existe, mas nao foi possivel ler TENANT_ID e CLIENT_ID.
    echo.
    choice /C SN /M "Deseja recriar este .env"
    if errorlevel 2 exit /b 1
    del /f /q "%ENV_FILE%" >nul 2>&1
    goto CONFIGURE_ENV_INPUT
  )

  call :VALIDATE_ENV_IDS
  if errorlevel 1 (
    echo O arquivo .env existe, mas contem dados invalidos.
    echo.
    choice /C SN /M "Deseja recriar este .env"
    if errorlevel 2 exit /b 1
    del /f /q "%ENV_FILE%" >nul 2>&1
    goto CONFIGURE_ENV_INPUT
  )

  call :SHOW_ENV_SUMMARY

  choice /C SN /M "Deseja reutilizar este .env"
  if errorlevel 2 (
    del /f /q "%ENV_FILE%" >nul 2>&1
    echo.
    echo .env removido. Sera necessario informar os dados novamente.
    echo.
  ) else (
    echo.
    echo .env mantido.
    echo.
    exit /b 0
  )
)

:CONFIGURE_ENV_INPUT
echo Informe os dados do App Registration.
echo.
echo TENANT_ID = ID do diretorio/locatario
echo CLIENT_ID = ID do aplicativo/cliente
echo.
echo Dica:
echo Esses dados ficam em Entra ID ^> Registros de aplicativo ^> App ^> Visao geral.
echo.

set "TENANT_ID="
set "CLIENT_ID="

set /p "TENANT_ID=Digite o TENANT_ID: "
set /p "CLIENT_ID=Digite o CLIENT_ID: "

set "TENANT_ID=%TENANT_ID: =%"
set "CLIENT_ID=%CLIENT_ID: =%"

call :VALIDATE_ENV_IDS
if errorlevel 1 (
  echo Dica: TENANT_ID e CLIENT_ID sao dois GUIDs diferentes.
  echo TENANT_ID fica em Directory ^(tenant^) ID.
  echo CLIENT_ID fica em Application ^(client^) ID.
  echo.
  pause
  exit /b 1
)

(
  echo TENANT_ID=%TENANT_ID%
  echo CLIENT_ID=%CLIENT_ID%
) > "%ENV_FILE%"

if errorlevel 1 (
  call :ERROR_PAUSE "Nao foi possivel criar o arquivo .env."
  exit /b 1
)

echo.
echo Arquivo .env criado com sucesso.
echo.
call :SHOW_ENV_SUMMARY
echo.
exit /b 0

:SHOW_APP_REGISTRATION_HELP
call :HEADER "Antes de continuar"

echo Para usar este importador, o cliente precisa ter um App Registration
echo criado e autorizado no Microsoft Entra ID.
echo.
echo Configuracao necessaria:
echo.
echo  1. Criar App Registration no Entra ID
echo  2. Adicionar permissoes delegadas:
echo     - User.Read
echo     - Mail.Read
echo     - Contacts.ReadWrite
echo.
echo  3. Em Autenticacao, ativar:
echo     - Permitir fluxos de cliente publico
echo.
echo  4. Em Permissoes de API, clicar em:
echo     - Conceder consentimento do administrador
echo.
echo O processo usa login individual.
echo Os contatos serao criados na conta Microsoft 365 que fizer login.
echo.
choice /C SN /M "O App Registration ja foi criado e autorizado"
if errorlevel 2 (
  echo.
  echo Configure o App Registration primeiro e execute este BAT novamente.
  echo.
  pause
  exit /b 1
)
exit /b 0

:RUN_PREVIEW
call :HEADER "Etapa 1 - Gerar preview dos contatos"

echo Nesta etapa o programa vai ler a Caixa de Entrada e os Itens Enviados
echo da conta Microsoft 365 que fizer login.
echo.
echo Nenhum contato sera criado nesta etapa.
echo.
echo Ao final, sera gerado o arquivo:
echo.
echo data\contacts-preview.csv
echo.
echo Importante:
echo O login sera feito pela Microsoft. O script nao solicita e nao salva senha.
echo.

choice /C SN /M "Deseja executar o preview agora"
if errorlevel 2 (
  echo.
  echo Processo interrompido antes do preview.
  echo.
  pause
  exit /b 1
)

call :HEADER "Login Microsoft"

echo Na proxima etapa, o programa vai exibir um link e um codigo.
echo.
echo Faca o seguinte:
echo.
echo  1. Abra o link informado pela Microsoft
echo  2. Digite o codigo exibido no terminal
echo  3. Entre com a conta Microsoft 365 que tera os contatos importados
echo.
echo Atencao:
echo Os contatos serao gerados para a conta que fizer login.
echo.
echo Se aparecer erro de autenticacao, confira primeiro se:
echo  - TENANT_ID = Directory ^(tenant^) ID / locatario
echo  - CLIENT_ID = Application ^(client^) ID / aplicativo
echo.

"%APP_DIR%%PREVIEW_EXE%"

if errorlevel 1 (
  echo.
  echo ERRO: O preview falhou.
  echo.
  echo Possiveis causas:
  echo  - TENANT_ID ou CLIENT_ID incorreto
  echo  - TENANT_ID e CLIENT_ID invertidos no .env
  echo  - App Registration sem permissoes corretas
  echo  - Falta de consentimento de administrador
  echo  - Fluxo de cliente publico nao habilitado
  echo  - Device Code Flow bloqueado por Conditional Access
  echo  - Conta sem caixa Exchange Online
  echo  - Erro de conexao com a Microsoft
  echo.
  echo Confira a mensagem exibida acima e tente novamente.
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

exit /b 0

:REVIEW_CSV
call :HEADER "Revisao do CSV"

echo O arquivo de preview sera aberto no Bloco de Notas.
echo.
echo Antes de continuar para a importacao, revise o arquivo e remova
echo contatos indesejados, como:
echo.
echo  - no-reply
echo  - noreply
echo  - mailer-daemon
echo  - postmaster
echo  - notificacoes automaticas
echo  - sistemas
echo  - emails invalidos
echo  - emails que nao devem virar contato
echo.
echo IMPORTANTE:
echo O fluxo ficara pausado enquanto o Bloco de Notas estiver aberto.
echo.
echo Revise o CSV, salve o arquivo e feche o Bloco de Notas para continuar.
echo.
pause

echo.
echo Abrindo data\contacts-preview.csv para revisao...
echo.
start /wait notepad "%DATA_DIR%\contacts-preview.csv"

echo.
echo Bloco de Notas fechado.
echo.

choice /C SN /M "Depois de revisar e salvar o CSV, deseja continuar para a importacao"
if errorlevel 2 (
  echo.
  echo Importacao cancelada pelo usuario.
  echo O CSV ficou salvo em:
  echo "%DATA_DIR%\contacts-preview.csv"
  echo.
  pause
  exit /b 1
)

exit /b 0

:RUN_IMPORT
call :HEADER "Etapa 2 - Importar contatos"

echo Agora o importador vai ler o CSV revisado e comparar com os contatos
echo ja existentes no Outlook.
echo.
echo Ele mostrara um resumo antes de criar qualquer contato.
echo.
echo Para confirmar dentro do importador, sera necessario digitar:
echo.
echo IMPORTAR
echo.
echo Se voce digitar qualquer outra coisa, nada sera criado.
echo.

choice /C SN /M "Deseja abrir o importador agora"
if errorlevel 2 (
  echo.
  echo Importacao cancelada antes da execucao.
  echo.
  pause
  exit /b 1
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
  echo Confira a mensagem exibida acima.
  echo.
  pause
  exit /b 1
)

call :HEADER "Importacao finalizada"

echo Se contatos foram criados, confira no Outlook em:
echo.
echo  Outlook Web ^> Pessoas ^> Contatos
echo.
echo ou pesquise algum email importado.
echo.
exit /b 0

:RUN_ONE_ACCOUNT
call :PREPARE_FOLDERS
if errorlevel 1 exit /b 1

call :CHECK_DOWNLOADS
if errorlevel 1 exit /b 1

call :CONFIGURE_ENV
if errorlevel 1 exit /b 1

call :RUN_PREVIEW
if errorlevel 1 exit /b 1

call :REVIEW_CSV
if errorlevel 1 exit /b 1

call :RUN_IMPORT
if errorlevel 1 exit /b 1

exit /b 0

:CLEANUP
call :HEADER "Limpeza final"

echo Por seguranca, e recomendado apagar pelo menos o arquivo .env,
echo pois ele contem os IDs usados para autenticar o aplicativo.
echo.
echo Tambem e recomendado apagar os executaveis baixados, caso este BAT
echo tenha sido usado apenas para uma importacao pontual.
echo.
echo Arquivos que podem ser apagados:
echo.
echo  - .env
echo  - %PREVIEW_EXE%
echo  - %IMPORT_EXE%
echo.
echo O CSV em data\contacts-preview.csv nao sera apagado automaticamente.
echo Ele pode ser util como evidencia ou conferencia do que foi importado.
echo.

choice /C SN /M "Deseja apagar .env e os executaveis agora"
if errorlevel 2 (
  echo.
  echo Limpeza ignorada.
  echo.
  echo Recomendacao: apague manualmente o arquivo .env quando nao precisar mais dele.
  echo.
  pause
  exit /b 0
)

echo.
echo Apagando arquivos...
echo.

if exist "%ENV_FILE%" (
  del /f /q "%ENV_FILE%" >nul 2>&1
  if exist "%ENV_FILE%" (
    echo Nao foi possivel apagar .env
  ) else (
    echo .env apagado.
  )
) else (
  echo .env nao encontrado.
)

if exist "%APP_DIR%%PREVIEW_EXE%" (
  del /f /q "%APP_DIR%%PREVIEW_EXE%" >nul 2>&1
  if exist "%APP_DIR%%PREVIEW_EXE%" (
    echo Nao foi possivel apagar %PREVIEW_EXE%
  ) else (
    echo %PREVIEW_EXE% apagado.
  )
) else (
  echo %PREVIEW_EXE% nao encontrado.
)

if exist "%APP_DIR%%IMPORT_EXE%" (
  del /f /q "%APP_DIR%%IMPORT_EXE%" >nul 2>&1
  if exist "%APP_DIR%%IMPORT_EXE%" (
    echo Nao foi possivel apagar %IMPORT_EXE%
  ) else (
    echo %IMPORT_EXE% apagado.
  )
) else (
  echo %IMPORT_EXE% nao encontrado.
)

echo.
choice /C SN /M "Deseja tentar apagar tambem este arquivo BAT"
if errorlevel 2 (
  echo.
  echo BAT mantido.
  echo.
  pause
  exit /b 0
)

echo.
echo O BAT tentara se autoapagar apos o fechamento desta janela.
echo Se o Windows bloquear a exclusao, apague manualmente depois.
echo.
pause

set "SELF_PATH=%~f0"

start "" /b cmd /c "timeout /t 2 /nobreak >nul & del /f /q "%SELF_PATH%" >nul 2>&1"

exit /b 0

REM ============================================================
REM Fluxo principal
REM ============================================================

:MAIN
call :HEADER "Outlook Contact Importer"

echo Este assistente vai:
echo.
echo  1. Baixar os executaveis da release do GitHub
echo  2. Criar ou reutilizar o arquivo .env com TENANT_ID e CLIENT_ID
echo  3. Gerar o CSV de preview dos contatos
echo  4. Abrir o CSV para revisao
echo  5. Executar a importacao dos contatos
echo  6. Perguntar se deseja processar outra conta
echo  7. Oferecer limpeza dos arquivos ao final
echo.
echo Recomendacao:
echo Execute este BAT em uma pasta vazia.
echo.

call :SHOW_APP_REGISTRATION_HELP
if errorlevel 1 exit /b 1

:ACCOUNT_LOOP
call :HEADER "Inicio do ciclo de importacao"

call :RUN_ONE_ACCOUNT

if errorlevel 1 (
  echo.
  echo O ciclo atual foi interrompido ou falhou.
  echo.
  choice /C SN /M "Deseja tentar novamente"
  if errorlevel 2 goto END_FLOW
  goto ACCOUNT_LOOP
)

echo.
call :HEADER "Conta processada"

choice /C SN /M "Deseja fazer o mesmo processo para outra conta"
if errorlevel 2 goto END_FLOW

echo.
choice /C SN /M "A proxima conta usa o mesmo tenant e o mesmo App Registration"
if errorlevel 2 (
  echo.
  echo A proxima conta NAO usa o mesmo tenant/app.
  echo O arquivo .env atual sera apagado para evitar uso incorreto.
  echo.
  if exist "%ENV_FILE%" del /f /q "%ENV_FILE%" >nul 2>&1
  pause
) else (
  echo.
  echo O mesmo .env sera reutilizado.
  echo Na proxima execucao, faca login com a outra conta Microsoft 365.
  echo.
  pause
)

goto ACCOUNT_LOOP

:END_FLOW
call :HEADER "Fim do processo"

echo Nao ha mais contas para processar.
echo.

call :CLEANUP

exit /b 0
