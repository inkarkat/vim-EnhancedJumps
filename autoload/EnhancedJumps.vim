" EnhancedJumps.vim: Enhanced jump list navigation commands.
"
" DEPENDENCIES:
"   - EnhancedJumps/Common.vim autoload script
"   - ingo/avoidprompt.vim autoload script
"   - ingo/compat.vim autoload script
"   - ingo/err.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/record.vim autoload script
"
" Copyright: (C) 2009-2016 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   3.10.021	18-Nov-2016	Use real error reporting with ingo#err#Set()
"				(beeps are still simply issues, without aborting
"				command sequences). We cannot use the return
"				status of s:DoJump(), because that signifies
"				whether a jump has occurred. We check via
"				ingo#err#IsSet() instead.
"   3.03.020	18-Nov-2016	After a jump to another file, also re-query the
"				jumps, because the jumplist got updated with the
"				text for the jumps, whereas it previously only
"				contained the buffer name. Thanks to Daniel
"				Hahler for sending a patch.
"				Especially in small terminals, jump messages may
"				not fit and cause a hit-enter prompt. Truncate
"				messages in s:Echo().
"				Local jump message only considers the
"				header, but not the file jump messages. If its
"				one, and cmdheight is 1, add its width to the
"				number of reserved columns, as we append the
"				following location. Thanks to Daniel Hahler for
"				the patch.
"				The warning message before a remote jump isn't
"				truncated to fit.
"   3.02.019	29-Sep-2014	Add g:EnhancedJumps_CaptureJumpMessages
"				configuration to turn off the capturing of the
"				messages during the jump, as the used :redir may
"				cause errors with another, concurrent capture.
"   3.02.018	30-May-2014	Use ingo#record#Position().
"   3.02.017	05-May-2014	Use ingo#msg#WarningMsg().
"   3.01.016	14-Jun-2013	Use ingo/msg.vim.
"   3.01.015	07-Jun-2013	Move EchoWithoutScrolling.vim into ingo-library.
"   3.00.014	08-Feb-2012	Move common shared functions to
"				EnhancedJumps/Common.vim autoload script to
"				allow re-use by new EnhancedJumps/Changes.vim.
"   2.00.013	20-Sep-2011	Split off autoload script.
"   2.00.012	14-Sep-2011	Make s:ParseJumpLine() return object to allow
"				easier access to attributes without array
"				slicing.
"				Differentiate between (given) count and
"				jumpCount when filtering.
"				Make remote jumps move to individual, different
"				files, so that remote jumps with [count] work as
"				expected.
"				s:DoJump() must now check for count = 0 because
"				of filtering.
"				Add filter name to all user messages.
"				Redefine l:jumps to only contain the jumps in
"				the jump direction via
"				s:SliceJumpsInDirection(). This obviates the
"				index arithmetic, duplicated checks for current
"				index marker, and enhances the filter
"				performance, because the unnecessary part in the
"				opposite direction doesn't need to be processed.
"				Make newer remote jumps also jump to the latest
"				file position, as this is more useful.
"				FIX: By just considering file names,
"				s:RemoveDuplicateSubsequentFiles() collapsed
"				jumps where there was a local jump in between.
"				Now also checking for sequential jump count.
"				Implement "next jump" message also for remote
"				jumps by capturing the file jump message(s)
"				(BufRead autocmds may be triggered and print
"				messages, such as the IndentConsistencyCop
"				plugin). Concatenate in one message line, or use
"				a larger 'cmdheight' value. The tricky thing for
"				the "remote" filter is that the following jump
"				information can become wrong in an A->B->A
"				scenario.
"   2.00.011	13-Sep-2011	Implement "local jumps" and "remote jumps"
"				varieties:
"				Change signature of s:IsJumpInCurrentBuffer() to
"				be suitable for directly accepting
"				s:ParseJumpLine() results.
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
let s:save_cpo = &cpo
set cpo&vim

function! s:FilterDuplicateSubsequentFiles( jumps, isNewer )
"****D echo join(a:jumps, "\n")
    " Always jump to the latest file position, also when jumping to newer files.
    " This way, the same position is maintained when jumping older and newer.
    " Otherwise, the newer jumps would always start at the top of the file (or
    " remembered file position) - not very useful.
    let l:uniqueJumps = []
    let l:prevParsedJump = EnhancedJumps#Common#ParseJumpLine('')
    for l:i in (a:isNewer ?
    \	range(len(a:jumps) - 1, 0, -1) :
    \	range(len(a:jumps))
    \)
	let l:currentParsedJump = EnhancedJumps#Common#ParseJumpLine(a:jumps[l:i])
	" Include the current jump if it's a different file or there are other
	" local jumps in between (i.e. the jump counts are not sequential).
	if l:currentParsedJump.text !=# l:prevParsedJump.text ||
	\   l:currentParsedJump.count != (l:prevParsedJump.count + (a:isNewer ? -1 : 1))
	    if a:isNewer
		call insert(l:uniqueJumps, a:jumps[l:i], 0)
	    else
		call add(l:uniqueJumps, a:jumps[l:i])
	    endif
	endif
	let l:prevParsedJump = l:currentParsedJump
    endfor
