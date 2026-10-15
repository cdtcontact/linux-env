" Run real asynchronous linters and record their displayed diagnostics.
set nomore
let s:case = json_decode(join(readfile(g:diagnostic_case_path), "\n"))
let s:result = {}
let g:ale_history_log_output = 1
" ALE normally updates the window list in a later timer, after ALELintPost.
" Use its supported test mode so the recorded list belongs to this lint pass.
let g:ale_set_lists_synchronously = 1
let g:diagnostic_lint_posts = 0
augroup linux_env_diagnostic_test
    autocmd!
    autocmd User ALELintPost let g:diagnostic_lint_posts += 1
augroup END

function! s:WaitForLint(previous) abort
    let l:start = reltime()
    while g:diagnostic_lint_posts <= a:previous || ale#engine#IsCheckingBuffer(bufnr(''))
        if reltimefloat(reltime(l:start)) > 15
            throw 'Timed out waiting for the external checker'
        endif
        sleep 20m
    endwhile
endfunction

function! s:LeaveInsert() abort
    " ALE 4 uses ModeChanged on recent Vim; older releases use InsertLeave.
    if exists('#ALEEvents#ModeChanged')
        doautocmd <nomodeline> ModeChanged i:n
    else
        doautocmd <nomodeline> InsertLeave
    endif
endfunction

function! s:State() abort
    let l:signs = sign_getplaced(bufnr(''), {'group': '*'})[0].signs
    call filter(l:signs, 'v:val.name =~# "^ALE" && v:val.name !=# "ALEDummySign"')
    return {'loclist': getloclist(0), 'signs': l:signs, 'filetype': &filetype}
endfunction

try
    " Ex mode skips ordinary plugin startup. Load the configured runtime's
    " plugin explicitly, as the interactive Vim startup would.
    runtime plugin/ale.vim
    if exists(':ALELint') != 2
        throw 'The installed ALE plugin was not loaded by the Vim configuration'
    endif
    execute 'edit ' . fnameescape(s:case.path)
    let s:before = g:diagnostic_lint_posts
    ALELint
    call s:WaitForLint(s:before)
    let s:result.initial = s:State()
    let s:result.error_sign = sign_getdefined('ALEErrorSign')[0].text
    let s:result.warning_sign = sign_getdefined('ALEWarningSign')[0].text

    " A semantic error can suppress compiler warnings. Check an independently
    " valid warning-only buffer before clearing it with the final fix.
    if has_key(s:case, 'warning')
        call setline(1, s:case.warning)
        let s:before = g:diagnostic_lint_posts
        call s:LeaveInsert()
        call s:WaitForLint(s:before)
        let s:result.warning = s:State()
    endif

    " No :write: this proves checking uses the corrected buffer, not old disk
    " contents, and that the normal leave-insert-mode event refreshes results.
    call setline(1, s:case.fixed)
    let s:before = g:diagnostic_lint_posts
    call s:LeaveInsert()
    call s:WaitForLint(s:before)
    let s:result.fixed = s:State()
    let s:result.disk_after_bufferlint = readfile(s:case.path)

    " Exercise the other advertised automatic trigger, saving a buffer.
    call setline(1, s:case.broken)
    let s:before = g:diagnostic_lint_posts
    write
    call s:WaitForLint(s:before)
    let s:result.saved = s:State()
catch
    let s:result.failure = v:exception . ' at ' . v:throwpoint
    let s:result.messages = execute('messages')
    if exists(':ALEInfo') == 2
        let s:result.ale_info = execute('ALEInfo')
    endif
endtry
call writefile([json_encode(s:result)], s:case.output)
if has_key(s:result, 'failure')
    cquit 1
endif
qa!
