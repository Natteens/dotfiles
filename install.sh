#!/usr/bin/env bash
# ==============================================================================
#  Natteens Quick Setup — Linux Mint / Ubuntu / Debian-based
#  sudo bash setup.sh
# ==============================================================================
set -euo pipefail

# ── Root check ─────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Execute com sudo: sudo bash setup.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
LOG_FILE="/tmp/natteens-setup.log"
: > "$LOG_FILE"

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

# ── run_silent: não trava mesmo se demorar ─────────────────────────────────────
run_silent() {
    local msg="$1"; shift
    spinner_start "$msg"
    local ret=0
    "$@" >> "$LOG_FILE" 2>&1 || ret=$?
    spinner_stop
    if [[ $ret -eq 0 ]]; then
        print_ok "$msg"
    else
        print_err "$msg — falhou (ver $LOG_FILE)"
        return 1
    fi
}

# ── Package helpers ────────────────────────────────────────────────────────────
has()            { command -v "$1" &>/dev/null; }
pkg_apt()        { dpkg -l "$1" 2>/dev/null | grep -q '^ii'; }
pkg_flatpak()    { flatpak list --app 2>/dev/null | grep -qi "$1"; }
pkg_snap()       { snap list 2>/dev/null | grep -qi "$1"; }

apt_install() {
    print_log "apt: $*"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >> "$LOG_FILE" 2>&1
}

flatpak_install() {
    print_log "flatpak: $*"
    sudo -u "$REAL_USER" flatpak install -y --noninteractive flathub "$@" >> "$LOG_FILE" 2>&1
}

as_user() {
    sudo -u "$REAL_USER" "$@"
}

# ── Detect distro & package manager ───────────────────────────────────────────
detect_system() {
    DISTRO_ID=""
    DISTRO_NAME=""
    PKG_MANAGER=""

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID:-}"
        DISTRO_NAME="${NAME:-}"
    fi

    if has apt-get; then
        PKG_MANAGER="apt"
    elif has dnf; then
        PKG_MANAGER="dnf"
    elif has pacman; then
        PKG_MANAGER="pacman"
    else
        PKG_MANAGER="unknown"
    fi

    # GPU
    GPU_NVIDIA=false; GPU_AMD=false
    lspci 2>/dev/null | grep -qi 'nvidia'           && GPU_NVIDIA=true || true
    lspci 2>/dev/null | grep -qi 'amd\|radeon\|ati' && GPU_AMD=true   || true

    # Installed checks
    HAS_ZSH=false;       has zsh                    && HAS_ZSH=true       || true
    HAS_NVIM=false;      has nvim                   && HAS_NVIM=true      || true
    HAS_KITTY=false;     has kitty                  && HAS_KITTY=true     || true
    HAS_FLATPAK=false;   has flatpak                && HAS_FLATPAK=true   || true
    HAS_GH=false;        has gh                     && HAS_GH=true        || true
    HAS_BRAVE=false;     has brave-browser          && HAS_BRAVE=true     || true
    HAS_VESKTOP=false;   pkg_flatpak "dev.vencord.Vesktop" && HAS_VESKTOP=true || true
    HAS_SPOTIFY=false;   pkg_flatpak "com.spotify.Client" && HAS_SPOTIFY=true || true
    HAS_STEAM=false;     pkg_apt steam-launcher     && HAS_STEAM=true     || true
    HAS_HEROIC=false;    pkg_flatpak "com.heroicgameslauncher.hgl" && HAS_HEROIC=true || true
    HAS_UNITY=false;     [[ -f "/opt/unityhub/unityhub" ]] && HAS_UNITY=true || true
    HAS_JETBRAINS=false; [[ -f "$REAL_HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]] && HAS_JETBRAINS=true || true
    HAS_VSCODE=false;    has code                   && HAS_VSCODE=true    || true
    HAS_GH_DESKTOP=false; pkg_flatpak "io.github.pol_rivero.github-desktop-plus" && HAS_GH_DESKTOP=true || true
    HAS_SPICETIFY=false; has spicetify              && HAS_SPICETIFY=true || true
    HAS_FFMPEG=false;    has ffmpeg                 && HAS_FFMPEG=true    || true

    IS_VM=false
    systemd-detect-virt --quiet 2>/dev/null && IS_VM=true || true
}

# ── Banner ─────────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo
    echo "  ${bold}╭──────────────────────────────────────────────╮${reset}"
    echo "  ${bold}│                                              │${reset}"
    echo "  ${bold}│   Natteens Quick Setup                       │${reset}"
    echo "  ${bold}│   ${dim}Linux Mint · Ubuntu · Debian-based${reset}${bold}        │${reset}"
    echo "  ${bold}│                                              │${reset}"
    echo "  ${bold}╰──────────────────────────────────────────────╯${reset}"
    echo

    local gpu=""; $GPU_NVIDIA && gpu+="NVIDIA "; $GPU_AMD && gpu+="AMD"; [[ -z "$gpu" ]] && gpu="não detectada"

    echo "  ${dim}Distro  ${reset}${cyan}$DISTRO_NAME${reset}"
    echo "  ${dim}PKG     ${reset}${cyan}$PKG_MANAGER${reset}"
    echo "  ${dim}GPU     ${reset}${cyan}$gpu${reset}"
    echo "  ${dim}User    ${reset}${cyan}$REAL_USER${reset}"
    $IS_VM && echo "  ${dim}VM      ${reset}${yellow}ambiente virtual detectado${reset}"
    echo
}

