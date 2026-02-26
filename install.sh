#!/usr/bin/env bash
# ==============================================================================
#  Natteens Dotfiles Installer  —  Arch Linux
#  bash puro, sem deps externas, seta+espaco+enter
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPERS_REPO="https://github.com/Natteens/Wallpapers.git"
WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
LOG_FILE="/tmp/dotfiles-install.log"
TMPDIR_WORK=""

# ── Colors ─────────────────────────────────────────────────────────────────────
bold=$'\e[1m'; dim=$'\e[2m'; reset=$'\e[0m'
red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'
blue=$'\e[34m'; cyan=$'\e[36m'; gray=$'\e[90m'
bg_sel=$'\e[48;5;236m'; fg_sel=$'\e[96m'

# ── Output ─────────────────────────────────────────────────────────────────────
print_step() { echo "  ${cyan}::${reset} $*"; }
print_ok()   { echo "  ${green}ok${reset}  $*"; }
print_warn() { echo "  ${yellow}!!${reset}  $*"; }
print_err()  { echo "  ${red}xx${reset}  $*" >&2; }
print_log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }
print_sep()  { printf "  %s\n" "$(printf '─%.0s' {1..52})"; }

# ── Spinner ────────────────────────────────────────────────────────────────────
_spin_pid=""
spinner_start() {
    ( local f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
      while true; do
          printf "\r  ${cyan}%s${reset}  %s " "${f:$((i%10)):1}" "$1"
          sleep 0.08; ((i++)) || true
      done ) &
    _spin_pid=$!
}
spinner_stop() {
    [[ -n "$_spin_pid" ]] && kill "$_spin_pid" 2>/dev/null || true
    _spin_pid=""; printf "\r\033[2K"
}
run_silent() {
    local msg="$1"; shift
    spinner_start "$msg"
    if "$@" >> "$LOG_FILE" 2>&1; then
        spinner_stop; print_ok "$msg"
    else
        spinner_stop; print_err "$msg — falhou (ver $LOG_FILE)"; return 1
    fi
}

# ── Package helpers ────────────────────────────────────────────────────────────
has()           { command -v "$1" &>/dev/null; }
pkg_pacman()    { pacman -Qi "$1" &>/dev/null 2>&1; }
pkg_flatpak()   { flatpak list --app 2>/dev/null | grep -qi "$1"; }
pacman_install(){ print_log "pacman: $*"; sudo pacman -S --needed --noconfirm "$@" >> "$LOG_FILE" 2>&1; }
aur_install()   { print_log "yay: $*";   yay -S --needed --noconfirm "$@"          >> "$LOG_FILE" 2>&1; }
paru_install()  { print_log "paru: $*";  paru -S --needed --noconfirm "$@"         >> "$LOG_FILE" 2>&1; }

