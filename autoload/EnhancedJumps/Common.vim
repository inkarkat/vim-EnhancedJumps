" Common.vim: Shared functionality for dealing with jump lists.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012-2020 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! EnhancedJumps#Common#GetJumps( command )
    redir => l:jumpsOutput
    silent! execute a:command
    redir END
    redraw  " This is necessary because of the :redir done earlier.

    return split(l:jumpsOutput, "\n")[1:] " The first line contains the header.
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
    if l:currentIndex < 0
	" XXX: Sometimes, the :changes command just outputs the "change line col
	" text" line, without a ">" line following.
	throw 'EnhancedJumps: jump list does not contain > marker'
    endif
    return l:currentIndex
endfunction
function! EnhancedJumps#Common#SliceJumpsInDirection( jumps, isNewer )
"******************************************************************************
"* PURPOSE:
"   From the list of jumps, keep only those following the current index in the
"   direction of jump, and reverse older jumps so that the jump index directly
"   corresponds to the count of the jump.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:jumps List of jump lines from :jumps or :changes command.
"   a:isNewer	Flag whether the jump is to newer jumps.
"* RETURN VALUES:
"   Rearranged slice of jumps; the jump index corresponds to the jump count.
"******************************************************************************
    let l:currentIndex = s:GetCurrentIndex(a:jumps)
    if a:isNewer
	return a:jumps[(l:currentIndex + 1) : ]
    else
	return (l:currentIndex == 0 ? [] : reverse(a:jumps[ : (l:currentIndex - 1)]))
    endif
endfunction

function! EnhancedJumps#Common#ParseJumpLine( jumpLine )
    " Parse one line of output from :jumps into object with count, lnum, col, text.
    let l:parseResult = matchlist(a:jumpLine, '^>\?\s*\(\d\+\)\s\+\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
    return {
    \	'count': get(l:parseResult, 1, 0),
    \	'lnum' : get(l:parseResult, 2, 0),
    \	'col'  : get(l:parseResult, 3, 0),
    \	'text' : get(l:parseResult, 4, '')
    \}
endfunction

function! EnhancedJumps#Common#IsInvalid( text )
    if a:text ==# '-invalid-'
	" Though invalid jumps are caused by marks in another (modified) file,
	" treat them as belonging to the current buffer; after all, Vim doesn't
	" move to that file, and just prints the "E19: Mark has invalid line
	" number" error.
	return 1
    endif
endfunction
function! EnhancedJumps#Common#IsJumpInCurrentBuffer( parsedJump )
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
function! s:Echo( fileJumpMessages, message )
    if empty(a:fileJumpMessages)
	echo ingo#avoidprompt#Truncate(a:message)
    elseif &cmdheight > 1 || len(a:fileJumpMessages) > 1
	for l:message in a:fileJumpMessages
	    echomsg l:message
	endfor
	echo ingo#avoidprompt#Truncate(a:message)
    else
	let l:message = ingo#avoidprompt#Truncate(a:message, ingo#compat#strdisplaywidth(a:fileJumpMessages[0]) + 1)    " The captured jump message may contain unprintable or non-ASCII characters; use strdisplaywidth().
	echomsg a:fileJumpMessages[0] . (empty(l:message) ? '' : ' ')
	echon l:message
    endif
endfunction
function! EnhancedJumps#Common#BufferName( jumpText )
    return (empty(a:jumpText) ? '[No name]' : a:jumpText)
endfunction
function! EnhancedJumps#Common#EchoFollowingMessage( followingJump, jumpDirection, filterName, fileJumpMessages )
    let l:following = EnhancedJumps#Common#ParseJumpLine(a:followingJump)
    if empty(a:followingJump)
	redraw
	call s:Echo(a:fileJumpMessages, printf('No %s%s jump position', a:jumpDirection, a:filterName))
    elseif EnhancedJumps#Common#IsInvalid(l:following.text)
	redraw
	call s:Echo(a:fileJumpMessages, printf('Next%s jump position is invalid', a:filterName))
    elseif EnhancedJumps#Common#IsJumpInCurrentBuffer(l:following)
	let l:header = printf('next%s: %d,%d ', a:filterName, l:following.lnum, l:following.col)
	call s:Echo(a:fileJumpMessages, l:header)
	let l:reservedColumns = len(l:header)	" l:header is printable ASCII-only, so can use len() for text width.
	if len(a:fileJumpMessages) == 1 && &cmdheight == 1
	    let l:reservedColumns += ingo#compat#strdisplaywidth(a:fileJumpMessages[0], l:reservedColumns) + 1  " The captured jump message may contain unprintable or non-ASCII characters; use strdisplaywidth(); it starts after the header, so consider its width, too.
	endif
	call ingo#msg#HighlightN(ingo#avoidprompt#Truncate(getline(l:following.lnum), l:reservedColumns), 'Directory')
    else
	call s:Echo(a:fileJumpMessages, printf('next%s: %s', a:filterName, EnhancedJumps#Common#BufferName(l:following.text)))
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
