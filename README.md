<div align="center">

# 🌙 dotfiles

**Arch Linux · Hyprland · Kitty · Zsh · DankMaterialShell**

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=black)
![Zsh](https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)

</div>

---

## 📦 O que está incluído

| Componente | Descrição |
|---|---|
| `.zshrc` | Shell com zinit, powerlevel10k, autosuggestions, syntax highlighting |
| `install.sh` | Instalador interativo com checklist |

---

## 🔧 Dependências

Antes de instalar, você precisa de:

- **Arch Linux** (ou derivado)
- **git** — para clonar o repo
- **stow** — para criar os symlinks
- **yay** — para pacotes do AUR (instalado automaticamente pelo `install.sh` se não tiver)

---

## 🚀 Instalação rápida

```bash
git clone https://github.com/Natteens/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

O instalador vai te mostrar uma checklist com tudo que pode ser instalado. Você escolhe o que quiser.

---

## 📋 O que o instalador oferece

```
[ ] Pacotes base         — git, nano, make, cmake, base-devel
[ ] zsh + zinit          — shell, gerenciador de plugins, fzf, zoxide
[ ] neovim               — editor de texto
[ ] fresh-editor         — editor minimalista (AUR)
[ ] fish                 — shell alternativo
[ ] Wallpapers           — clona ~/Pictures/Wallpapers do GitHub
[ ] Symlinks via stow    — aplica os dotfiles no sistema
```

---

## 🐚 Shell (zsh)

Configurado com:

- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)** — prompt customizável com wizard interativo
- **[zinit](https://github.com/zdharma-continuum/zinit)** — gerenciador de plugins rápido
- **zsh-autosuggestions** — sugestões inline baseadas no histórico
- **zsh-syntax-highlighting** — coloração de comandos em tempo real
- **zsh-completions** — completions extras
- **fzf-tab** — menu de completion com fuzzy search
- **fzf** — fuzzy finder geral
- **zoxide** — navegação inteligente de diretórios (`cd` turbinado)

Para reconfigurar o prompt a qualquer momento:

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

## 🔗 Symlinks

Os dotfiles são gerenciados com [GNU Stow](https://www.gnu.org/software/stow/). Para aplicar manualmente:

```bash
cd ~/dotfiles
stow .
```

Para remover os symlinks:

```bash
stow -D .
```

---

## 📁 Estrutura

```
dotfiles/
├── .zshrc          # Configuração do zsh
├── install.sh      # Instalador interativo
└── README.md
```

---

<div align="center">
  <sub>feito por <a href="https://github.com/Natteens">Natteens</a></sub>
</div>