"****D echo "****\n" join(l:uniqueJumps, "\n")
    return l:uniqueJumps
endfunction
function! s:FilterJumps( jumps, filter, isNewer )
    if empty(a:filter)
	return a:jumps
    elseif a:filter ==# 'local'
	return filter(a:jumps, 's:IsJumpInCurrentBuffer(EnhancedJumps#Common#ParseJumpLine(v:val))')
    elseif a:filter ==# 'remote'
	return s:FilterDuplicateSubsequentFiles(
	\   filter(a:jumps, '! s:IsJumpInCurrentBuffer(EnhancedJumps#Common#ParseJumpLine(v:val))'),
	\   a:isNewer
	\)
    else
	throw 'ASSERT: Unknown filter type ' . string(a:filter)
    endif
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
function! s:DoJump( count, isNewer )
    if a:count == 0
	execute "normal! \<C-\>\<C-n>\<Esc>"
	return 0
    endif

    try
	" There's just a beep when there's no newer/older jump position; this is
	" not a Vim error, so no exception is thrown.
	" We check the position before and after the jump to detect its success
	" in all cases.
	let l:originalPosition = ingo#record#Position(0)
	execute 'normal!' a:count . (a:isNewer ? "\<C-i>" : "\<C-o>")
	if ingo#record#Position(0) == l:originalPosition
	    return 0
	endif

	" When typed, CTRL-I/O open the fold at the jump target, but inside a
	" mapping or :normal this must be done explicitly via 'zv'.
	normal! zv

	return 1
    catch /^Vim\%((\a\+)\)\=:/
	" A Vim error occurs when there's an invalid jump position.
	call ingo#err#VimExceptionMsg('EnhancedJumps')
	return 0
    endtry
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
function! s:EchoFollowingMessage( followingJump, jumpDirection, filterName, fileJumpMessages )
    let l:following = EnhancedJumps#Common#ParseJumpLine(a:followingJump)
    if empty(a:followingJump)
	redraw
	call s:Echo(a:fileJumpMessages, printf('No %s%s jump position', a:jumpDirection, a:filterName))
    elseif s:IsInvalid(l:following.text)
	redraw
	call s:Echo(a:fileJumpMessages, printf('Next%s jump position is invalid', a:filterName))
    elseif s:IsJumpInCurrentBuffer(l:following)
	let l:header = printf('next%s: %d,%d ', a:filterName, l:following.lnum, l:following.col)
	call s:Echo(a:fileJumpMessages, l:header)
	let l:reservedColumns = len(l:header)	" l:header is printable ASCII-only, so can use len() for text width.
	if len(a:fileJumpMessages) == 1 && &cmdheight == 1
	    let l:reservedColumns += ingo#compat#strdisplaywidth(a:fileJumpMessages[0], l:reservedColumns) + 1  " The captured jump message may contain unprintable or non-ASCII characters; use strdisplaywidth(); it starts after the header, so consider its width, too.
	endif
	echohl Directory
	echon ingo#avoidprompt#Truncate(getline(l:following.lnum), l:reservedColumns)
	echohl None
    else
	call s:Echo(a:fileJumpMessages, printf('next%s: %s', a:filterName, s:BufferName(l:following.text)))
    endif
