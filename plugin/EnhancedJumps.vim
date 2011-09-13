" EnhancedJumps.vim: Enhanced jump list navigation commands. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - EchoWithoutScrolling.vim autoload script.  
"
" Copyright: (C) 2009-2011 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.20.011	14-Sep-2011	Implement "local jumps" and "remote jumps"
"				varieties: 
"				Change signature of s:IsJumpInCurrentBuffer() to
"				be suitable for directly accepting
"				s:ParseJumpLine() results. 
"				Make s:ParseJumpLine() return object to allow
"				easier access to attributes without array
"				slicing. 
"				Differentiate between (given) count and
"				jumpCount when filtering. 
"   1.14.010	13-Sep-2011	Better way to beep. 
"   1.13.009	16-Jul-2010	BUG: Jump opened fold at current position when
"				"No newer/older jump position" error occurred.
"				Now checking whether the jump actually was
"				successful in s:DoJump(), and not just relying
"				on the Vim error that only occurs when there's
"				an invalid jump position. 
"   1.12.008	17-Jul-2009	BF: Trailing space after the command to open the
"				folds accidentally moved cursor one position to
"				the right of the jump target. 
"   1.11.007	14-Jul-2009	BF: A '^\)' string caused "E55: Unmatched \)"
"				because the '\^\p' regexp fragment would only
"				match the first half of the text's escaped
"				backslash and thus sabotage the escaping. Now
"				explicitly matching an escaped backslash (\\) as
"				an alternative to the \p atom. 
"   1.10.006	06-Jul-2009	BF: Folds at the jump target must be explicitly
"				opened; inside a mapping / :normal CTRL-I/O
"				behave like [nN*#]. 
"   1.10.005	01-Jul-2009	ENH: To overcome the next buffer warning, a
"				previously given [count] need not be specified
"				again. A jump command with a different [count]
"				than last time now is treated as a separate jump
"				command and thus doesn't overcome the next
"				buffer warning. 
"				Factored out s:GetJumps(), s:GetCurrentIndex()
"				and s:GetCount() to reduce the size of s:Jump(). 
"   1.00.004	01-Jul-2009	Renamed to EnhancedJumps.vim. 
"				BF: Empty jump text matched any line in the
"				current buffer; but it must match an empty line
"				to belong to the current buffer. 
"				BF: An unnamed buffer was simply listed as
"				"next: ", now listed as "next: [No name]". 
"				BF: s:IsJumpInCurrentBuffer() regexp didn't
"				consider that ^X could stand for either a
"				non-printable char or the literal ^X sequence. 
"	003	29-Jun-2009	BF: Fixed missing next jump indication by
"				executing the jump command before the :echo (and
"				sometimes doing a :redraw before the :echo). 
"	002	28-Jun-2009	ENH: After a jump, the line, column and text of
"				the next jump target are printed. The text of
"				jumps inside the current buffer are highlighted
"				like in the :jumps output. 
"	001	27-Jun-2009	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_EnhancedJumps') || (v:version < 700)
    finish
endif
let g:loaded_EnhancedJumps = 1

"- configuration --------------------------------------------------------------
if ! exists('g:stopFirstAndNotifyTimeoutLen')
    let g:stopFirstAndNotifyTimeoutLen = 2000
endif

"- functions ------------------------------------------------------------------
function! s:GetJumps()
    redir => l:jumpsOutput
    silent! jumps
    redir END
    redraw  " This is necessary because of the :redir done earlier. 

    return split(l:jumpsOutput, "\n")[1:] " The first line contains the header. 
