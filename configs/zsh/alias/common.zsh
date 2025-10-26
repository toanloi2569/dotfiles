alias vi='nvim'

alias lzd='docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock -v /yourpath/config:/.config/jesseduffield/lazydocker lazyteam/lazydocker'
alias swk='echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias offmcafee='sudo /opt/McAfee/ens/tp/init/mfetpd-control.sh stop & sudo /opt/McAfee/ens/esp/init/mfeespd-control.sh stop'
alias ssh-hosts="grep -P \"^Host ([^*]+)$\" $HOME/.ssh/config | sed 's/Host //'"

# zsh
alias openzs="open ~/.zshrc"
alias sourcezs="source ~/.zshrc"
alias vizs="nvim ~/.zshrc"

# docker
alias dps='docker ps -a'
alias dim='docker images'
alias dcb='docker compose build'
alias dcu='docker compose up -d'
alias dcd='docker compose down'

alias clog='logcolor'

alias kctx='kubectx'
alias kns='kubens'

alias vihost='sudo nvim /etc/hosts'