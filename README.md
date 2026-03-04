<div align="center">

# 🌙 dotfiles

**Linux · Zsh · Kitty · EasyEffects · Hyprland**

![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Zsh](https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=black)

</div>

---

## 📦 O que está incluído

| Arquivo | Descrição |
|---|---|
| `.zshrc` | Shell com zinit, powerlevel10k, autosuggestions, syntax highlighting |
| `setup.sh` | Instalador interativo — Linux Mint / Ubuntu / Debian |
| `install.sh` | Instalador interativo — Arch Linux |
| `fix_mic.sh` | Corrige boost excessivo de microfone via ALSA |
| `preset_mic.json` | Preset de microfone para EasyEffects |

---

## 🚀 Instalação rápida

### Linux Mint / Ubuntu / Debian
```bash
git clone https://github.com/Natteens/dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo bash setup.sh
```

### Arch Linux
```bash
git clone https://github.com/Natteens/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

O instalador detecta o que já está instalado, mostra uma checklist e instala só o que você escolher.

---

## 🔧 Dependências

### Linux Mint / Ubuntu
O `setup.sh` instala as dependências automaticamente. Só precisa de:
- **git** — para clonar o repo
- **sudo** — para instalar pacotes

### Arch Linux
- **git** — para clonar o repo
- **stow** — para criar os symlinks
- **yay** — instalado automaticamente pelo `install.sh`

---

## 📋 O que o instalador oferece

### setup.sh (Mint/Ubuntu)
```
[ ] Pacotes base         — build-essential, curl, wget, git
[ ] Zsh                  — shell + fzf + zoxide
[ ] Neovim               — editor
[ ] Kitty                — terminal
[ ] Fontes               — JetBrains Mono Nerd + Noto
[ ] FFmpeg               — codecs + mídia
[ ] GitHub CLI           — + openssh
[ ] Flatpak              — + Flathub
[ ] Brave                — browser
[ ] Vesktop              — Discord + Vencord (flatpak)
[ ] Spotify              — flatpak
[ ] Spicetify            — tema pro Spotify
[ ] GitHub Desktop+      — flatpak
[ ] VS Code              — editor
[ ] JetBrains Toolbox    — IDEs
[ ] Unity Hub            — game engine
[ ] Steam                — plataforma de jogos
[ ] Heroic               — Epic / GOG (flatpak)
[ ] NVIDIA               — driver proprietário
[ ] AMD GPU              — mesa + vulkan
[ ] EasyEffects          — áudio + preset de microfone
[ ] Fix Microfone        — corrige boost via ALSA
[ ] Tweaks sistema       — swappiness + performance
[ ] Codecs               — mp3, h264, aac, etc
```

---

## 🎙️ Microfone

O repositório inclui dois recursos para corrigir problemas de microfone:

**`fix_mic.sh`** — Corrige boost excessivo de microfone via ALSA (hardware):
```bash
bash fix_mic.sh
```

**`preset_mic.json`** — Preset para EasyEffects com:
- RNNoise — cancelamento de ruído neural
- DeepFilterNet — filtro de ruído avançado
- Gate — corta som abaixo de um threshold
- Equalizer — EQ de 5 bandas otimizado para voz
- Compressor — controla picos de volume
- De-esser — reduz sibilância
- Limiter — evita clipping

O `setup.sh` instala o EasyEffects e aplica o preset automaticamente.

---

## 🐚 Shell (zsh)

Configurado com:
- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)** — prompt customizável
- **[zinit](https://github.com/zdharma-continuum/zinit)** — gerenciador de plugins rápido
- **zsh-autosuggestions** — sugestões inline baseadas no histórico
- **zsh-syntax-highlighting** — coloração de comandos em tempo real
- **zsh-completions** — completions extras
- **fzf-tab** — menu de completion com fuzzy search
- **fzf** — fuzzy finder geral
- **zoxide** — navegação inteligente de diretórios

Para reconfigurar o prompt:
```bash
p10k configure
```

---

## 🖼️ Wallpapers

Os wallpapers ficam em `~/Pictures/Wallpapers` e são clonados de:
```
https://github.com/Natteens/Wallpapers
```

---

## 🔗 Symlinks (Arch)

Os dotfiles são gerenciados com [GNU Stow](https://www.gnu.org/software/stow/):

```bash
cd ~/dotfiles
stow .
```

Para remover:
```bash
stow -D .
```

---

## 📁 Estrutura

```
dotfiles/
├── .zshrc              # Configuração do zsh
├── install.sh          # Instalador — Arch Linux
├── setup.sh            # Instalador — Linux Mint / Ubuntu
├── fix_mic.sh          # Corrige boost de microfone
├── preset_mic.json     # Preset EasyEffects para microfone
└── README.md
```

---

<div align="center">
<sub>feito por <a href="https://github.com/Natteens">Natteens</a></sub>
</div>