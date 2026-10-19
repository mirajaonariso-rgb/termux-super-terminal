#!/data/data/com.termux/files/usr/bin/bash
# Super terminal Termux : zsh + suggestions temps réel + explication d'erreurs + correction
set -e

pkg update -y && pkg upgrade -y
pkg install -y zsh git curl python fzf zoxide eza bat starship

mkdir -p ~/.zsh ~/.config
clone() { [ -d ~/.zsh/$2 ] || git clone --depth 1 https://github.com/$1/$2 ~/.zsh/$2; }
clone zsh-users zsh-autosuggestions
clone zsh-users zsh-syntax-highlighting
clone zsh-users zsh-completions

# Prompt sans besoin de police spéciale
starship preset plain-text-symbols -o ~/.config/starship.toml

cat > ~/.zshrc <<'EOF'
# ---------- Historique ----------
HISTFILE=~/.zsh_history; HISTSIZE=50000; SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE AUTO_CD

# ---------- Complétion ----------
fpath=(~/.zsh/zsh-completions/src $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ---------- Suggestions temps réel + couleurs ----------
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
bindkey '^[[C' forward-char        # flèche droite = accepter la suggestion

# ---------- Alias ----------
alias ls='eza --group-directories-first'
alias ll='eza -lah --git'
alias cat='bat --paging=never'
alias maj='pkg update -y && pkg upgrade -y'
alias ..='cd ..'

eval "$(zoxide init zsh)"
source <(fzf --zsh) 2>/dev/null     # Ctrl+R = recherche floue

# ---------- Détecteur d'erreurs + correction ----------
autoload -Uz add-zsh-hook
typeset -g _last_cmd=""
_err_preexec() { _last_cmd="$1" }
_err_precmd() {
  local code=$?
  local cmd="$_last_cmd"; _last_cmd=""
  [[ -z $cmd || $code -eq 0 || $code -eq 130 ]] && return $code

  local first=${${(z)cmd}[1]}
  local msg fix=""

  case $code in
    127)
      msg="Commande introuvable : '$first'."
      local guess
      guess=$(python3 -c "import difflib,sys;print(''.join(difflib.get_close_matches(sys.argv[1],sys.argv[2:],1,0.6)))" \
              "$first" ${(k)commands} ${(k)aliases} ${(k)builtins} 2>/dev/null)
      if [[ -n $guess ]]; then
        msg+=" Faute de frappe probable, tu voulais écrire '$guess' ?"
        fix="${guess}${cmd:${#first}}"
      else
        msg+=" Pas installée ? Essaie : pkg search $first"
      fi ;;
    126)
      msg="Permission refusée : le fichier n'est pas exécutable."
      fix="chmod +x $first && $cmd" ;;
    2)   msg="Mauvaise utilisation : argument ou option invalide. Essaie '$first --help'." ;;
    1)   msg="Erreur générale : lis le message juste au-dessus pour le détail." ;;
    137) msg="Processus tué (Android a coupé Termux ou mémoire pleine)." ;;
    139) msg="Segmentation fault : le programme a planté (bug ou paquet incompatible)." ;;
    *)   msg="La commande a échoué (code $code)." ;;
  esac

  print -P "%F{red}✗ ${msg}%f"
  if [[ -n $fix ]]; then
    print -nP "%F{yellow}Corriger et lancer « ${fix} » ? [o/N] %f"
    local ans; read -k1 ans; print
    if [[ $ans == [oOyY] ]]; then
      print -s -- "$fix"
      eval "$fix"
    fi
  fi
  return $code
}
add-zsh-hook preexec _err_preexec
add-zsh-hook precmd  _err_precmd

# ---------- Prompt (en dernier) ----------
eval "$(starship init zsh)"
EOF

chsh -s zsh
echo "✅ Terminé. Ferme et rouvre Termux."