# ── Detection ──────────────────────────────────────────────────────────────────
detect_system() {
    # Tools
    HAS_YAY=false;      has yay              && HAS_YAY=true     || true
    HAS_PARU=false;     has paru             && HAS_PARU=true    || true
    HAS_ZSH=false;      has zsh              && HAS_ZSH=true     || true
    HAS_NVIM=false;     has nvim             && HAS_NVIM=true    || true
    HAS_KITTY=false;    has kitty            && HAS_KITTY=true   || true
    HAS_FLATPAK=false;  has flatpak          && HAS_FLATPAK=true || true
    HAS_STOW=false;     has stow             && HAS_STOW=true    || true
    HAS_GH=false;       has gh               && HAS_GH=true      || true
    HAS_SDDM=false;     pkg_pacman sddm      && HAS_SDDM=true    || true
    HAS_PIPEWIRE=false; pkg_pacman pipewire  && HAS_PIPEWIRE=true || true
    HAS_BT=false;       pkg_pacman bluez     && HAS_BT=true      || true

    # Apps pacman/AUR
    HAS_BRAVE=false;    pkg_pacman brave-bin       && HAS_BRAVE=true    || true
    HAS_STEAM=false;    pkg_pacman steam           && HAS_STEAM=true    || true
    HAS_VESKTOP=false;  pkg_pacman vesktop-bin     && HAS_VESKTOP=true  || true
    HAS_SPOTIFY=false;  pkg_pacman spotify         && HAS_SPOTIFY=true  || true
    HAS_FRESH=false;    pkg_pacman fresh-editor    && HAS_FRESH=true    || true
    HAS_EQUIBOP=false;  pkg_pacman equibop         && HAS_EQUIBOP=true  || true
    HAS_HEROIC=false;   pkg_pacman heroic-games-launcher-bin && HAS_HEROIC=true || true
    HAS_BIBATA=false;   pkg_pacman bibata-cursor-theme-bin   && HAS_BIBATA=true || true
    HAS_SPICETIFY=false; has spicetify             && HAS_SPICETIFY=true || true

    # Flatpak apps
    HAS_GH_DESKTOP=false; pkg_flatpak "github-desktop-plus" && HAS_GH_DESKTOP=true || true
    HAS_HEROIC_FLAT=false; pkg_flatpak "heroic"             && HAS_HEROIC_FLAT=true || true

    # GPU / CPU
    GPU_NVIDIA=false; GPU_AMD=false; CPU_AMD=false; CPU_INTEL=false
    lspci 2>/dev/null | grep -qi 'nvidia'            && GPU_NVIDIA=true || true
    lspci 2>/dev/null | grep -qi 'amd\|radeon\|ati'  && GPU_AMD=true   || true
    grep -qi 'amd'   /proc/cpuinfo 2>/dev/null       && CPU_AMD=true   || true
    grep -qi 'intel' /proc/cpuinfo 2>/dev/null       && CPU_INTEL=true || true
    IS_VM=false; systemd-detect-virt --quiet 2>/dev/null && IS_VM=true || true
}

# ── Bootstrap ──────────────────────────────────────────────────────────────────
check_arch() { [[ -f /etc/arch-release ]] || { echo "Apenas Arch Linux suportado."; exit 1; }; }

ask_yn() {
    # ask_yn "pergunta" → retorna 0 para sim, 1 para nao
    local msg="$1"
    printf "  ${yellow}?${reset}  %s [S/n] " "$msg"
    read -r ans
    [[ "${ans,,}" != "n" ]]
}

setup_deps() {
    print_sep
    echo "  ${bold}Verificando dependencias do instalador...${reset}"
    print_sep; echo

    # yay
    if ! $HAS_YAY; then
        print_warn "yay nao encontrado."
        if ask_yn "Instalar yay (necessario para pacotes AUR)?"; then
            print_step "Instalando yay..."
            pacman_install git base-devel
            TMPDIR_WORK=$(mktemp -d)
            git clone https://aur.archlinux.org/yay.git "$TMPDIR_WORK/yay" >> "$LOG_FILE" 2>&1
            (cd "$TMPDIR_WORK/yay" && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1)
            rm -rf "$TMPDIR_WORK"
            HAS_YAY=true
            print_ok "yay instalado."
        else
            print_warn "Sem yay — pacotes AUR nao poderao ser instalados."
        fi
    fi

    # paru
    if ! $HAS_PARU; then
        print_warn "paru nao encontrado."
        if ask_yn "Instalar paru (AUR helper alternativo, necessario para bibata cursor)?"; then
            print_step "Instalando paru..."
            TMPDIR_WORK=$(mktemp -d)
            git clone https://aur.archlinux.org/paru.git "$TMPDIR_WORK/paru" >> "$LOG_FILE" 2>&1
            (cd "$TMPDIR_WORK/paru" && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1)
            rm -rf "$TMPDIR_WORK"
            HAS_PARU=true
            print_ok "paru instalado."
        fi
    fi

    echo
}