endfunction
function! s:IsJumpNotInCurrentBuffer( jumpLine )
    " For proper indexing, we must include the current jump line in the results. 
    return (a:jumpLine[0] ==# '>' || ! s:IsJumpInCurrentBuffer(s:ParseJumpLine(a:jumpLine)))
endfunction
function! s:FilterJumps( jumps, filter )
    if empty(a:filter)
	return a:jumps
    elseif a:filter ==# 'local'
	return filter(a:jumps, 's:IsJumpInCurrentBuffer(s:ParseJumpLine(v:val))')
    elseif a:filter ==# 'remote'
	" TODO: filter duplicate subsequent files (in jump direction)
	return filter(a:jumps, 's:IsJumpNotInCurrentBuffer(v:val)')
    else
	throw 'ASSERT: Unknown filter type ' . string(a:filter)
    endif
endfunction
function! s:GetCurrentIndex( jumps )
    let l:currentIndex = -1
    " Note: The linear search starts from the end because it's more likely that
    " the user hasn't navigated to the oldest entries in the jump list. 
    for l:i in reverse(range(len(a:jumps)))
	if a:jumps[l:i][0] ==# '>'
	    let l:currentIndex = l:i
	    break
	endif
    endfor
    if l:currentIndex < 0 | throw 'ASSERT: :jumps command contains > marker' | endif
    return l:currentIndex
endfunction
function! s:GetCount()
    " Determine whether this is a repetition of the same jump command that got
    " stuck on the warning about jumping into another buffer. 
    let l:wasStopped = (exists('t:lastJumpCommandCount') && t:lastJumpCommandCount)
    if l:wasStopped
	" If no [count] is given on this repetition, re-use the [count]
	" from the initial jump command that got stuck on the warning. 
	return (v:count ? v:count1 : t:lastJumpCommandCount)
    else
	" This isn't a repetition; use the supplied [count]. 
	return v:count1
    endif
endfunction
function! s:BufferName( jumpText )
    return (empty(a:jumpText) ? '[No name]' : a:jumpText)
endfunction
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
function! s:IsJumpInCurrentBuffer( parsedJump )
    if empty(a:parsedJump.text)
	" In case there is no jump text, the corresponding line in the current
	" buffer also should be empty. 
	let l:regexp = '^$'
    else
	" The jump text omits any indent, may be truncated and has non-printable
	" characters rendered as ^X (so any ^X substring may either represent a
	" non-printable single character or the literal two-character ^X
	" sequence). The regexp has to consider this. 
	let l:regexp = '\V' . substitute(escape(a:parsedJump.text, '\'), '\^\%(\\\\\|\p\)', '\\%(\0\\|\\.\\)', 'g')
    endif
"****D echomsg '****' l:regexp
    return getline(a:parsedJump.lnum) =~# l:regexp
endfunction
function! s:ParseJumpLine( jumpLine )
    " Parse one line of output from :jumps into object with count, lnum, col, text. 
    let l:parseResult = matchlist(a:jumpLine, '^>\?\s*\(\d\+\)\s\+\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
    return {
    \	'count': get(l:parseResult, 1, 0),
    \	'lnum' : get(l:parseResult, 2, 0),
    \	'col'  : get(l:parseResult, 3, 0),
    \	'text' : get(l:parseResult, 4, '')
    \}
endfunction
function! s:RecordPosition()
    " The position record consists of the current cursor position and the buffer
    " number. 
    return getpos('.') + [bufnr('')]
endfunction  
function! s:DoJump( count, isNewer )
    try
	" There's just a beep when there's no newer/older jump position; this is
	" not a Vim error, so no exception is thrown. 
	" We check the position before and after the jump to detect its success
	" in all cases. 
	let l:originalPosition = s:RecordPosition()
	execute 'normal!' a:count . (a:isNewer ? "\<C-i>" : "\<C-o>")
	if s:RecordPosition() == l:originalPosition
	    return 0
	endif

	" When typed, CTRL-I/O open the fold at the jump target, but inside a
	" mapping or :normal this must be done explicitly via 'zv'. 
	normal! zv
	
	return 1
    catch /^Vim\%((\a\+)\)\=:E/
	" A Vim error occurs when there's an invalid jump position. 

	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away. 
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
	return 0
    endtry
endfunction
function! s:Jump( isNewer, filter )
    let l:filterName = (empty(a:filter) ? '' : ' ' . a:filter)
    let l:jumpDirection = (a:isNewer ? 'newer' : 'older')
    let l:jumps = s:FilterJumps(s:GetJumps(), a:filter)
    let l:currentIndex = s:GetCurrentIndex(l:jumps)
    let l:count = s:GetCount()

    let l:targetIndex = l:currentIndex + (a:isNewer ? 1 : -1) * l:count
    let l:followingIndex = l:targetIndex + (a:isNewer ? 1 : -1)
    let l:targetJump = (l:targetIndex < 0 ? '' : get(l:jumps, l:targetIndex, ''))
    let l:followingJump = (l:followingIndex < 0 ? '' : get(l:jumps, l:followingIndex, ''))
"****D echomsg '****' l:targetIndex l:targetJump
"****D echomsg '****' l:followingIndex l:followingJump
    " In case of filtering the count for the jump command does not correspond to
    " the given count and must be retrieved from the jump line. 
    let l:jumpCount = (empty(a:filter) ? l:count : s:ParseJumpLine(l:targetJump).count)
"****D echomsg '****' l:count l:jumpCount
    if empty(l:targetJump)
	let l:countMax = (a:isNewer ? len(l:jumps) - l:currentIndex - 1: l:currentIndex)
	if l:countMax == 0
	    let v:errmsg = printf('No %s%s jump position', l:jumpDirection, l:filterName)
	else
	    let v:errmsg = printf('Only %d %s%s jump position%s', l:countMax, l:jumpDirection, l:filterName, (l:countMax > 1 ? 's' : ''))
	endif
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
	
	" We still execute the actual jump command, even though we've determined
	" that it won't work. The jump command will still cause the customary
	" beep. 
	call s:DoJump(l:jumpCount, a:isNewer)
    else
	let l:target = s:ParseJumpLine(l:targetJump)
	if s:IsInvalid(l:target.text)
	    " Do nothing here, the jump command will print an error. 
	    call s:DoJump(l:jumpCount, a:isNewer)
	elseif s:IsJumpInCurrentBuffer(l:target)
	    " To avoid that the jump command's output overwrites the indication
	    " of the next jump position, the jump command is executed first and
	    " the indication only printed if the jump didn't cause an error. 
	    if s:DoJump(l:jumpCount, a:isNewer)
		let l:following = s:ParseJumpLine(l:followingJump)
		if empty(l:followingJump)
		    redraw
		    echo printf('No %s%s jump position', l:jumpDirection, l:filterName)
		elseif s:IsInvalid(l:following.text)
		    redraw
		    echo printf('Next%s jump position is invalid', l:filterName)
		elseif s:IsJumpInCurrentBuffer(l:following)
		    let l:header = printf('next%s: %d,%d ', l:filterName, l:following.lnum, l:following.col)
		    echo l:header
		    echohl Directory
		    echon EchoWithoutScrolling#Truncate(l:following.text, strlen(l:header))
		    echohl None
		else
		    call EchoWithoutScrolling#Echo(printf('next%s: %s', l:filterName, s:BufferName(l:following.text)))
		endif
	    endif
	else
	    " The next jump would move to another buffer. Stop and notify first,
	    " and only execute the jump if the same jump command (either
	    " repeating the original [count] or completely omitting it) is
	    " executed once more immediately afterwards. 
	    let l:isSameCountAsLast = (! v:count || (exists('t:lastJumpCommandCount') && t:lastJumpCommandCount == v:count1))
	    let l:wasLastJumpBufferStop = l:isSameCountAsLast && (exists('t:lastJumpBufferStop') && s:WasLastStop([a:isNewer, winnr(), l:target.text, localtime()], t:lastJumpBufferStop))
	    if l:wasLastJumpBufferStop || ! empty(a:filter)
		call s:DoJump(l:jumpCount, a:isNewer)
	    else
		" Memorize the current jump command, context, target and time
		" (except for the [count], which is stored separately) to be
		" able to detect the same jump command. 
		let t:lastJumpBufferStop = [a:isNewer, winnr(), l:target.text, localtime()]

		" Memorize the given [count] to detect the same jump command,
		" and that it need not be specified on the repetition of the
		" jump command to overcome the warning. 
		let t:lastJumpCommandCount = l:count

		let v:warningmsg = printf('next%s: %s', l:filterName, s:BufferName(l:target.text))
		echohl WarningMsg
		echomsg v:warningmsg
		echohl None

		" Signal edge case via beep. 
		execute "normal! \<C-\>\<C-n>\<Esc>"

		" We stop here, and do not execute the actual jump command. 
		return
	    endif
	endif
    endif

    let t:lastJumpBufferStop = [a:isNewer, winnr(), '', 0]
    let t:lastJumpCommandCount = 0  " This is no repetition. 
endfunction

"- mappings -------------------------------------------------------------------
nnoremap <Plug>EnhancedJumpsOlder       :<C-u>call <SID>Jump(0,'')<CR>
nnoremap <Plug>EnhancedJumpsNewer       :<C-u>call <SID>Jump(1,'')<CR>
nnoremap <Plug>EnhancedJumpsLocalOlder  :<C-u>call <SID>Jump(0,'local')<CR>
nnoremap <Plug>EnhancedJumpsLocalNewer  :<C-u>call <SID>Jump(1,'local')<CR>
nnoremap <Plug>EnhancedJumpsRemoteOlder :<C-u>call <SID>Jump(0,'remote')<CR>
nnoremap <Plug>EnhancedJumpsRemoteNewer :<C-u>call <SID>Jump(1,'remote')<CR>

if ! hasmapto('<Plug>EnhancedJumpsOlder', 'n')
    nmap <silent> <C-o> <Plug>EnhancedJumpsOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsNewer', 'n')
    nmap <silent> <C-i> <Plug>EnhancedJumpsNewer
endif
if ! hasmapto('<Plug>EnhancedJumpsLocalOlder', 'n')
    nmap <silent> g<C-o> <Plug>EnhancedJumpsLocalOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsLocalNewer', 'n')
    nmap <silent> g<C-i> <Plug>EnhancedJumpsLocalNewer
endif
if ! hasmapto('<Plug>EnhancedJumpsRemoteOlder', 'n')
    nmap <silent> <Leader><C-o> <Plug>EnhancedJumpsRemoteOlder
endif
if ! hasmapto('<Plug>EnhancedJumpsRemoteNewer', 'n')
    nmap <silent> <Leader><C-i> <Plug>EnhancedJumpsRemoteNewer
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
