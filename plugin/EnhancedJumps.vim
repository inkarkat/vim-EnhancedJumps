
function! s:IsJumpInCurrentBuffer( line, text )
    " The jump text omits any indent, may be truncated and has non-printable
    " characters rendered as ^X. The regexp has to consider this. 
    let l:regexp = '\V' . substitute(escape(a:text, '\'), '\^\p', '\\.', 'g')
    return getline(a:line) =~# l:regexp
endfunction
function! s:Jump( isForward )
    let l:jumpDirection = (a:isForward ? 'newer' : 'older')

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

    let l:targetIndex = l:currentIndex + (a:isForward ? 1 : -1) * v:count1
    let l:targetJump = (l:targetIndex < 0 ? '' : get(l:jumps, l:targetIndex, ''))
    if empty(l:targetJump)
	let l:countMax = (a:isForward ? len(l:jumps) - l:currentIndex - 1: l:currentIndex)
	if l:countMax == 0
	    let v:errmsg = printf('No %s jump position', l:jumpDirection)
	else
	    let v:errmsg = printf('Only %d %s jump position%s', l:countMax, l:jumpDirection, (l:countMax > 1 ? 's' : ''))
	endif
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    else
	let [l:x, l:targetLine, l:targetCol, l:targetText, l:x, l:x, l:x, l:x, l:x, l:x] = matchlist(l:targetJump, '^>\?\s*\d\+\s\+\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
	if s:IsJumpInCurrentBuffer(l:targetLine, l:targetText)
	    echo printf('%d,%d %s', l:targetLine, l:targetCol, l:targetText)
	else
	    let l:wasLastJumpBufferStop = (exists('t:lastJumpBufferStop') && [a:isForward, winnr(), l:targetText] == t:lastJumpBufferStop)
	    if ! l:wasLastJumpBufferStop
		let t:lastJumpBufferStop = [a:isForward, winnr(), l:targetText]
		let v:warningmsg = 'next: ' . l:targetText
		echohl WarningMsg
		echomsg v:warningmsg
		echohl None

		" Signal edge case via beep. 
		execute "normal \<Plug>IngoJumpBell" 

		return
	    endif
	endif
    endif

    let t:lastJumpBufferStop = [a:isForward, winnr(), '']
    execute 'normal!' v:count1 . (a:isForward ? "\<C-i>" : "\<C-o>")
endfunction
nnoremap <silent> { :<C-u>call <SID>Jump(0)<CR>
nnoremap <silent> } :<C-u>call <SID>Jump(1)<CR>