# ── Bootstrap deps do instalador ───────────────────────────────────────────────
bootstrap() {
    print_sep
    echo "  ${bold}Verificando dependências do instalador...${reset}"
    print_sep; echo

    run_silent "apt update" apt-get update -qq

    has curl   || run_silent "curl"   apt_install curl
    has wget   || run_silent "wget"   apt_install wget
    has git    || run_silent "git"    apt_install git
    has lspci  || run_silent "pciutils" apt_install pciutils

    if ! $HAS_FLATPAK; then
        run_silent "flatpak" apt_install flatpak
        run_silent "flathub" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
        HAS_FLATPAK=true
        print_warn "Flatpak instalado — pode precisar reiniciar após o setup"
    fi

    echo
}

# ══════════════════════════════════════════════════════════════════════════════
#  SELETOR BASH PURO
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

    while [[ $cursor -lt $total && "${_IS_SEP[$cursor]}" == "1" ]]; do ((cursor++)) || true; done

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true

    _draw() {
        tput cup 0 0 2>/dev/null || printf '\033[H'
        printf '\033[2J' 2>/dev/null || true
        echo
        printf "  ${bold}Selecione os itens para instalar${reset}\n"
        printf "  ${dim}↑↓=navegar  espaço=marcar  a=tudo  n=nenhum  enter=confirmar  q=sair${reset}\n\n"

        local end=$(( offset + visible ))
        [[ $end -gt $total ]] && end=$total

        for (( i=offset; i<end; i++ )); do
            _render_line "$i" "$cursor"
        done

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
    menu_item base       "Pacotes base         build-essential curl wget git" "false"
    menu_item zsh        "Zsh                  + fzf + zoxide"                "$HAS_ZSH"
    menu_item nvim       "Neovim               editor"                        "$HAS_NVIM"
    menu_item kitty      "Kitty                terminal"                      "$HAS_KITTY"
    menu_item fonts      "Fontes               JetBrains Nerd + Noto"         "false"
    menu_item ffmpeg     "FFmpeg               codec + mídia"                 "$HAS_FFMPEG"
    menu_item gh         "GitHub CLI           + openssh"                     "$HAS_GH"
    menu_item flatpak    "Flatpak              + Flathub"                     "$HAS_FLATPAK"

    menu_sep "Apps"
    menu_item brave      "Brave                browser"                       "$HAS_BRAVE"
    menu_item vesktop    "Vesktop              Discord + Vencord (flatpak)"   "$HAS_VESKTOP"
    menu_item spotify    "Spotify              flatpak"                       "$HAS_SPOTIFY"
    menu_item spicetify  "Spicetify            tema pro Spotify"              "$HAS_SPICETIFY"
    menu_item gh_desktop "GitHub Desktop+      flatpak"                       "$HAS_GH_DESKTOP"
    menu_item vscode     "VS Code              editor"                        "$HAS_VSCODE"
    menu_item jetbrains  "JetBrains Toolbox    IDEs"                          "$HAS_JETBRAINS"
    menu_item unity      "Unity Hub            game engine"                   "$HAS_UNITY"

    menu_sep "Games"
    menu_item steam      "Steam                plataforma de jogos"           "$HAS_STEAM"
    menu_item heroic     "Heroic               Epic / GOG (flatpak)"          "$HAS_HEROIC"

    menu_sep "Drivers"
    menu_item nvidia     "NVIDIA               driver proprietário"           "false"
    menu_item amd_gpu    "AMD GPU              mesa + vulkan"                 "false"

    menu_sep "Sistema"
    menu_item fix_mic    "Fix Microfone        PulseAudio noise cancel"       "false"
    menu_item tweaks     "Tweaks sistema       swappiness + performance"      "false"
    menu_item codecs     "Codecs               mp3, h264, aac, etc"           "false"
}

