sudo bash apt_install.sh
bash clone_vim_plugins_opt.sh

# In your C project directory
envSource="${HOME}/Code/c/c_env/"
cp "${envSource}/vimrc.txt" "${HOME}/.vimrc"
cp "${envSource}/gemini.sh" ./
cp "${envSource}/doubao.sh" ./
cp "${envSource}/Makefile.txt" ./Makefile
cp "${envSource}/editorconfig.txt" ./.editorconfig
chmod +x gemini.sh doubao.sh
export GEMINI_API_KEY="your‑api‑key‑here"
export ARK_API_KEY="your‑api‑key‑here"

make idx
vim main.c

