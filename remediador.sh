#!/bin/bash

# ==============================================================================
# WP-REMEDIATOR AGENT v2.1 (CORRIGIDO)
# ==============================================================================

WP_ROOT=$(pwd)

C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_CYAN='\033[1;36m'
C_BOLD='\033[1m'

clear
echo -e "${C_CYAN}"
echo "  ██████╗ ███████╗███╗   ███╗███████╗██████╗ ██╗██████╗  ██████╗ ██╗"
echo "  ██╔══██╗██╔════╝████╗ ████║██╔════╝██╔══██╗██║██╔══██╗██╔═══██╗██║"
echo "  ██████╔╝█████╗  ██╔████╔██║█████╗  ██║  ██║██║██║  ██║██║   ██║██║"
echo "  ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔══╝  ██║  ██║██║██║  ██║██║   ██║╚═╝"
echo "  ██║  ██║███████╗██║ ╚═╝ ██║███████╗██████╔╝██║██████╔╝╚██████╔╝██╗"
echo "  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═════╝  ╚═════╝ ╚═╝"
echo -e "         AGENTE REMEDIADOR E AUTOCORREÇÃO - WORDPRESS v2.1${C_RESET}"
echo -e "${C_BLUE}=================================================================${C_RESET}"

ULTIMO_RELATORIO=$(ls -t relatorio_seguranca_*.txt 2>/dev/null | head -n 1)

if [ -z "$ULTIMO_RELATORIO" ]; then
    echo -e "${C_RED}[ERRO] Nenhum relatório de segurança encontrado!${C_RESET}"
    echo -e "Execute o './scanner.sh' primeiro para gerar uma auditoria.\n"
    exit 1
fi

echo -e " Relatório Alvo : ${C_BOLD}${ULTIMO_RELATORIO}${C_RESET}"
echo -e "${C_BLUE}=================================================================${C_RESET}\n"

read -p "Deseja iniciar as correções automáticas baseadas neste relatório? (s/n): " CONFIRMA
if [[ "$CONFIRMA" != "s" && "$CONFIRMA" != "S" ]]; then
    echo -e "\n${C_YELLOW}[!] Operação cancelada pelo usuário.${C_RESET}\n"
    exit 0
fi

echo -e "\n${C_YELLOW}[+] Aplicando correções no ambiente...${C_RESET}\n"

CORRECOES_REALIZADAS=0

# ------------------------------------------------------------------------------
# 1. REMOÇÃO DE ARQUIVOS OCULTOS DESNECESSÁRIOS E TEMPORÁRIOS
# ------------------------------------------------------------------------------
if grep -qi "Arquivos ocultos encontrados" "$ULTIMO_RELATORIO" || grep -qi "\.DS_Store" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 1/6] Removendo arquivos ocultos e temporários desnecessários...${C_RESET}"
    find . -name ".DS_Store" -type f -delete 2>/dev/null
    find . -maxdepth 2 -name ".*" ! -name "." ! -name ".." ! -name ".htaccess" ! -name ".user.ini" ! -name ".git*" -delete 2>/dev/null
    echo -e "  ${C_GREEN}✓ Arquivos ocultos não essenciais removidos${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

# ------------------------------------------------------------------------------
# 2. CORREÇÃO DE PERMISSÕES NO WP-CONFIG.PHP E DIRETÓRIOS 777
# ------------------------------------------------------------------------------
if grep -qi "Permissão insegura no wp-config.php" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 2/6] Corrigindo permissões do wp-config.php...${C_RESET}"
    chmod 640 wp-config.php 2>/dev/null
    echo -e "  ${C_GREEN}✓ Alterado: 'wp-config.php' -> CHMOD 640${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

if grep -qi "permissão 777" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 3/6] Corrigindo permissões 777 de diretórios para 755...${C_RESET}"
    find . -type d -perm 0777 -exec chmod 755 {} + 2>/dev/null
    echo -e "  ${C_GREEN}✓ Diretórios 777 corrigidos para CHMOD 755${C_RESET}"
    ((CORRECOES_REALIZADAS++))
fi

# ------------------------------------------------------------------------------
# 3. BLOQUEIO DE EDIÇÃO DE ARQUIVOS NO PAINEL (DISALLOW_FILE_EDIT)
# ------------------------------------------------------------------------------
if grep -qi "DISALLOW_FILE_EDIT" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 4/6] Desativando a edição de arquivos via painel Admin...${C_RESET}"
    if [ -f wp-config.php ]; then
        if ! grep -q "DISALLOW_FILE_EDIT" wp-config.php; then
            sed -i '2i define( "DISALLOW_FILE_EDIT", true );' wp-config.php
            echo -e "  ${C_GREEN}✓ Inserido em 'wp-config.php': define( 'DISALLOW_FILE_EDIT', true );${C_RESET}"
            ((CORRECOES_REALIZADAS++))
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 4. TRATAMENTO DE PHP NA PASTA UPLOADS + SEGURANÇA HTACCESS
# ------------------------------------------------------------------------------
if grep -qi "Arquivos PHP executáveis na pasta UPLOADS" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 5/6] Isolando scripts PHP na pasta Uploads...${C_RESET}"
    
    PHP_FILES=$(find wp-content/uploads/ -type f -name "*.php" 2>/dev/null)
    if [ -n "$PHP_FILES" ]; then
        for FILE in $PHP_FILES; do
            mv "$FILE" "${FILE}.quarentena"
            echo -e "  ${C_RED}✓ Isolado: '$FILE' -> '${FILE}.quarentena'${C_RESET}"
            ((CORRECOES_REALIZADAS++))
        done
    fi
    
    HTACCESS_UPLOADS="wp-content/uploads/.htaccess"
    if [ ! -f "$HTACCESS_UPLOADS" ]; then
        echo -e "<Files *.php>\n    deny from all\n</Files>" > "$HTACCESS_UPLOADS"
        echo -e "  ${C_GREEN}✓ Criado: '$HTACCESS_UPLOADS' (Bloqueio total de execução PHP no diretório)${C_RESET}"
        ((CORRECOES_REALIZADAS++))
    fi
fi

# ------------------------------------------------------------------------------
# 5. RESTAURAÇÃO DO CORE ADULTERADO
# ------------------------------------------------------------------------------
if grep -qi "Arquivo do Core alterado" "$ULTIMO_RELATORIO"; then
    echo -e "${C_CYAN}[FIX 6/6] Restaurando arquivos nativos do WordPress...${C_RESET}"
    if command -v wp &> /dev/null; then
        wp core download --skip-content --force --allow-root &>/dev/null
        echo -e "  ${C_GREEN}✓ Core oficial recarregado da fonte oficial do WordPress${C_RESET}"
        ((CORRECOES_REALIZADAS++))
    fi
fi

# ------------------------------------------------------------------------------
# RESUMO DAS AÇÕES
# ------------------------------------------------------------------------------
echo -e "\n${C_BLUE}=================================================================${C_RESET}"
echo -e "                   ${C_BOLD}RESUMO DAS CORREÇÕES${C_RESET}                          "
echo -e "${C_BLUE}=================================================================${C_RESET}"

if [ $CORRECOES_REALIZADAS -gt 0 ]; then
    echo -e " Total de ações executadas : ${C_GREEN}${CORRECOES_REALIZADAS}${C_RESET}"
    echo -e " Status do ambiente        : ${C_GREEN}Vulnerabilidades Mitigadas${C_RESET}"
    echo -e "\n${C_YELLOW}[!] Execute o './scanner.sh' novamente para atualizar seu score.${C_RESET}\n"
else
    echo -e " Nenhuma ação pendente identificada.\n"
fi
