" Changes.vim: summary
"
" DEPENDENCIES:
"   - EnhancedJumps/Common.vim autoload script. 
"   - ingowindow.vim autoload script. 
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	001	08-Feb-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! s:abs( num1, num2 )
    let l:difference = a:num1 - a:num2
    return (l:difference >= 0 ? l:difference : -1 * l:difference)
endfunction
function! s:FilterNearJumps( jumps, isNewer, startLnum, endLnum, nearHeight )
"****D echo join(a:jumps, "\n")
    " Always jump to the latest change position, also when jumping to newer
    " changes.
    " This way, the same position is maintained when jumping older and newer.
    let l:farJumps = []
    let l:prevParsedJump = EnhancedJumps#Common#ParseJumpLine('')
    let l:prevParsedJump.lnum = -1 * (a:nearHeight + 1)
    let l:lastLnum = 0
    let l:isFirstJump = 1

    for l:i in (a:isNewer ?
    \	range(len(a:jumps) - 1, 0, -1) :
    \	range(len(a:jumps))
    \)
	let l:currentParsedJump = EnhancedJumps#Common#ParseJumpLine(a:jumps[l:i])
	" Include the current jump if it's more than a:nearHeight lines away
	" from the previous jump or from the last accepted jump. 
	if l:isFirstJump && (
	\	l:currentParsedJump.lnum < a:startLnum ||
	\	l:currentParsedJump.lnum > a:endLnum
	\   ) ||
	\   ! l:isFirstJump && (
	\	s:abs(l:currentParsedJump.lnum, l:prevParsedJump.lnum) > a:nearHeight ||
	\	s:abs(l:currentParsedJump.lnum, l:lastLnum) > a:nearHeight
	\   )
	    if a:isNewer
		call insert(l:farJumps, a:jumps[l:i], 0)
	    else
		call add(l:farJumps, a:jumps[l:i])
	    endif
	    let l:isFirstJump = 0
	    let l:lastLnum = l:currentParsedJump.lnum
	endif
	let l:prevParsedJump = l:currentParsedJump
    endfor
"****D echo "****\n" join(l:farJumps, "\n")
    return l:farJumps
endfunction

function! s:DoJump( count, isNewer )
    if a:count == 0
	execute "normal! \<C-\>\<C-n>\<Esc>"
	return 0
    endif

    try
	execute 'normal!' a:count . (a:isNewer ? 'g,' : 'g;')

	" When typed, g,/g; open the fold at the jump target, but inside a
	" mapping or :normal this must be done explicitly via 'zv'. 
	normal! zv
	
	return 1
    catch /^Vim\%((\a\+)\)\=:E/
	" A Vim error occurs when already at the start / end of the changelist. 

	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away. 
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
	return 0
    endtry
endfunction
function! EnhancedJumps#Changes#Jump( isNewer, isFallbackToNearChanges )
    let l:jumpDirection = (a:isNewer ? 'newer' : 'older')
    let l:count = v:count1
    let [l:startLnum, l:endLnum] = ingowindow#DisplayedLines()
    let l:nearHeight = winheight(0)

    let l:jumps = s:FilterNearJumps(
    \	EnhancedJumps#Common#SliceJumpsInDirection(
    \	    EnhancedJumps#Common#GetJumps('changes'),
    \	    a:isNewer
    \	),
    \	a:isNewer,
    \	l:startLnum, l:endLnum, l:nearHeight
    \)

    if empty(l:jumps)
	if a:isFallbackToNearChanges
	    " Perform the [count]'th near jump. 
	    if s:DoJump(l:count, a:isNewer)
		" Only print the warning when the jump was successful; it may
		" have already errored out with "At start / end of changelist". 
		let v:warningmsg = printf('No %s far change', l:jumpDirection)
		echohl WarningMsg
		echomsg v:warningmsg
		echohl None
	    endif

	    return
	else
	    let v:errmsg = printf('No %s far change', l:jumpDirection)
	    echohl ErrorMsg
	    echomsg v:errmsg
	    echohl None
	endif
	" We still execute the actual jump command, even though we've determined
	" that it won't work. The jump command will still cause the customary
	" beep. 
    endif

"****D for j in l:jumps | echomsg j | endfor
    let l:targetJump = get(l:jumps, l:count - 1, '')
    if empty(l:targetJump) && a:isFallbackToNearChanges
	" Perform the first near jump after the last available far jump. 
	let l:fallbackCount = get(l:jumps, -1, 0) + 1
	if s:DoJump(l:fallbackCount, a:isNewer)
	    " Only print the warning when the jump was successful; it may
	    " have already errored out with "At start / end of changelist". 
	    let v:warningmsg = printf('No more %d %s far changes', l:count, l:jumpDirection)
	    echohl WarningMsg
	    echomsg v:warningmsg
	    echohl None
	endif

	return
    endif

    " Because of filtering the count for the jump command does not correspond to
    " the given count and must be retrieved from the jump line. 
    let l:jumpCount = EnhancedJumps#Common#ParseJumpLine(l:targetJump).count
"****D echomsg '****' l:count l:jumpCount
    call s:DoJump(l:jumpCount, a:isNewer)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