# ══════════════════════════════════════════════════════════════════════════════
#  INSTALL MODULES
# ══════════════════════════════════════════════════════════════════════════════

install_base() {
    run_silent "build-essential + base" apt_install \
        build-essential make cmake curl wget git unzip zip \
        ca-certificates gnupg lsb-release software-properties-common \
        apt-transport-https xdg-utils
}

install_zsh() {
    has zsh    || run_silent "zsh"    apt_install zsh
    has fzf    || run_silent "fzf"    apt_install fzf
    has zoxide || {
        run_silent "zoxide" bash -c \
            "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sudo -u $REAL_USER bash"
    }
    grep -q "/usr/bin/zsh" /etc/shells 2>/dev/null || echo "/usr/bin/zsh" | tee -a /etc/shells >> "$LOG_FILE"
    chsh -s /usr/bin/zsh "$REAL_USER" && print_ok "zsh = shell padrão" || print_warn "rode 'chsh -s /usr/bin/zsh' manualmente"
}

install_nvim() {
    $HAS_NVIM && { print_warn "neovim já instalado"; return; }
    # Usa snap pra versão mais recente no Mint/Ubuntu
    if has snap; then
        run_silent "neovim (snap)" snap install nvim --classic
    else
        run_silent "neovim (apt)" apt_install neovim
    fi
}

install_kitty() {
    $HAS_KITTY && { print_warn "kitty já instalado"; return; }
    run_silent "kitty" bash -c \
        "curl -sSfL https://sw.kovidgoyal.net/kitty/installer.sh | sudo -u $REAL_USER sh /dev/stdin"
    # Symlink
    as_user ln -sf "$REAL_HOME/.local/kitty.app/bin/kitty" "$REAL_HOME/.local/bin/kitty" 2>/dev/null || true
    as_user ln -sf "$REAL_HOME/.local/kitty.app/bin/kitten" "$REAL_HOME/.local/bin/kitten" 2>/dev/null || true
}