# ── Banner ─────────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo
    echo "  ${bold}╭──────────────────────────────────────────────╮${reset}"
    echo "  ${bold}│                                              │${reset}"
    echo "  ${bold}│   Natteens Dotfiles Installer                │${reset}"
    echo "  ${bold}│   ${dim}Arch Linux  ·  stow  ·  yay  ·  paru${reset}${bold}      │${reset}"
    echo "  ${bold}│                                              │${reset}"
    echo "  ${bold}╰──────────────────────────────────────────────╯${reset}"
    echo

    local gpu=""; $GPU_NVIDIA && gpu+="NVIDIA "; $GPU_AMD && gpu+="AMD"; [[ -z "$gpu" ]] && gpu="nenhuma"
    local cpu=""; $CPU_AMD && cpu="AMD"; $CPU_INTEL && cpu="${cpu:+$cpu + }Intel"

    echo "  ${dim}GPU    ${reset}${cyan}$gpu${reset}"
    echo "  ${dim}CPU    ${reset}${cyan}$cpu${reset}"
    echo "  ${dim}Shell  ${reset}$($HAS_ZSH      && echo "${cyan}zsh${reset} ${dim}(instalado)${reset}"    || echo "${gray}bash${reset}")"
    echo "  ${dim}Audio  ${reset}$($HAS_PIPEWIRE && echo "${cyan}pipewire${reset}"                         || echo "${gray}nao detectado${reset}")"
    echo "  ${dim}yay    ${reset}$($HAS_YAY      && echo "${green}ok${reset}"                              || echo "${yellow}nao encontrado${reset}")"
    echo "  ${dim}paru   ${reset}$($HAS_PARU     && echo "${green}ok${reset}"                              || echo "${yellow}nao encontrado${reset}")"
    $IS_VM && echo "  ${dim}VM     ${reset}${yellow}ambiente virtual${reset}"
    echo
}

# ══════════════════════════════════════════════════════════════════════════════
#  SELETOR BASH PURO
#  seta cima/baixo = navegar
#  espaco          = marcar/desmarcar
#  a               = marcar tudo
#  n               = desmarcar tudo
#  enter           = confirmar
#  q / ctrl-c      = sair
# ══════════════════════════════════════════════════════════════════════════════

declare -a _KEYS=()
declare -a _LABELS=()
declare -a _CHECKED=()
declare -a _IS_SEP=()

menu_sep() {
    _KEYS+=("")
    _LABELS+=("$1")
    _CHECKED+=(0)
    _IS_SEP+=(1)
}

menu_item() {
    # menu_item key label installed(true/false)
    local key="$1" label="$2" inst="$3"
    _KEYS+=("$key")
    _LABELS+=("$label")
    _CHECKED+=($( [[ "$inst" == "true" ]] && echo 1 || echo 0 ))
    _IS_SEP+=(0)
}

_render_line() {
    local i=$1 cursor=$2
    if [[ "${_IS_SEP[$i]}" == "1" ]]; then
        printf "  ${blue}${bold}  ─── %-42s${reset}\n" "${_LABELS[$i]}"
        return
    fi
    local box; [[ "${_CHECKED[$i]}" == "1" ]] && box="${green}[x]${reset}" || box="${gray}[ ]${reset}"
    if [[ "$i" == "$cursor" ]]; then
        printf "  ${bg_sel}${fg_sel}${bold} > %s  %-42s ${reset}\n" "$box" "${_LABELS[$i]}"
    else
        printf "    %s  %-42s\n" "$box" "${_LABELS[$i]}"
    fi
}

declare -a CHOSEN_KEYS=()

