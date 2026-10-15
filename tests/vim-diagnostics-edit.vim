" Observations only: every edit and row change is sent by the PTY driver.
set nomore
let s:case = json_decode(join(readfile(g:diagnostic_edit_case), "\n"))
let s:serial = 0
let g:ale_c_cc_executable = s:case.compiler

function! s:Capture() abort
    let s:serial += 1
    let l:signs = sign_getplaced(bufnr(''), {'group': '*'})[0].signs
    call filter(l:signs, 'v:val.name =~# "^ALE" && v:val.name !=# "ALEDummySign"')
    let l:state = {'serial': s:serial, 'mode': mode(1), 'line': line('.'),
                \ 'loclist': getloclist(0), 'signs': l:signs, 'lines': getline(1, '$'),
                \ 'checking': ale#engine#IsCheckingBuffer(bufnr('')),
                \ 'checks': filereadable(s:case.calls) ? len(readfile(s:case.calls)) : 0}
    call writefile([json_encode(l:state)], s:case.output . '.tmp')
    call rename(s:case.output . '.tmp', s:case.output)
endfunction

" <Cmd> deliberately preserves INSERT, unlike <C-O>: or Escape-based probes.
nnoremap <silent> <C-G> <Cmd>call <SID>Capture()<CR>
inoremap <silent> <C-G> <Cmd>call <SID>Capture()<CR>
inoremap <silent> <C-L> <Cmd>ALELint<CR>
inoremap <C-E> <End>
execute 'edit ' . fnameescape(s:case.source)
