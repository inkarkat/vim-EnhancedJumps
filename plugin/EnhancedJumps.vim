" ingojumps.vim: Enhanced jump list navigation commands. 
"
" DESCRIPTION:
"   This plugin enhances the built-in CTRL-I / CTRL-O jump commands: 
"   - For jumps inside the current buffer, the line, column and text at the jump
"     target are printed. 
"   - An error message and the valid range for jumps in that direction is
"     printed if a jump outside the jumplist is attempted. 
"   - In case the next jump would move to another buffer, only a warning is
"     printed at the first attempt. The jump to another buffer is only executed
"     if the same jump command is executed once more immediately afterwards. 
"
" USAGE:
" INSTALLATION:
"   Put the script into your user or system Vim plugin directory (e.g.
"   ~/.vim/plugin). 

" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - EchoWithoutScrolling.vim autoload script.  

" CONFIGURATION:
" INTEGRATION:
" LIMITATIONS:
" ASSUMPTIONS:
" KNOWN PROBLEMS:
" TODO:
"
" Copyright: (C) 2009 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	001	27-Jun-2009	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_ingojumps') || (v:version < 700)
    finish
endif
let g:loaded_ingojumps = 1

"- configuration --------------------------------------------------------------
if ! exists('g:stopFirstAndNotifyTimeoutLen')
    let g:stopFirstAndNotifyTimeoutLen = 2000
endif

"- functions ------------------------------------------------------------------
function! s:WasLastStop( current, record )
    return (! empty(a:current) && ! empty(a:record) && a:current[0:-2] == a:record[0:-2]) && (a:current[-1] - a:record[-1] <= (g:stopFirstAndNotifyTimeoutLen / 1000))
endfunction
function! s:IsInvalid( text )
    if a:text ==# '-invalid-'
	" Though invalid jumps are caused by marks in another (modified) file,
	" treat them as belonging to the current buffer; after all, Vim doesn't
	" move to that file, and just prints the "E19: Mark has invalid line
	" number" error. 
	return 1
    endif
endfunction
function! s:IsJumpInCurrentBuffer( line, text )
    " The jump text omits any indent, may be truncated and has non-printable
    " characters rendered as ^X. The regexp has to consider this. 
    let l:regexp = '\V' . substitute(escape(a:text, '\'), '\^\p', '\\.', 'g')
    return getline(a:line) =~# l:regexp
endfunction
function! s:Jump( isNewer )
    let l:jumpDirection = (a:isNewer ? 'newer' : 'older')

    redir => l:jumpsOutput
    silent! jumps
    redir END
    redraw  " This is necessary because of the :redir done earlier. 

    let l:jumps = split(l:jumpsOutput, "\n")[1:] " The first line contains the header. 

    let l:currentIndex = -1
    for l:i in reverse(range(len(l:jumps)))
	if strpart(l:jumps[l:i], 0, 1) == '>'
	    let l:currentIndex = l:i
	    break
	endif
    endfor
    if l:currentIndex < 0 | throw 'ASSERT: :jumps command contains > marker' | endif

    let l:targetIndex = l:currentIndex + (a:isNewer ? 1 : -1) * v:count1
    let l:targetJump = (l:targetIndex < 0 ? '' : get(l:jumps, l:targetIndex, ''))
    if empty(l:targetJump)
	let l:countMax = (a:isNewer ? len(l:jumps) - l:currentIndex - 1: l:currentIndex)
	if l:countMax == 0
	    let v:errmsg = printf('No %s jump position', l:jumpDirection)
	else
	    let v:errmsg = printf('Only %d %s jump position%s', l:countMax, l:jumpDirection, (l:countMax > 1 ? 's' : ''))
	endif
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
	
	" We still fall through to the actual jump command, even though we've
	" determined that it won't work. The jump command will still cause the
	" customary beep. 
    else
	let [l:x, l:targetLine, l:targetCol, l:targetText, l:x, l:x, l:x, l:x, l:x, l:x] = matchlist(l:targetJump, '^>\?\s*\d\+\s\+\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
	if s:IsInvalid(l:targetText)
	    " Do nothing here, the jump command will print an error. 
	elseif s:IsJumpInCurrentBuffer(l:targetLine, l:targetText)
	    call EchoWithoutScrolling#Echo(printf('%d,%d %s', l:targetLine, l:targetCol, l:targetText))
	else
	    " The next jump would move to another buffer. Stop and notify first,
	    " and only execute the jump if the same jump command is executed
	    " once more immediately afterwards. 
	    let l:wasLastJumpBufferStop = (exists('t:lastJumpBufferStop') && s:WasLastStop([a:isNewer, winnr(), l:targetText, localtime()], t:lastJumpBufferStop))
	    if ! l:wasLastJumpBufferStop
		let t:lastJumpBufferStop = [a:isNewer, winnr(), l:targetText, localtime()]
		let v:warningmsg = 'next: ' . l:targetText
		echohl WarningMsg
		echomsg v:warningmsg
		echohl None

		" Signal edge case via beep. 
		execute "normal \<Plug>IngoJumpsBell" 

		" We stop here, and do not execute the actual jump command. 
		return
	    endif
	endif
    endif

    let t:lastJumpBufferStop = [a:isNewer, winnr(), '', 0]

    try
	execute 'normal!' v:count1 . (a:isNewer ? "\<C-i>" : "\<C-o>")
    catch /^Vim\%((\a\+)\)\=:E/
	echohl ErrorMsg
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away. 
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echomsg v:errmsg
	echohl None
    endtry
endfunction

"- mappings -------------------------------------------------------------------
nnoremap <Plug>IngoJumpsOlder :<C-u>call <SID>Jump(0)<CR>
nnoremap <Plug>IngoJumpsNewer :<C-u>call <SID>Jump(1)<CR>
if ! hasmapto('<Plug>IngoJumpsOlder', 'n')
    nmap <silent> <C-o> <Plug>IngoJumpsOlder
endif
if ! hasmapto('<Plug>IngoJumpsNewer', 'n')
    nmap <silent> <C-i> <Plug>IngoJumpsNewer
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
