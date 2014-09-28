" EnhancedJumps.vim: Enhanced jump list navigation commands. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - EnhancedJumps.vim autoload script.  
"
" Copyright: (C) 2009-2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   3.00.002	08-Feb-2012	Add mappings for jumps to far changes. 
"   2.00.001	27-Jun-2009	Split off autoload script. 
"				file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_EnhancedJumps') || (v:version < 700)
    finish
endif
let g:loaded_EnhancedJumps = 1

"- configuration --------------------------------------------------------------
if ! exists('g:stopFirstAndNotifyTimeoutLen')
    let g:stopFirstAndNotifyTimeoutLen = 2000
endif


"- mappings -------------------------------------------------------------------
nnoremap <silent> <Plug>EnhancedJumpsOlder       :<C-u>call EnhancedJumps#Jump(0,'')<CR>
nnoremap <silent> <Plug>EnhancedJumpsNewer       :<C-u>call EnhancedJumps#Jump(1,'')<CR>
nnoremap <silent> <Plug>EnhancedJumpsLocalOlder  :<C-u>call EnhancedJumps#Jump(0,'local')<CR>
nnoremap <silent> <Plug>EnhancedJumpsLocalNewer  :<C-u>call EnhancedJumps#Jump(1,'local')<CR>
nnoremap <silent> <Plug>EnhancedJumpsRemoteOlder :<C-u>call EnhancedJumps#Jump(0,'remote')<CR>
nnoremap <silent> <Plug>EnhancedJumpsRemoteNewer :<C-u>call EnhancedJumps#Jump(1,'remote')<CR>

nnoremap <silent> <Plug>EnhancedJumpsFarChangeOlder         :<C-u>call EnhancedJumps#Changes#Jump(0,0)<CR>
nnoremap <silent> <Plug>EnhancedJumpsFarChangeNewer         :<C-u>call EnhancedJumps#Changes#Jump(1,0)<CR>
nnoremap <silent> <Plug>EnhancedJumpsFarFallbackChangeOlder :<C-u>call EnhancedJumps#Changes#Jump(0,1)<CR>
nnoremap <silent> <Plug>EnhancedJumpsFarFallbackChangeNewer :<C-u>call EnhancedJumps#Changes#Jump(1,1)<CR>

if ! hasmapto('<Plug>EnhancedJumpsOlder', 'n')
    nmap <C-o> <Plug>EnhancedJumpsOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsNewer', 'n')
    nmap <C-i> <Plug>EnhancedJumpsNewer
endif
if ! hasmapto('<Plug>EnhancedJumpsLocalOlder', 'n')
    nmap g<C-o> <Plug>EnhancedJumpsLocalOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsLocalNewer', 'n')
    nmap g<C-i> <Plug>EnhancedJumpsLocalNewer
endif
if ! hasmapto('<Plug>EnhancedJumpsRemoteOlder', 'n')
    nmap <Leader><C-o> <Plug>EnhancedJumpsRemoteOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsRemoteNewer', 'n')
    nmap <Leader><C-i> <Plug>EnhancedJumpsRemoteNewer
endif

if ! hasmapto('<Plug>EnhancedJumpsFarFallbackChangeOlder', 'n')
    nmap g; <Plug>EnhancedJumpsFarFallbackChangeOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsFarFallbackChangeNewer', 'n')
    nmap g, <Plug>EnhancedJumpsFarFallbackChangeNewer
endif

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
