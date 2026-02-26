#!/usr/bin/env bash
# ==============================================================================
#  Natteens Dotfiles Installer  —  Arch Linux
#  whiptail TUI — seta pra navegar, espaco pra marcar, enter pra confirmar
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPERS_REPO="https://github.com/Natteens/Wallpapers.git"
WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
LOG_FILE="/tmp/dotfiles-install.log"
TMPDIR_YAY=""

# ── Colors ─────────────────────────────────────────────────────────────────────
bold=$'\e[1m'; dim=$'\e[2m'; reset=$'\e[0m'
red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'
blue=$'\e[34m'; cyan=$'\e[36m'; gray=$'\e[90m'

# ── Output ─────────────────────────────────────────────────────────────────────
print_step() { echo "  ${cyan}::${reset} $*"; }
print_ok()   { echo "  ${green}ok${reset}  $*"; }
print_warn() { echo "  ${yellow}!!${reset}  $*"; }
print_err()  { echo "  ${red}xx${reset}  $*" >&2; }
print_log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Spinner ────────────────────────────────────────────────────────────────────
_spin_pid=""
spinner_start() {
    local msg="$1"
    ( local f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
      while true; do
          printf "\r  ${cyan}%s${reset}  %s " "${f:$((i%10)):1}" "$msg"
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
has()        { command -v "$1" &>/dev/null; }
pkg_exists() { pacman -Qi "$1" &>/dev/null 2>&1; }
pacman_install() { print_log "pacman: $*"; sudo pacman -S --needed --noconfirm "$@" >> "$LOG_FILE" 2>&1; }
aur_install()    { print_log "yay: $*";    yay    -S --needed --noconfirm "$@" >> "$LOG_FILE" 2>&1; }

# ── Detection ──────────────────────────────────────────────────────────────────
detect_system() {
    HAS_YAY=false;     has yay              && HAS_YAY=true     || true
    HAS_ZSH=false;     has zsh              && HAS_ZSH=true     || true
    HAS_NVIM=false;    has nvim             && HAS_NVIM=true    || true
    HAS_KITTY=false;   has kitty            && HAS_KITTY=true   || true
    HAS_FLATPAK=false; has flatpak          && HAS_FLATPAK=true || true
    HAS_STOW=false;    has stow             && HAS_STOW=true    || true
    HAS_GH=false;      has gh               && HAS_GH=true      || true
    HAS_BRAVE=false;   pkg_exists brave-bin && HAS_BRAVE=true   || true
    HAS_STEAM=false;   pkg_exists steam     && HAS_STEAM=true   || true
    HAS_SDDM=false;    pkg_exists sddm      && HAS_SDDM=true    || true
    HAS_DMS=false;     has dms              && HAS_DMS=true     || true
    GPU_NVIDIA=false;  lspci 2>/dev/null | grep -qi 'nvidia'            && GPU_NVIDIA=true || true
    GPU_AMD=false;     lspci 2>/dev/null | grep -qi 'amd\|radeon\|ati'  && GPU_AMD=true   || true
}

# ── Bootstrap ──────────────────────────────────────────────────────────────────
check_arch() { [[ -f /etc/arch-release ]] || { echo "Apenas Arch Linux."; exit 1; }; }

ensure_whiptail() {
    has whiptail && return
    echo "  Instalando whiptail..."
    sudo pacman -S --needed --noconfirm libnewt >> "$LOG_FILE" 2>&1
}

ensure_yay() {
    has yay && return
    print_step "yay nao encontrado — instalando..."
    pacman_install git base-devel
    TMPDIR_YAY=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TMPDIR_YAY/yay" >> "$LOG_FILE" 2>&1
    (cd "$TMPDIR_YAY/yay" && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1)
    rm -rf "$TMPDIR_YAY"
    print_ok "yay instalado."
}

# ── Banner ─────────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo
    echo "  ${bold}Natteens Dotfiles Installer${reset}  —  Arch Linux"
    echo "  ${dim}─────────────────────────────────────────${reset}"
    echo

    local gpu=""
    $GPU_NVIDIA && gpu+="NVIDIA "
    $GPU_AMD    && gpu+="AMD"
    [[ -z "$gpu" ]] && gpu="nenhuma detectada"

    echo "  ${dim}GPU    ${reset}${cyan}${gpu}${reset}"
    echo "  ${dim}Shell  ${reset}$(  $HAS_ZSH && echo "${cyan}zsh${reset} ${dim}(instalado)${reset}" || echo "${gray}bash${reset}")"
    echo "  ${dim}yay    ${reset}$(  $HAS_YAY && echo "${green}ok${reset}"                           || echo "${gray}nao encontrado${reset}")"
    echo
    echo "  ${dim}─────────────────────────────────────────${reset}"
    echo
    echo "  ${dim}Seta pra navegar  ESPACO pra marcar  ENTER pra confirmar${reset}"
    echo
}

# ── whiptail checklist ─────────────────────────────────────────────────────────
# Builds a single checklist with all items grouped by category
# Returns selected keys via stdout
run_checklist() {
    # whiptail checklist args: tag item status
    # We use "---CAT---" tags as visual separators (non-selectable via grep later)
    local -a wt_args=()

    st() { $1 && echo ON || echo OFF; }  # installed -> ON (pre-checked)

    wt_args+=(
        # ── Base & Shell ──────────────────────────────────────────────────
        "SEP_BASE"  "──── Base & Shell ────────────────────────────" OFF
        "base"      "Pacotes base       git make cmake curl wget"    OFF
        "zsh"       "Zsh                zsh + fzf + zoxide"          "$(st $HAS_ZSH)"
        "nvim"      "Neovim             editor"                      "$(st $HAS_NVIM)"
        "fresh"     "fresh-editor       editor minimalista (AUR)"    OFF
        "kitty"     "Kitty              terminal"                     "$(st $HAS_KITTY)"
        "fonts"     "Fontes             JetBrains Mono Nerd + Noto"  OFF
        "qt"        "Qt5 / Qt6          wayland support"             OFF
        "sddm"      "SDDM               display manager"             "$(st $HAS_SDDM)"
        "flatpak"   "Flatpak            + Flathub remote"            "$(st $HAS_FLATPAK)"
        "gh"        "GitHub CLI         + openssh + auth"            "$(st $HAS_GH)"
        "dms"       "DankMaterialShell  desktop shell wayland"       "$(st $HAS_DMS)"
        # ── Apps ─────────────────────────────────────────────────────────
        "SEP_APPS"  "──── Apps ────────────────────────────────────" OFF
        "brave"     "Brave              browser"                     "$(st $HAS_BRAVE)"
        "vesktop"   "Vesktop            Discord client"              OFF
        "spotify"   "Spotify            + Spicetify"                 OFF
        "jetbrains" "JetBrains Toolbox  gerenciador de IDEs"         OFF
        "unity"     "Unity Hub          game engine manager"         OFF
        # ── Games ────────────────────────────────────────────────────────
        "SEP_GAMES" "──── Games ───────────────────────────────────" OFF
        "steam"     "Steam              plataforma de jogos"         "$(st $HAS_STEAM)"
        "heroic"    "Heroic             Epic / GOG launcher"         OFF
        # ── Drivers ──────────────────────────────────────────────────────
        "SEP_DRV"   "──── Drivers de Video ────────────────────────" OFF
        "nvidia"    "NVIDIA             proprietario + lib32"        OFF
        "amd"       "AMD                mesa + vulkan-radeon"        OFF
        # ── Dotfiles ─────────────────────────────────────────────────────
        "SEP_DOT"   "──── Dotfiles ────────────────────────────────" OFF
        "wallpapers" "Wallpapers         -> ~/Pictures/Wallpapers"   OFF
        "symlinks"  "Symlinks           aplicar dotfiles via stow"   OFF
    )

    local result
    result=$(whiptail \
        --title " Natteens Dotfiles Installer " \
        --checklist "\nSELECIONE OS ITENS PARA INSTALAR\n\nSeta = navegar   Espaco = marcar/desmarcar   Tab = botoes   Enter = confirmar" \
        30 72 20 \
        "${wt_args[@]}" \
        3>&1 1>&2 2>&3) || return 1

    # Parse result — whiptail returns quoted strings
    echo "$result" | tr -d '"' | tr ' ' '\n' | grep -v '^SEP_'
}

# ══════════════════════════════════════════════════════════════════════════════
#  INSTALL MODULES
# ══════════════════════════════════════════════════════════════════════════════

install_base() { run_silent "pacotes base" pacman_install git nano base-devel make cmake curl wget unzip; }

install_zsh() {
    local pkgs=()
    has zsh    || pkgs+=(zsh)
    has zoxide || pkgs+=(zoxide)
    has fzf    || pkgs+=(fzf)
    [[ ${#pkgs[@]} -gt 0 ]] && run_silent "zsh + zoxide + fzf" pacman_install "${pkgs[@]}"
    grep -q "/usr/bin/zsh" /etc/shells 2>/dev/null || echo "/usr/bin/zsh" | sudo tee -a /etc/shells >> "$LOG_FILE"
    chsh -s /usr/bin/zsh && print_ok "zsh = shell padrao" || print_warn "rode 'chsh -s /usr/bin/zsh' manualmente"
}

install_nvim()  { $HAS_NVIM && { print_warn "neovim ja instalado"; return; }; run_silent "neovim" pacman_install neovim; }
install_fresh() { pkg_exists fresh-editor && { print_warn "fresh-editor ja instalado"; return; }; run_silent "fresh-editor" aur_install fresh-editor; }
install_kitty() {
    $HAS_KITTY && { print_warn "kitty ja instalado"; return; }
    run_silent "kitty" pacman_install kitty
    mkdir -p "$HOME/.config/kitty"
    grep -q "shell /usr/bin/zsh" "$HOME/.config/kitty/kitty.conf" 2>/dev/null \
        || echo "shell /usr/bin/zsh" >> "$HOME/.config/kitty/kitty.conf"
}
install_fonts() {
    pkg_exists ttf-jetbrains-mono-nerd \
        && print_warn "JetBrains Mono Nerd ja instalado" \
        || run_silent "JetBrains Mono Nerd" aur_install ttf-jetbrains-mono-nerd
    run_silent "Noto Fonts + Emoji" pacman_install noto-fonts noto-fonts-emoji
}
install_qt()      { run_silent "Qt5 + Qt6 + Wayland" pacman_install qt5-base qt6-base qt5-wayland qt6-wayland; }
install_sddm()    { $HAS_SDDM || run_silent "sddm" pacman_install sddm; run_silent "habilitar sddm" sudo systemctl enable sddm; }
install_flatpak() {
    $HAS_FLATPAK || run_silent "flatpak" pacman_install flatpak
    run_silent "Flathub" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}
install_gh() {
    $HAS_GH || run_silent "github-cli + openssh" pacman_install github-cli openssh
    print_step "Autenticando GitHub..."
    gh auth login && print_ok "GitHub CLI autenticado."
}
install_dms()       { $HAS_DMS && { print_warn "DMS ja instalado"; return; }; run_silent "DankMaterialShell" aur_install dms-shell-bin; }
install_brave()     { $HAS_BRAVE && { print_warn "Brave ja instalado"; return; }; run_silent "Brave" aur_install brave-bin; }
install_vesktop()   { pkg_exists vesktop-bin && { print_warn "Vesktop ja instalado"; return; }; run_silent "Vesktop" aur_install vesktop-bin; }
install_spotify() {
    pkg_exists spotify || run_silent "Spotify" aur_install spotify
    has spicetify && { print_warn "spicetify ja instalado"; return; }
    run_silent "spicetify-cli" aur_install spicetify-cli
    sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R 2>/dev/null || true
    spicetify backup apply >> "$LOG_FILE" 2>&1 || true
}
install_jetbrains() { pkg_exists jetbrains-toolbox && { print_warn "JetBrains ja instalado"; return; }; run_silent "JetBrains Toolbox" aur_install jetbrains-toolbox; }
install_unity()     { pkg_exists unityhub && { print_warn "Unity Hub ja instalado"; return; }; run_silent "Unity Hub" aur_install unityhub; }
install_steam() {
    $HAS_STEAM && { print_warn "Steam ja instalado"; return; }
    grep -q "^\[multilib\]" /etc/pacman.conf || {
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >> "$LOG_FILE"
        sudo pacman -Sy >> "$LOG_FILE" 2>&1
    }
    run_silent "Steam" pacman_install steam
}
install_heroic()    { pkg_exists heroic-games-launcher-bin && { print_warn "Heroic ja instalado"; return; }; run_silent "Heroic" aur_install heroic-games-launcher-bin; }
install_nvidia() {
    run_silent "NVIDIA drivers" pacman_install nvidia nvidia-utils nvidia-settings lib32-nvidia-utils
    grep -q "nvidia_drm" /etc/mkinitcpio.conf 2>/dev/null || {
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        run_silent "mkinitcpio" sudo mkinitcpio -P
    }
    print_warn "Reinicie para ativar os drivers NVIDIA."
}
install_amd()        { run_silent "AMD drivers" pacman_install mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver; }
install_wallpapers() {
    mkdir -p "$HOME/Pictures"
    [[ -d "$WALLPAPERS_DIR" ]] \
        && run_silent "atualizando wallpapers" git -C "$WALLPAPERS_DIR" pull \
        || run_silent "clonando wallpapers"   git clone "$WALLPAPERS_REPO" "$WALLPAPERS_DIR"
}
install_symlinks() {
    $HAS_STOW || run_silent "stow" pacman_install stow
    cd "$DOTFILES_DIR"
    run_silent "symlinks via stow" stow --adopt .
}

run_key() {
    case "$1" in
        base)       install_base ;;       zsh)        install_zsh ;;
        nvim)       install_nvim ;;       fresh)      install_fresh ;;
        kitty)      install_kitty ;;      fonts)      install_fonts ;;
        qt)         install_qt ;;         sddm)       install_sddm ;;
        flatpak)    install_flatpak ;;    gh)         install_gh ;;
        dms)        install_dms ;;        brave)      install_brave ;;
        vesktop)    install_vesktop ;;    spotify)    install_spotify ;;
        jetbrains)  install_jetbrains ;;  unity)      install_unity ;;
        steam)      install_steam ;;      heroic)     install_heroic ;;
        nvidia)     install_nvidia ;;     amd)        install_amd ;;
        wallpapers) install_wallpapers ;; symlinks)   install_symlinks ;;
    esac
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
cleanup() {
    spinner_stop
    [[ -n "$TMPDIR_YAY" && -d "$TMPDIR_YAY" ]] && rm -rf "$TMPDIR_YAY" || true
}
trap cleanup EXIT

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    check_arch
    : > "$LOG_FILE"
    clear; echo; echo "  Detectando sistema..."
    detect_system
    ensure_whiptail
    ensure_yay
    show_banner
    sleep 0.3

    # Selection via whiptail
    local selected
    selected=$(run_checklist) || { echo "  Cancelado."; exit 0; }

    local -a keys=()
    while IFS= read -r k; do
        [[ -n "$k" ]] && keys+=("$k")
    done <<< "$selected"

    [[ ${#keys[@]} -eq 0 ]] && { echo "  Nada selecionado."; exit 0; }

    # Confirm
    local list=""
    for k in "${keys[@]}"; do list+="  + $k\n"; done
    whiptail --title " Confirmar instalacao " \
        --yesno "\nInstalar os seguintes itens?\n\n${list}\n" \
        20 50 || { echo "  Cancelado."; exit 0; }

    # Install
    clear; echo
    echo "  ${bold}Instalando...${reset}"; echo

    local failed=()
    for key in "${keys[@]}"; do
        echo "  ${blue}──${reset} ${bold}$key${reset}"
        run_key "$key" || failed+=("$key")
        echo
    done

    # Summary
    echo "  ${bold}Concluido${reset}"
    echo "  ${dim}─────────────────────────────────────────${reset}"
    echo "  ${green}ok${reset}   $((${#keys[@]} - ${#failed[@]})) / ${#keys[@]} itens instalados"
    [[ ${#failed[@]} -gt 0 ]] && echo "  ${red}!!${reset}   ${#failed[@]} falha(s) — ver $LOG_FILE"
    echo "  ${dim}log: $LOG_FILE${reset}"
    echo
}

main "$@"