run_selector() {
    local total=${#_KEYS[@]}
    local cursor=0
    local visible=24
    local offset=0

    # Pula pra primeiro item
    while [[ $cursor -lt $total && "${_IS_SEP[$cursor]}" == "1" ]]; do ((cursor++)) || true; done

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true

    _draw() {
        tput cup 0 0 2>/dev/null || printf '\033[H'
        printf '\033[2J' 2>/dev/null || true
        echo
        printf "  ${bold}Selecione os itens para instalar${reset}\n"
        printf "  ${dim}↑↓=navegar  espaco=marcar  a=tudo  n=nenhum  enter=confirmar  q=sair${reset}\n\n"

        local end=$(( offset + visible ))
        [[ $end -gt $total ]] && end=$total

        for (( i=offset; i<end; i++ )); do
            _render_line "$i" "$cursor"
        done

        # Preenche espaco vazio pra nao deixar lixo na tela
        local drawn=$(( end - offset ))
        for (( i=drawn; i<visible+2; i++ )); do printf "\033[2K\n"; done

        local marked=0
        for c in "${_CHECKED[@]}"; do [[ "$c" == "1" ]] && ((marked++)) || true; done
        printf "  ${dim}%d item(s) marcado(s)${reset}\033[K\n" "$marked"
    }

    _next() {
        local i=$(( cursor + 1 ))
        while [[ $i -lt $total ]]; do
            [[ "${_IS_SEP[$i]}" == "0" ]] && { cursor=$i; break; }
            ((i++)) || true
        done
    }

    _prev() {
        local i=$(( cursor - 1 ))
        while [[ $i -ge 0 ]]; do
            [[ "${_IS_SEP[$i]}" == "0" ]] && { cursor=$i; break; }
            ((i--)) || true
        done
    }

    _scroll() {
        [[ $cursor -lt $offset ]] && offset=$cursor
        [[ $cursor -ge $(( offset + visible )) ]] && offset=$(( cursor - visible + 1 ))
    }

    local result="ok"
    _draw
    while true; do
        _scroll; _draw

        local key; IFS= read -rsn1 key 2>/dev/null || true

        case "$key" in
            $'\x1b')
                local seq; IFS= read -rsn2 -t 0.1 seq 2>/dev/null || true
                case "$seq" in
                    '[A') _prev ;;
                    '[B') _next ;;
                esac
                ;;
            ' ')
                [[ "${_IS_SEP[$cursor]}" == "0" ]] && {
                    [[ "${_CHECKED[$cursor]}" == "1" ]] && _CHECKED[$cursor]=0 || _CHECKED[$cursor]=1
                }
                ;;
            'a'|'A') for (( i=0; i<total; i++ )); do [[ "${_IS_SEP[$i]}" == "0" ]] && _CHECKED[$i]=1; done ;;
            'n'|'N') for (( i=0; i<total; i++ )); do _CHECKED[$i]=0; done ;;
            ''|$'\n') result="ok"; break ;;
            'q'|'Q'|$'\x03') result="cancel"; break ;;
        esac
    done

    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true

    [[ "$result" == "cancel" ]] && return 1

    CHOSEN_KEYS=()
    for (( i=0; i<total; i++ )); do
        [[ "${_IS_SEP[$i]}" == "0" && "${_CHECKED[$i]}" == "1" ]] && CHOSEN_KEYS+=("${_KEYS[$i]}")
    done
    return 0
}

