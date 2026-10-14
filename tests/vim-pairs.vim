" Exercise actual mapped insert keys, rather than calling implementation helpers.
set noswapfile
call assert_true(&cursorline, 'Cursor row guide is disabled')
call assert_true(&cursorcolumn, 'Cursor column guide is disabled')
for s:background in ['dark', 'light']
    execute 'set background=' . s:background
    " OptionSet is suppressed during startup (-S), so simulate a theme reload.
    doautocmd ColorScheme
    call assert_equal(s:background ==# 'dark' ? '236' : '254', synIDattr(hlID('CursorLine'), 'bg', 'cterm'))
    call assert_equal(s:background ==# 'dark' ? '237' : '252', synIDattr(hlID('CursorColumn'), 'bg', 'cterm'))
    call assert_equal('', synIDattr(hlID('CursorLine'), 'underline', 'cterm'), 'Guide must not underline code')
endfor
colorscheme default
call assert_equal(&background ==# 'dark' ? '236' : '254', synIDattr(hlID('CursorLine'), 'bg', 'cterm'))
function! s:Input(keys, expected, filetype) abort
    enew!
    execute 'setlocal filetype=' . a:filetype
    call feedkeys('i' . a:keys . "\<Esc>", 'xt')
    call assert_equal(a:expected, getline(1, '$'), a:filetype . ': ' . string(a:keys))
endfunction

for s:ft in ['c', 'cpp', 'python', 'sh', 'javascript', 'go', 'rust', 'json', 'yaml', '']
    for s:pair in [['(', '()'], ['[', '[]'], ['{', '{}'], ['"', '""'], ["'", "''"], ['`', '``']]
        call s:Input(s:pair[0], [s:pair[1]], s:ft)
        call s:Input(s:pair[1], [s:pair[1]], s:ft)
        call s:Input(s:pair[0] . "\<BS>", [''], s:ft)
    endfor
    call s:Input('([{"x"}])', ['([{"x"}])'], s:ft)
    call s:Input("abc\<BS>", ['ab'], s:ft)
    call s:Input(')', [')'], s:ft)
endfor

call s:Input('int main()', ['int main()'], 'c')
call s:Input("int main() {\<CR>return 0;", ['int main() {', '    return 0;', '}'], 'c')
call s:Input("{\<CR>body", ['{', '    body', '}'], '')
call s:Input("values = [\<CR>1", ['values = [', '        1', '        ]'], 'python')
call s:Input("{\<CR>\"x\": [1, 2]", ['{', '  "x": [1, 2]', '}'], 'json')
call s:Input("print(\"it's\")", ["print(\"it's\")"], 'python')
call s:Input('"say \"hi\""', ['"say \"hi\""'], 'c')
call s:Input('\(', ['\('], 'python')
call s:Input('"""hello"""', ['"""hello"""'], 'python')
call s:Input(repeat("'", 3) . 'hello' . repeat("'", 3), [repeat("'", 3) . 'hello' . repeat("'", 3)], 'python')
call s:Input('"中文"', ['"中文"'], 'python')
call s:Input("中文\<BS>", ['中'], 'python')
call s:Input("\<C-v>(", ['('], 'c')
call s:Input('if (a < b)', ['if (a < b)'], 'c')

set paste
call s:Input('print("literal")', ['print("literal")'], 'python')
set nopaste
let g:linux_env_auto_pairs = 0
call s:Input('({[', ['({['], 'c')
let g:linux_env_auto_pairs = 1

if !empty(v:errors)
    for s:error in v:errors
        echomsg s:error
    endfor
    cquit
endif
qa!
