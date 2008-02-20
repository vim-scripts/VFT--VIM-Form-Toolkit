" VFT-Test 0.1 by Alex Kunin <alexkunin@gmail.com>
" Sample plugin that utilizes VFT - VIM Form Toolkit.

let s:file = expand('<sfile>:p')

function! s:RunForm()
    tabnew

    call setline(1, readfile(s:file))
    execute "normal 1Gd/^finish$\<CR>dd"

    let l:form = vft#InitCurBuf()

    call l:form.setItems('colorscheme', map(split(glob("$VIMRUNTIME/colors/*.vim"), "\n"), 'fnamemodify(v:val, ":t:r")'))

    call l:form.setValues({
        \ 'colorscheme':exists('g:colors_name') ? g:colors_name : '',
        \ 'ruler':&ruler,
        \ 'wildmenu':&wildmenu,
        \ 'wrap':&wrap,
        \ 'hlsearch':&hlsearch,
        \ 'incsearch':&incsearch,
        \ 'foldmethod':&foldmethod
    \ })

    function! VftTest_ChangeCallback(id, value)
        echo 'Control ' . a:id . ' got new value ' . a:value
        if a:id == 'colorscheme'
            execute 'colorscheme ' . a:value
        elseif a:id == 'foldmethod'
            execute 'set ' . a:id . '=' . a:value
        else
            execute 'set ' . a:id . (a:value ? '' : '!')
        endif
    endfunction

    call l:form.setChangeCallback(function('VftTest_ChangeCallback'))

    function! VftTest_ButtonCallback(id)
        tabclose
        if a:id == 'SOURCE'
            tabnew
            execute 'edit ' . s:file
        endif
    endfunction

    call l:form.setButtonCallback(function('VftTest_ButtonCallback'))
endfunction

nmap <silent> <F5> :call <SID>RunForm()<CR>

function! s:GetTail(name)
    let l:lines = readfile(expand('<sfile>'))
endfunction

finish

    This plugin demonstrates    Tip: use Tab/Shift-Tab to navigate,
    comboboxes, checkboxes,     Space or Enter to change values.
    radio buttons, buttons.     Bugs included. No mouse, sorry.

        <Close>|CLOSE|                      <View Source>|SOURCE|

    ---------------------------------------------------------

    Colorscheme: [________|v] |colorscheme|

    General options:            Search behavior:

        [ ] Ruler |ruler|           [ ] Highlight matches |hlsearch|
        [ ] Wildmenu |wildmenu|     [ ] Incremental search |incsearch|
        [ ] Text wrapping |wrap|

    Folding method:

        ( ) manual |foldmethod|     ( ) marker |foldmethod|
        ( ) indent |foldmethod|     ( ) syntax |foldmethod|
        ( ) expr |foldmethod|       ( ) diff |foldmethod|