# ── Catalog ────────────────────────────────────────────────────────────────────
build_catalog() {
    _KEYS=(); _LABELS=(); _CHECKED=(); _IS_SEP=()

    menu_sep "Base & Shell"
    menu_item base        "Pacotes base        git make cmake curl wget"  "false"
    menu_item yay_pkg     "yay                 AUR helper"                "$HAS_YAY"
    menu_item paru_pkg    "paru                AUR helper alternativo"    "$HAS_PARU"
    menu_item zsh         "Zsh                 zsh + fzf + zoxide"        "$HAS_ZSH"
    menu_item nvim        "Neovim              editor"                    "$HAS_NVIM"
    menu_item fresh       "fresh-editor        editor leve (AUR)"        "$HAS_FRESH"
    menu_item kitty       "Kitty               terminal"                  "$HAS_KITTY"
    menu_item fonts       "Fontes              JetBrains Mono Nerd + Noto" "false"
    menu_item bibata      "Bibata Cursor       tema de cursor (paru)"     "$HAS_BIBATA"
    menu_item qt          "Qt5 / Qt6           wayland support"           "false"
    menu_item sddm        "SDDM                display manager"           "$HAS_SDDM"
    menu_item pipewire    "Pipewire            audio + wireplumber"       "$HAS_PIPEWIRE"
    menu_item bluetooth   "Bluetooth           bluez + blueman"           "$HAS_BT"
    menu_item flatpak     "Flatpak             + Flathub"                 "$HAS_FLATPAK"
    menu_item gh          "GitHub CLI          + openssh"                 "$HAS_GH"

    menu_sep "Apps"
    menu_item brave       "Brave               browser"                   "$HAS_BRAVE"
    menu_item vesktop     "Vesktop             Discord + Vencord"         "$HAS_VESKTOP"
    menu_item equibop     "Equibop             cliente Discord alternativo" "$HAS_EQUIBOP"
    menu_item spotify     "Spotify             musica"                    "$HAS_SPOTIFY"
    menu_item spicetify   "Spicetify           tema pro Spotify"          "$HAS_SPICETIFY"
    menu_item gh_desktop  "GitHub Desktop+     flatpak"                   "$HAS_GH_DESKTOP"
    menu_item jetbrains   "JetBrains Toolbox   IDEs"                      "$(pkg_pacman jetbrains-toolbox && echo true || echo false)"
    menu_item unity       "Unity Hub           game engine"               "$(pkg_pacman unityhub && echo true || echo false)"

    menu_sep "Games"
    menu_item steam       "Steam               plataforma de jogos"       "$HAS_STEAM"
    menu_item heroic      "Heroic (AUR)        Epic / GOG"                "$HAS_HEROIC"
    menu_item heroic_flat "Heroic (Flatpak)    Epic / GOG"                "$HAS_HEROIC_FLAT"

    menu_sep "Drivers"
    menu_item nvidia      "NVIDIA              proprietario + Wayland"    "false"
    menu_item amd_gpu     "AMD GPU             mesa + vulkan-radeon"      "false"
    menu_item amd_cpu     "AMD CPU             amd-ucode microcódigo"     "false"
    menu_item intel_gpu   "Intel GPU           mesa + vulkan-intel"       "false"
    menu_item intel_cpu   "Intel CPU           intel-ucode microcódigo"   "false"

    menu_sep "Dotfiles"
    menu_item wallpapers  "Wallpapers          ~/Pictures/Wallpapers"     "$([[ -d "$WALLPAPERS_DIR" ]] && echo true || echo false)"
    menu_item symlinks    "Symlinks            aplicar via stow"          "false"
}

# ══════════════════════════════════════════════════════════════════════════════
#  INSTALL MODULES
# ══════════════════════════════════════════════════════════════════════════════

install_base() { run_silent "pacotes base" pacman_install git nano base-devel make cmake curl wget unzip; }

install_yay_pkg() {
    $HAS_YAY && { print_warn "yay ja instalado"; return; }
    print_step "Instalando yay..."
    pacman_install git base-devel
    TMPDIR_WORK=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TMPDIR_WORK/yay" >> "$LOG_FILE" 2>&1
    (cd "$TMPDIR_WORK/yay" && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1)
    rm -rf "$TMPDIR_WORK"; HAS_YAY=true
    print_ok "yay instalado."
}

install_paru_pkg() {
    $HAS_PARU && { print_warn "paru ja instalado"; return; }
    print_step "Instalando paru..."
    pacman_install git base-devel
    TMPDIR_WORK=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$TMPDIR_WORK/paru" >> "$LOG_FILE" 2>&1
    (cd "$TMPDIR_WORK/paru" && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1)
    rm -rf "$TMPDIR_WORK"; HAS_PARU=true
    print_ok "paru instalado."
}

