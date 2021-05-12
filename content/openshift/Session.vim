let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/git_repositories/moje/madopenshift/content/openshift
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
set shortmess=aoO
badd +23 ~/git_repositories/moje/madopenshift/content/faze/nifi-zookeeper-statefullset/02-nifi-ca-repository.md
badd +19 PERSISTENCE/nfsAzureFile-K8s.md
badd +10 PERSISTENCE/azureFile-PersistenceFileStorage.md
badd +2 PERSISTENCE/yaml/storageclass.yaml
badd +22 PERSISTENCE/yaml/sts-pv.yaml
badd +46 PERSISTENCE/yaml/sts.yaml
badd +14 PERSISTENCE/yaml/pv.yaml
badd +177 ~/.zshrc
badd +102 ~/git_repositories/moje/madopenshift/content/faze/nifi-zookeeper-statefullset/01-zookeper.md
badd +11 ~/git_repositories/moje/madopenshift/content/faze/nifi-zookeeper-statefullset/index.md
badd +6 PERSISTENCE/yaml/pvc.yaml
badd +0 agregateLogging/log.md
argglobal
%argdel
edit agregateLogging/log.md
set splitbelow splitright
set nosplitbelow
set nosplitright
wincmd t
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
setlocal fdm=expr
setlocal fde=Foldexpr_markdown(v:lnum)
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=20
setlocal fml=1
setlocal fdn=20
setlocal fen
let s:l = 70 - ((69 * winheight(0) + 38) / 77)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 70
normal! 0
lcd ~/git_repositories/moje/madopenshift/content/openshift
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0&& getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20 winminheight=1 winminwidth=1 shortmess=filnxtToOFc
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
nohlsearch
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
