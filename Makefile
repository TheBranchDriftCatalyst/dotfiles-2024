DOTPATH    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(wildcard .??*) bin
EXCLUSIONS := .DS_Store .git .gitmodules .travis.yml .vscode .scratch
DOTFILES   := $(filter-out $(EXCLUSIONS), $(CANDIDATES))

.DEFAULT_GOAL := help

all: brew install asdf afx

k8: ## maybe use helmfile???
	cask install --cask docker
	brew install minikube
	brew install helm 
	brew install kubectl
	brew install kubectx	

asdf: ## NOTE, neovim wont work till asdf install NPM dependency
	# @brew install asdf
	@asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
	@asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
	@asdf plugin-add python
	@asdf plugin-add rust https://github.com/asdf-community/asdf-rust.git 
	@asdf install

afx: ## Install babarot/afx
	# NOTE: afx wont be accessible until the dotfiles are added, afx install doesnt add afx to the path bah
	# the dotfile sym linking has it there though.
	@curl -sL https://raw.githubusercontent.com/babarot/afx/HEAD/hack/install | sh
	@echo 'Done. Run "afx install" next.'

brew: ## Install brew and run brew bundle
	@sh ./etc/scripts/brew.sh
	@brew bundle
	@echo 'Done. For saving your brew packages added newly, run "brew bundle dump".'

list: ## Show dot files in this repo
	@$(foreach val, $(DOTFILES), /bin/ls -dF $(val);)

install: ## Create symlink to home directory
	@echo 'Copyright (c) 2013-2015 BABAROT All Rights Reserved.'
	@echo '==> Start to link dotfiles to home directory.'
	@echo ''
	@$(foreach val, $(DOTFILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

clean: ## Remove the dot file symlinks
	@echo 'Remove dot files in your home directory...'
	@-$(foreach val, $(DOTFILES), rm -vrf $(HOME)/$(val);)
	# -rm -rf $(DOTPATH)

fix-permissions:
	@chmod +x ./bin/*


help: ## Self-documented Makefile
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'



