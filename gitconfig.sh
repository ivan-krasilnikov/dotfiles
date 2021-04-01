#!/bin/bash
source ~/.dotfiles/setup.lib.sh

cat <<EOF
# Autogenerated by ~/.dotfiles/gitconfig.sh

[user]
	name = ${SCM_NAME}
	email = ${SCM_EMAIL}

[alias]
	amend = commit --amend
	br = branch
	ci = commit
	cia = commit --amend
	caa = commit -a --amend
	co = checkout
	cp = cherry-pick
	detach = !git checkout HEAD^0
	diffh = diff HEAD
	g = !gitg
	lg = log --pretty=oneline --abbrev-commit --decorate
	pp = !git pull && git push
	root = rev-parse --show-toplevel
	st = status
	unstage = reset HEAD --

	# git gc with pruning. add --aggressive for more effect.
	gca = !git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 \
	        -c gc.rerereresolved=0 -c gc.rerereunresolved=0 \
	        -c gc.pruneExpire=now gc --prune=now

[color]
	ui = auto

[core]
	pager = less -FSRXi

EOF

if [[ -d /usr/share/git-core/templates/branches/ &&
      "$(ls -A /usr/share/git-core/templates/branches/)" == "" ]]; then
  echo "[init]"
  echo "	# Point to an empty directory to avoid copying sample hooks to every repo."
  echo "	# Look for sample hooks in /usr/share/git-core/templates/hooks/"
  echo "	templateDir = /usr/share/git-core/templates/branches/"
  echo
fi

cat <<EOF
[pull]
	ff = only
	rebase = false

[push]
	default = matching

[url "git@github.com:"]
	pushInsteadOf = "git://github.com/"
	pushInsteadOf = "https://github.com/"

[url "git@gist.github.com:"]
	pushInsteadOf = "git://gist.github.com/"
EOF
