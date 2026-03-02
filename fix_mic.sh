#!/usr/bin/env bash
# fix_mic.sh — Corrige boost excessivo de microfone no Linux
# Testado em: Zorin OS 18, Ubuntu 24.04
# Uso: bash fix_mic.sh

set -e

echo "=== fix_mic.sh ==="
echo "Detectando placas de som..."

# Lista todas as placas
CARDS=$(arecord -l 2>/dev/null | grep "^placa" | awk '{print $2}' | tr -d ':')

if [ -z "$CARDS" ]; then
    echo "Nenhuma placa de captura encontrada. Verifique sua instalação de ALSA."
    exit 1
fi

echo "Placas encontradas: $CARDS"
echo ""

for CARD in $CARDS; do
    echo "--- Placa $CARD ---"

    # Tenta corrigir Front Mic Boost
    if amixer -c "$CARD" get 'Front Mic Boost' &>/dev/null; then
        echo "Front Mic Boost encontrado. Ajustando para 1 (10dB)..."
        amixer -c "$CARD" set 'Front Mic Boost' 1
    fi

    # Tenta corrigir Rear Mic Boost
    if amixer -c "$CARD" get 'Rear Mic Boost' &>/dev/null; then
        REAR_VAL=$(amixer -c "$CARD" get 'Rear Mic Boost' | grep "Front Left:" | awk '{print $2}')
        if [ "$REAR_VAL" = "3" ]; then
            echo "Rear Mic Boost estava em 3 (30dB). Ajustando para 1..."
            amixer -c "$CARD" set 'Rear Mic Boost' 1
        else
            echo "Rear Mic Boost em $REAR_VAL, sem alteração."
        fi
    fi

    # Tenta corrigir Mic Boost genérico
    if amixer -c "$CARD" get 'Mic Boost' &>/dev/null; then
        echo "Mic Boost genérico encontrado. Ajustando para 1..."
        amixer -c "$CARD" set 'Mic Boost' 1
    fi

    echo ""
done

echo "Salvando configuração com alsactl..."
alsactl store
echo "Configuração salva. Não vai resetar no próximo boot."
echo ""
echo "Pronto. Se o áudio ainda estiver ruim, rode:"
echo "  amixer -c <numero_da_placa> scontents | grep -A6 -i mic"
echo "e ajuste manualmente o boost para 0 se necessário."