endfunction
function! EnhancedJumps#Jump( isNewer, filter )
    call ingo#err#Clear('EnhancedJumps')
    let l:filterName = (empty(a:filter) ? '' : ' ' . a:filter)
    let l:jumpDirection = (a:isNewer ? 'newer' : 'older')

    let l:jumps = s:FilterJumps(EnhancedJumps#Common#SliceJumpsInDirection(EnhancedJumps#Common#GetJumps('jumps'), a:isNewer), a:filter, a:isNewer)
    let l:count = s:GetCount()

    let l:targetJump = get(l:jumps, l:count - 1, '')
    let l:followingJump = get(l:jumps, l:count, '')
"****D echomsg '****' l:targetJump
"****D echomsg '****' l:followingJump
    " In case of filtering the count for the jump command does not correspond to
    " the given count and must be retrieved from the jump line.
    let l:jumpCount = (empty(a:filter) ? l:count : EnhancedJumps#Common#ParseJumpLine(l:targetJump).count)
"****D echomsg '****' l:count l:jumpCount
    if empty(l:targetJump)
	let l:countMax = len(l:jumps)
	if l:countMax == 0
	    call ingo#err#Set(printf('No %s%s jump position', l:jumpDirection, l:filterName), 'EnhancedJumps')
	else
	    call ingo#err#Set(printf('Only %d %s%s jump position%s', l:countMax, l:jumpDirection, l:filterName, (l:countMax > 1 ? 's' : '')), 'EnhancedJumps')
	endif

	" We still execute the actual jump command, even though we've determined
	" that it won't work. The jump command will still cause the customary
	" beep.
	call s:DoJump(l:jumpCount, a:isNewer)
    else
	let l:target = EnhancedJumps#Common#ParseJumpLine(l:targetJump)
	if s:IsInvalid(l:target.text)
	    " Do nothing here, the jump command will print an error.
	    call s:DoJump(l:jumpCount, a:isNewer)
	elseif s:IsJumpInCurrentBuffer(l:target)
	    " To avoid that the jump command's output overwrites the indication
	    " of the next jump position, the jump command is executed first and
	    " the indication only printed if the jump didn't cause an error.
	    if s:DoJump(l:jumpCount, a:isNewer)
		call s:EchoFollowingMessage(l:followingJump, l:jumpDirection, l:filterName, '')
	    endif
	else
	    " The next jump would move to another buffer. Stop and notify first,
	    " and only execute the jump if the same jump command (either
	    " repeating the original [count] or completely omitting it) is
	    " executed once more immediately afterwards.
	    let l:isSameCountAsLast = (! v:count || (exists('t:lastJumpCommandCount') && t:lastJumpCommandCount == v:count1))
	    let l:wasLastJumpBufferStop = l:isSameCountAsLast &&
	    \   exists('t:lastJumpBufferStop') &&
	    \   s:WasLastStop([a:isNewer, winnr(), l:target.text, localtime()], t:lastJumpBufferStop)
	    if l:wasLastJumpBufferStop || ! empty(a:filter)
		if g:EnhancedJumps_CaptureJumpMessages
		    redir => l:fileJumpCapture
			silent call s:DoJump(l:jumpCount, a:isNewer)
		    redir END
		else
		    let l:fileJumpCapture = ''
		    call s:DoJump(l:jumpCount, a:isNewer)
		endif

		" After the jump to another file, the filtered list for
		" remote files becomes wrong in case the following file is
		" the same as the original file (i.e. A(original) -> B(jump)
		" -> A(following)), because that jump was initially filtered
		"  out. To correctly determine the following jump, we must
		"  re-query and re-filter the jumps.
		"  In addition, the file paths to the file may have changed
		"  due to changes in CWD / 'autochdir'.
		"  For local files the jumplist gets updated with the text for
		"  the jumps, while it only contained the buffer name before.
		let l:followingJump = get(
		\	s:FilterJumps(EnhancedJumps#Common#SliceJumpsInDirection(EnhancedJumps#Common#GetJumps('jumps'), a:isNewer), a:filter, a:isNewer),
		\	0, ''
		\)

		call s:EchoFollowingMessage(l:followingJump, l:jumpDirection, l:filterName,
		\   filter(
		\	split(l:fileJumpCapture, "\n"),
		\	'! empty(v:val)'
		\   )
		\)
	    else
		" Memorize the current jump command, context, target and time
		" (except for the [count], which is stored separately) to be
		" able to detect the same jump command.
		let t:lastJumpBufferStop = [a:isNewer, winnr(), l:target.text, localtime()]

		" Memorize the given [count] to detect the same jump command,
		" and that it need not be specified on the repetition of the
		" jump command to overcome the warning.
		let t:lastJumpCommandCount = l:count

		call ingo#msg#WarningMsg(ingo#avoidprompt#Truncate(printf('next%s: %s', l:filterName, s:BufferName(l:target.text))))
		" Signal edge case via beep.
		execute "normal! \<C-\>\<C-n>\<Esc>"

		" We stop here, and do not execute the actual jump command.
		return 1
	    endif
	endif
    endif

    let t:lastJumpBufferStop = [a:isNewer, winnr(), '', 0]
    let t:lastJumpCommandCount = 0  " This is no repetition.

    return ! ingo#err#IsSet('EnhancedJumps')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