install_fonts() {
    run_silent "fontes base" apt_install fonts-noto fonts-noto-color-emoji
    # JetBrains Mono Nerd
    local font_dir="$REAL_HOME/.local/share/fonts"
    as_user mkdir -p "$font_dir"
    run_silent "JetBrains Mono Nerd" bash -c "
        cd /tmp
        wget -q 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz' -O JetBrainsMono.tar.xz
        mkdir -p jb_font && tar -xf JetBrainsMono.tar.xz -C jb_font
        cp jb_font/*.ttf '$font_dir/' 2>/dev/null || true
        rm -rf jb_font JetBrainsMono.tar.xz
    "
    fc-cache -f "$font_dir" >> "$LOG_FILE" 2>&1
    print_ok "Fontes instaladas"
}

install_ffmpeg() {
    $HAS_FFMPEG && { print_warn "ffmpeg já instalado"; return; }
    run_silent "ffmpeg" apt_install ffmpeg
}

install_gh() {
    if ! $HAS_GH; then
        run_silent "github-cli repo" bash -c "
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list
            apt-get update -qq
        "
        run_silent "github-cli" apt_install gh openssh-client
    fi
    print_step "Autenticando GitHub (siga as instruções)..."
    as_user gh auth login && print_ok "GitHub CLI autenticado." || print_warn "Autentique manualmente com: gh auth login"
}

install_flatpak() {
    $HAS_FLATPAK && { print_warn "flatpak já instalado"; return; }
    run_silent "flatpak" apt_install flatpak
    run_silent "flathub" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    print_warn "Reinicie o sistema para ativar o Flatpak completamente"
}

install_brave() {
    $HAS_BRAVE && { print_warn "Brave já instalado"; return; }
    run_silent "brave repo" bash -c "
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main' \
            > /etc/apt/sources.list.d/brave-browser-release.list
        apt-get update -qq
    "
    run_silent "brave-browser" apt_install brave-browser
}

install_vesktop() {
    $HAS_VESKTOP && { print_warn "Vesktop já instalado"; return; }
    run_silent "Vesktop (flatpak)" flatpak_install dev.vencord.Vesktop
}

install_spotify() {
    $HAS_SPOTIFY && { print_warn "Spotify já instalado"; return; }
    run_silent "Spotify (flatpak)" flatpak_install com.spotify.Client
}

install_spicetify() {
    $HAS_SPICETIFY && { print_warn "spicetify já instalado"; return; }
    run_silent "spicetify-cli" bash -c \
        "curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sudo -u $REAL_USER sh"
    # Permissão pra Spotify flatpak
    local spotify_path="$REAL_HOME/.var/app/com.spotify.Client/config/spotify"
    [[ -d "$spotify_path" ]] && chmod a+wr "$spotify_path" -R 2>/dev/null || true
    as_user spicetify backup apply >> "$LOG_FILE" 2>&1 || true
    print_ok "Spicetify configurado"
}

install_gh_desktop() {
    $HAS_GH_DESKTOP && { print_warn "GitHub Desktop+ já instalado"; return; }
    run_silent "GitHub Desktop+ (flatpak)" flatpak_install io.github.pol_rivero.github-desktop-plus
}

install_vscode() {
    $HAS_VSCODE && { print_warn "VS Code já instalado"; return; }
    run_silent "vscode repo" bash -c "
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main' \
            > /etc/apt/sources.list.d/vscode.list
        apt-get update -qq
    "
    run_silent "VS Code" apt_install code
}

install_jetbrains() {
    $HAS_JETBRAINS && { print_warn "JetBrains Toolbox já instalado"; return; }
    run_silent "JetBrains Toolbox" bash -c "
        cd /tmp
        wget -q 'https://data.services.jetbrains.com/products/download?platform=linux&code=TBA' -O jetbrains-toolbox.tar.gz 2>/dev/null || \
        curl -sL 'https://data.services.jetbrains.com/products/download?platform=linux&code=TBA' -o jetbrains-toolbox.tar.gz
        mkdir -p jb_toolbox && tar -xzf jetbrains-toolbox.tar.gz -C jb_toolbox --strip-components=1
        cp jb_toolbox/jetbrains-toolbox /usr/local/bin/
        rm -rf jb_toolbox jetbrains-toolbox.tar.gz
    "
    print_warn "Execute 'jetbrains-toolbox' para iniciar e instalar IDEs"
}

install_unity() {
    $HAS_UNITY && { print_warn "Unity Hub já instalado"; return; }
    run_silent "Unity Hub repo" bash -c "
        wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor > /usr/share/keyrings/Unity_Technologies_ApS.gpg
        echo 'deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main' \
            > /etc/apt/sources.list.d/unityhub.list
        apt-get update -qq
    "
    run_silent "Unity Hub" apt_install unityhub
}

install_steam() {
    $HAS_STEAM && { print_warn "Steam já instalado"; return; }
    run_silent "multiarch i386" dpkg --add-architecture i386
    run_silent "apt update" apt-get update -qq
    run_silent "Steam" bash -c "
        wget -qO /tmp/steam.deb 'https://cdn.akamai.steamstatic.com/client/installer/steam.deb'
        DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/steam.deb
        rm -f /tmp/steam.deb
    "
}

install_heroic() {
    $HAS_HEROIC && { print_warn "Heroic já instalado"; return; }
    run_silent "Heroic (flatpak)" flatpak_install com.heroicgameslauncher.hgl
}

install_nvidia() {
    print_step "Detectando GPU NVIDIA..."
    local card
    card=$(lspci 2>/dev/null | grep -i nvidia | head -1 || echo "")
    print_step "Placa: $card"

    run_silent "ubuntu-drivers" apt_install ubuntu-drivers-common 2>/dev/null || true

    # Tenta instalar driver recomendado automaticamente
    if has ubuntu-drivers; then
        run_silent "driver NVIDIA (auto)" ubuntu-drivers autoinstall
    else
        run_silent "nvidia-driver" apt_install nvidia-driver-535 nvidia-utils-535
    fi

    run_silent "vulkan nvidia" apt_install libvulkan1 vulkan-tools

    print_warn "Reinicie o sistema para ativar os drivers NVIDIA"
}

install_amd_gpu() {
    run_silent "AMD GPU — mesa + vulkan" apt_install \
        mesa-vulkan-drivers libvulkan1 vulkan-tools \
        mesa-utils va-driver-all
}

install_fix_mic() {
    print_step "Configurando cancelamento de ruído do microfone..."

    # Instala PulseAudio com noise cancel
    run_silent "pulseaudio noise cancel" apt_install pulseaudio-equalizer 2>/dev/null || true
    run_silent "pipewire noise cancel" apt_install pipewire-audio-client-libraries 2>/dev/null || true

    # Cria config de noise cancellation
    local pa_conf="$REAL_HOME/.config/pipewire/pipewire.conf.d"
    as_user mkdir -p "$pa_conf"

    cat > "$pa_conf/99-mic-noise-cancel.conf" << 'EOF'
context.modules = [
    {   name = libpipewire-module-filter-chain
        args = {
            node.description = "Noise Canceling source"
            media.name       = "Noise Canceling source"
            filter.graph = {
                nodes = [
                    {
                        type   = ladspa
                        name   = rnnoise
                        plugin = librnnoise_ladspa
                        label  = noise_suppressor_mono
                        control = {
                            "VAD Threshold (%)" = 50.0
                        }
                    }
                ]
            }
            capture.props = {
                node.name      = "capture.rnnoise_source"
                node.passive   = true
                audio.rate     = 48000
            }
            playback.props = {
                media.class  = Audio/Source
                node.name    = "rnnoise_source"
                audio.rate   = 48000
            }
        }
    }
]
EOF

    chown -R "$REAL_USER:$REAL_USER" "$pa_conf"

    # Instala rnnoise
    run_silent "rnnoise ladspa" apt_install ladspa-sdk 2>/dev/null || true
    wget -q "https://github.com/werman/noise-suppression-for-voice/releases/latest/download/linux.tar.gz" \
        -O /tmp/rnnoise.tar.gz >> "$LOG_FILE" 2>&1 && \
        tar -xzf /tmp/rnnoise.tar.gz -C /tmp >> "$LOG_FILE" 2>&1 && \
        cp /tmp/linux/ladspa/librnnoise_ladspa.so /usr/lib/ladspa/ >> "$LOG_FILE" 2>&1 || \
        print_warn "rnnoise não instalado — microfone básico configurado"

    rm -f /tmp/rnnoise.tar.gz
    print_ok "Configuração de microfone aplicada"
    print_warn "Selecione 'Noise Canceling source' nas configurações de áudio"
}

install_tweaks() {
    print_step "Aplicando tweaks de performance..."

    # Swappiness
    echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
    sysctl --system >> "$LOG_FILE" 2>&1

    # IRQ Balance
    apt_install irqbalance >> "$LOG_FILE" 2>&1 || true
    systemctl enable --now irqbalance >> "$LOG_FILE" 2>&1 || true

    # EarlyOOM
    apt_install earlyoom >> "$LOG_FILE" 2>&1 || true
    systemctl enable --now earlyoom >> "$LOG_FILE" 2>&1 || true

    # Preload
    apt_install preload >> "$LOG_FILE" 2>&1 || true
    systemctl enable --now preload >> "$LOG_FILE" 2>&1 || true

    print_ok "Tweaks aplicados: swappiness=10, irqbalance, earlyoom, preload"
}

install_codecs() {
    run_silent "codecs multimedia" apt_install \
        ubuntu-restricted-extras 2>/dev/null || \
    apt_install \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-plugins-good \
        gstreamer1.0-libav \
        libavcodec-extra \
        libdvd-pkg 2>/dev/null || true
    print_ok "Codecs instalados"
}

run_key() {
    case "$1" in
        base)        install_base ;;
        zsh)         install_zsh ;;
        nvim)        install_nvim ;;
        kitty)       install_kitty ;;
        fonts)       install_fonts ;;
        ffmpeg)      install_ffmpeg ;;
        gh)          install_gh ;;
        flatpak)     install_flatpak ;;
        brave)       install_brave ;;
        vesktop)     install_vesktop ;;
        spotify)     install_spotify ;;
        spicetify)   install_spicetify ;;
        gh_desktop)  install_gh_desktop ;;
        vscode)      install_vscode ;;
        jetbrains)   install_jetbrains ;;
        unity)       install_unity ;;
        steam)       install_steam ;;
        heroic)      install_heroic ;;
        nvidia)      install_nvidia ;;
        amd_gpu)     install_amd_gpu ;;
        fix_mic)     install_fix_mic ;;
        tweaks)      install_tweaks ;;
        codecs)      install_codecs ;;
    esac
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    if [[ "$PKG_MANAGER" != "apt" ]]; then
        echo "  ${yellow}Aviso:${reset} Este instalador é otimizado para apt (Mint/Ubuntu/Debian)."
        echo "  Detectado: $PKG_MANAGER — alguns módulos podem não funcionar."
        echo
        printf "  Continuar mesmo assim? [S/n] "; read -r ans
        [[ "${ans,,}" == "n" ]] && exit 0
    fi

    clear; echo; echo "  Detectando sistema..."
    detect_system
    show_banner
    bootstrap
    build_catalog

    echo "  ${dim}Pressione ENTER para abrir o seletor...${reset}"
    read -r

    run_selector || { echo "  Cancelado."; exit 0; }
    [[ ${#CHOSEN_KEYS[@]} -eq 0 ]] && { echo "  Nada selecionado."; exit 0; }

    clear; echo
    echo "  ${bold}Itens selecionados:${reset}"
    print_sep
    for k in "${CHOSEN_KEYS[@]}"; do echo "  ${cyan}+${reset}  $k"; done
    print_sep; echo
    printf "  Instalar agora? [S/n] "; read -r ans
    [[ "${ans,,}" == "n" ]] && { echo "  Cancelado."; exit 0; }

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
    echo "  ${bold}Concluído${reset}"
    print_sep
    echo "  ${green}ok${reset}   $((${#CHOSEN_KEYS[@]} - ${#failed[@]})) / ${#CHOSEN_KEYS[@]} instalados"
    [[ ${#failed[@]} -gt 0 ]] && {
        echo "  ${red}!!${reset}   ${#failed[@]} falha(s):"
        for f in "${failed[@]}"; do echo "       ${gray}- $f${reset}"; done
        echo "  ${dim}log completo: $LOG_FILE${reset}"
    }
    echo
    print_warn "Recomendado: reinicie o sistema após o setup"
    echo
}

main "$@"