install_zsh() {
    local pkgs=()
    has zsh    || pkgs+=(zsh)
    has zoxide || pkgs+=(zoxide)
    has fzf    || pkgs+=(fzf)
    [[ ${#pkgs[@]} -gt 0 ]] && run_silent "zsh + zoxide + fzf" pacman_install "${pkgs[@]}"
    grep -q "/usr/bin/zsh" /etc/shells 2>/dev/null || echo "/usr/bin/zsh" | sudo tee -a /etc/shells >> "$LOG_FILE"
    chsh -s /usr/bin/zsh && print_ok "zsh = shell padrao" || print_warn "rode 'chsh -s /usr/bin/zsh' manualmente"
}

install_nvim()   { $HAS_NVIM  && { print_warn "neovim ja instalado";    return; }; run_silent "neovim"       pacman_install neovim; }
install_fresh()  { $HAS_FRESH && { print_warn "fresh-editor ja inst.";  return; }; run_silent "fresh-editor" aur_install fresh-editor; }

install_kitty() {
    $HAS_KITTY && { print_warn "kitty ja instalado"; return; }
    run_silent "kitty" pacman_install kitty
    mkdir -p "$HOME/.config/kitty"
    grep -q "shell /usr/bin/zsh" "$HOME/.config/kitty/kitty.conf" 2>/dev/null \
        || echo "shell /usr/bin/zsh" >> "$HOME/.config/kitty/kitty.conf"
}

install_fonts() {
    pkg_pacman ttf-jetbrains-mono-nerd \
        && print_warn "JetBrains Mono Nerd ja instalado" \
        || run_silent "JetBrains Mono Nerd" aur_install ttf-jetbrains-mono-nerd
    run_silent "Noto Fonts + Emoji" pacman_install noto-fonts noto-fonts-emoji
}

install_bibata() {
    $HAS_BIBATA && { print_warn "bibata ja instalado"; return; }
    if ! $HAS_PARU; then
        print_warn "paru necessario para bibata — instale paru primeiro"
        return 1
    fi
    run_silent "bibata-cursor-theme-bin" paru_install bibata-cursor-theme-bin
}

install_qt()     { run_silent "Qt5 + Qt6 + Wayland" pacman_install qt5-base qt6-base qt5-wayland qt6-wayland; }

install_sddm() {
    $HAS_SDDM || run_silent "sddm" pacman_install sddm
    run_silent "sddm Qt6 deps" pacman_install qt6-svg qt6-virtualkeyboard qt6-multimedia
    run_silent "habilitar sddm" sudo systemctl enable sddm
}

install_pipewire() {
    $HAS_PIPEWIRE && { print_warn "pipewire ja instalado"; return; }
    run_silent "pipewire + wireplumber" pacman_install pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    run_silent "habilitar pipewire" systemctl --user enable --now pipewire pipewire-pulse wireplumber
}

install_bluetooth() {
    $HAS_BT && { print_warn "bluez ja instalado"; return; }
    run_silent "bluez + blueman" pacman_install bluez bluez-utils blueman
    run_silent "habilitar bluetooth" sudo systemctl enable --now bluetooth
}

install_flatpak() {
    $HAS_FLATPAK || run_silent "flatpak" pacman_install flatpak
    run_silent "Flathub" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_gh() {
    $HAS_GH || run_silent "github-cli + openssh" pacman_install github-cli openssh
    print_step "Autenticando GitHub (siga as instrucoes)..."
    gh auth login && print_ok "GitHub CLI autenticado."
}

install_brave()   { $HAS_BRAVE   && { print_warn "Brave ja instalado";   return; }; run_silent "Brave"   aur_install brave-bin; }

install_vesktop() {
    $HAS_VESKTOP && { print_warn "Vesktop ja instalado"; return; }
    run_silent "Vesktop (Discord + Vencord)" aur_install vesktop-bin
}

install_equibop() {
    $HAS_EQUIBOP && { print_warn "Equibop ja instalado"; return; }
    # Equibop precisa de npm pra buildar
    has npm || run_silent "npm (dep equibop)" pacman_install npm
    run_silent "Equibop" aur_install equibop
}

install_spotify() {
    $HAS_SPOTIFY || run_silent "Spotify" aur_install spotify
    print_ok "Spotify instalado."
}

install_spicetify() {
    $HAS_SPICETIFY && { print_warn "spicetify ja instalado"; return; }
    run_silent "spicetify-cli" aur_install spicetify-cli
    sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R 2>/dev/null || true
    spicetify backup apply >> "$LOG_FILE" 2>&1 || true
    print_ok "Spicetify configurado."
}

install_gh_desktop() {
    $HAS_GH_DESKTOP && { print_warn "GitHub Desktop+ ja instalado"; return; }
    if ! $HAS_FLATPAK; then
        print_warn "Flatpak necessario — instale Flatpak primeiro"
        return 1
    fi
    run_silent "GitHub Desktop Plus (flatpak)" \
        flatpak install -y --noninteractive flathub io.github.pol_rivero.github-desktop-plus
}

install_jetbrains() { pkg_pacman jetbrains-toolbox && { print_warn "JetBrains ja instalado"; return; }; run_silent "JetBrains Toolbox" aur_install jetbrains-toolbox; }
install_unity()     { pkg_pacman unityhub && { print_warn "Unity Hub ja instalado"; return; }; run_silent "Unity Hub" aur_install unityhub; }

install_steam() {
    $HAS_STEAM && { print_warn "Steam ja instalado"; return; }
    grep -q "^\[multilib\]" /etc/pacman.conf || {
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >> "$LOG_FILE"
        sudo pacman -Sy >> "$LOG_FILE" 2>&1
    }
    run_silent "Steam" pacman_install steam
}

install_heroic() {
    $HAS_HEROIC && { print_warn "Heroic (AUR) ja instalado"; return; }
    run_silent "Heroic (AUR)" aur_install heroic-games-launcher-bin
}

install_heroic_flat() {
    $HAS_HEROIC_FLAT && { print_warn "Heroic (flatpak) ja instalado"; return; }
    if ! $HAS_FLATPAK; then print_warn "Flatpak necessario"; return 1; fi
    run_silent "Heroic (Flatpak)" \
        flatpak install -y --noninteractive flathub com.heroicgameslauncher.hgl
}

install_nvidia() {
    local use_open=false
    lspci 2>/dev/null | grep -qi 'rtx\|GeForce 20\|GeForce 30\|GeForce 40\|GeForce 50' && use_open=true || true
    $use_open \
        && run_silent "nvidia-open + utils" pacman_install nvidia-open nvidia-utils nvidia-settings lib32-nvidia-utils \
        || run_silent "nvidia + utils"      pacman_install nvidia      nvidia-utils nvidia-settings lib32-nvidia-utils
    grep -q "nvidia_drm" /etc/mkinitcpio.conf 2>/dev/null || {
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        run_silent "mkinitcpio rebuild" sudo mkinitcpio -P
    }
    grep -q "GBM_BACKEND" /etc/environment 2>/dev/null || \
        printf '\nGBM_BACKEND=nvidia-drm\n__GLX_VENDOR_LIBRARY_NAME=nvidia\nNVIDIA_DRIVER_CAPABILITIES=all\n' \
        | sudo tee -a /etc/environment >> "$LOG_FILE"
    print_warn "Reinicie para ativar os drivers NVIDIA."
}

install_amd_gpu()  {
    run_silent "AMD GPU — mesa + vulkan" \
        pacman_install mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver mesa-vdpau
}
install_amd_cpu()  { run_silent "amd-ucode" pacman_install amd-ucode; print_warn "Adicione 'initrd /amd-ucode.img' ao bootloader."; }
install_intel_gpu(){ run_silent "Intel GPU — mesa + vulkan" pacman_install mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver; }
install_intel_cpu(){ run_silent "intel-ucode" pacman_install intel-ucode; print_warn "Adicione 'initrd /intel-ucode.img' ao bootloader."; }

install_wallpapers() {
    mkdir -p "$HOME/Pictures"
    if [[ -d "$WALLPAPERS_DIR" ]]; then
        run_silent "atualizando wallpapers" git -C "$WALLPAPERS_DIR" pull
    else
        run_silent "clonando wallpapers" git clone "$WALLPAPERS_REPO" "$HOME/Pictures/"
    fi
    print_ok "Wallpapers em $WALLPAPERS_DIR"
}

install_symlinks() {
    $HAS_STOW || run_silent "stow" pacman_install stow
    cd "$DOTFILES_DIR"
    run_silent "symlinks via stow" stow --adopt .
}

run_key() {
    case "$1" in
        base)        install_base ;;
        yay_pkg)     install_yay_pkg ;;
        paru_pkg)    install_paru_pkg ;;
        zsh)         install_zsh ;;
        nvim)        install_nvim ;;
        fresh)       install_fresh ;;
        kitty)       install_kitty ;;
        fonts)       install_fonts ;;
        bibata)      install_bibata ;;
        qt)          install_qt ;;
        sddm)        install_sddm ;;
        pipewire)    install_pipewire ;;
        bluetooth)   install_bluetooth ;;
        flatpak)     install_flatpak ;;
        gh)          install_gh ;;
        brave)       install_brave ;;
        vesktop)     install_vesktop ;;
        equibop)     install_equibop ;;
        spotify)     install_spotify ;;
        spicetify)   install_spicetify ;;
        gh_desktop)  install_gh_desktop ;;
        jetbrains)   install_jetbrains ;;
        unity)       install_unity ;;
        steam)       install_steam ;;
        heroic)      install_heroic ;;
        heroic_flat) install_heroic_flat ;;
        nvidia)      install_nvidia ;;
        amd_gpu)     install_amd_gpu ;;
        amd_cpu)     install_amd_cpu ;;
        intel_gpu)   install_intel_gpu ;;
        intel_cpu)   install_intel_cpu ;;
        wallpapers)  install_wallpapers ;;
        symlinks)    install_symlinks ;;
    esac
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
    [[ -n "$TMPDIR_WORK" && -d "$TMPDIR_WORK" ]] && rm -rf "$TMPDIR_WORK" || true
}
trap cleanup EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    check_arch
    : > "$LOG_FILE"

    clear; echo; echo "  Detectando sistema..."
    detect_system

    show_banner
    setup_deps

    build_catalog

    echo "  ${dim}Pressione ENTER para abrir o seletor...${reset}"
    read -r

    run_selector || { echo "  Cancelado."; exit 0; }
    [[ ${#CHOSEN_KEYS[@]} -eq 0 ]] && { echo "  Nada selecionado."; exit 0; }

    # Confirmacao
    clear; echo
    echo "  ${bold}Itens selecionados para instalacao:${reset}"
    print_sep
    for k in "${CHOSEN_KEYS[@]}"; do echo "  ${cyan}+${reset}  $k"; done
    print_sep; echo
    printf "  Instalar agora? [S/n] "; read -r ans
    [[ "${ans,,}" == "n" ]] && { echo "  Cancelado."; exit 0; }

    # Instalacao
    clear; echo
    echo "  ${bold}Instalando...${reset}"; echo

    local failed=()
    for key in "${CHOSEN_KEYS[@]}"; do
        echo "  ${blue}──${reset} ${bold}$key${reset}"
        run_key "$key" || failed+=("$key")
        echo
    done

    # Resumo
    print_sep
    echo "  ${bold}Concluido${reset}"
    print_sep
    echo "  ${green}ok${reset}   $((${#CHOSEN_KEYS[@]} - ${#failed[@]})) / ${#CHOSEN_KEYS[@]} instalados"
    [[ ${#failed[@]} -gt 0 ]] && {
        echo "  ${red}!!${reset}   ${#failed[@]} falha(s):"
        for f in "${failed[@]}"; do echo "       ${gray}- $f${reset}"; done
        echo "  ${dim}log completo: $LOG_FILE${reset}"
    }
    echo
}

main "$@"
