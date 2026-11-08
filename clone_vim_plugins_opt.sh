#!/bin/bash
set -e
VIM_PACK="$HOME/.vim/pack"
mkdir -p "$VIM_PACK/tpope/opt"
mkdir -p "$VIM_PACK/vendor/opt"

cd "$VIM_PACK/tpope/opt"
git clone https://github.com/tpope/vim-repeat.git
git clone https://github.com/tpope/vim-surround.git
git clone https://github.com/tpope/vim-commentary.git
git clone https://github.com/tpope/vim-fugitive.git

cd "$VIM_PACK/vendor/opt"
git clone https://github.com/ctrlpvim/ctrlp.vim.git ctrlp
git clone https://github.com/editorconfig/editorconfig-vim.git
git clone https://github.com/dense-analysis/ale.git
git clone https://github.com/majutsushi/tagbar.git
git clone https://github.com/vim-airline/vim-airline.git
git clone https://github.com/vim-airline/vim-airline-themes.git

vim -c "helptags ALL" -c q
echo "All plugins cloned into opt, enable each plugin by packadd! inside vimrc"

