" VIM Form Toolkit 0.1 by Alex Kunin <alexkunin@gmail.com>

function! s:put(x, y, string)
    let l:line = getline(a:y)
    call setline(a:y, l:line[: a:x - 2] . a:string . l:line[a:x - 1 + strlen(a:string):])
endfunction

let s:Control = {
    \ 'type':'',
    \ 'id':'',
    \ 'label':'',
    \ 'index':-1,
    \ 'x':-1,
    \ 'y':-1,
    \ 'width':-1,
    \ 'fullWidth':-1
\}

function! s:Control.init(type, id, label, index, x, y, width, fullWidth) dict
    let self.type = a:type
    let self.id = a:id
    let self.label = a:label
    let self.index = a:index
    let self.x = a:x
    let self.y = a:y
    let self.width = a:width
    let self.fullWidth = a:fullWidth
endfunction

function! s:Control.hitTest(x, y, ...) dict
    if !a:0
        return a:y == self.y && a:x >= self.x && a:x < self.x + self.fullWidth
    elseif a:1 < 0
        return a:y == self.y && a:x >= self.x
    else
        return a:y == self.y && a:x < self.x + self.fullWidth
    endif
endfunction

function! s:Control.focus(...) dict
    let l:focusInputArea = a:0 ? a:1 : 0

    if self.type == 'checkbox' || self.type == 'radio'
        call cursor(self.y, self.x + 1)
    elseif self.type == 'combobox'
        call cursor(self.y, self.x + (l:focusInputArea ? + 1 : self.width - 2))
    elseif self.type == 'button'
        call cursor(self.y, self.x + 1)
    endif
endfunction

function! s:Control.setValue(value) dict
    if self.type == 'checkbox'
        call s:put(self.x + 1, self.y, (a:value ? 'X' : ' '))
    elseif self.type == 'radio'
        call s:put(self.x + 1, self.y, (a:value ? '+' : ' '))
    elseif self.type == 'combobox'
        call s:put(self.x + 1, self.y, printf('%-*s', self.width - 4, a:value)[:self.width - 5])
    endif
endfunction

let s:Form = {
    \ 'patterns':{
        \ 'checkbox':'\[[ X]\]',
        \ 'radio':'([ +])',
        \ 'combobox':'\[[^|]\+|v\]',
        \ 'button':'<[^>]\+>'
    \ },
    \ 'controls':[],
    \ 'content':[],
    \ 'activeCombo':-1,
    \ 'popupActive':0,
    \ 'values':{},
    \ 'items':{},
    \ 'changeCallback':0,
    \ 'buttonCallback':0
\ }

function! s:Form.detectControlType(string) dict
    for [ l:type, l:pattern ] in items(self.patterns)
        if match(a:string, '^' . l:pattern . '$') != -1
            return l:type
        endif
    endfor

    throw "Can't detect control type for string '" . a:string . "'."
endfunction

function! s:Form.initialize(...) dict
    let b:FormInstance = self
    call self.parseControls()
    call self.tuneHighlighting()
    call self.tuneMappings()
    call self.focus(a:0 ? a:1 : 0)
endfunction

function! s:Form.parseControls() dict
    let self.controls = []
    let l:y = 0
    let l:lists = {}

    for l:line in getline('^', '$')
        let l:y += 1
        let l:pattern = '\(' . join(values(self.patterns), '\|') . '\)\(\s*\)\([^|]*\)\s*|\(\w\+\)|'
        let l:start = 0

        while 1
            let l:matches = matchlist(l:line, l:pattern, l:start)

            if empty(l:matches) | break | endif

            let l:start = matchend(l:line, l:pattern, l:start)

            let l:control = deepcopy(s:Control)

            call l:control.init(
                \ self.detectControlType(l:matches[1]),
                \ l:matches[4],
                \ l:matches[3],
                \ len(self.controls),
                \ l:start - strlen(l:matches[0]) + 1,
                \ l:y,
                \ strlen(l:matches[1]),
                \ strlen(l:matches[1]) + strlen(l:matches[2]) + strlen(l:matches[3])
            \ )

            call add(self.controls, l:control)

            if l:control.type == 'radio'
                if !has_key(l:lists, l:control.id)
                    let l:lists[l:control.id] = []
                endif

                call add(l:lists[l:control.id], l:control.label)
            endif
        endwhile
    endfor

    for [ l:id, l:list ] in items(l:lists)
        call self.setItems(l:id, l:list)
    endfor
endfunction

function! s:Form.setChangeCallback(callback) dict
    let self.changeCallback = a:callback
endfunction

function! s:Form.setButtonCallback(callback) dict
    let self.buttonCallback = a:callback
endfunction

function! s:Form.tuneHighlighting() dict
    syntax clear

    syntax match Ignore /|\w\+|/

    for l:pattern in values(self.patterns)
        execute 'syntax match Special /' . l:pattern . '/'
    endfor
endfunction

function! s:Form.tuneMappings() dict
    nmap <silent> <buffer> <S-Tab> :call b:FormInstance.focusPrevious()<CR>
    nmap <silent> <buffer> <Tab> :call b:FormInstance.focusNext()<CR>
    nmap <silent> <buffer> <Space> :call b:FormInstance.touchCurrent()<CR>
    nmap <silent> <buffer> <CR> :call b:FormInstance.touchCurrent()<CR>
    nmap <silent> <buffer> <LeftRelease> <ESC>:call b:FormInstance.touchCurrent()<CR>

	imap <buffer> <BS> <C-R>=''<CR>
	imap <buffer> <C-H> <C-R>=''<CR>
	imap <buffer> <C-L> <C-R>=''<CR>
	"imap <buffer> <C-Y> <C-R>=''<CR>
	"imap <buffer> <C-E> <C-R>=''<CR>
	imap <buffer> <Space> <C-Y><Esc>
	imap <buffer> <Enter> <C-Y><Esc>
	"imap <buffer> <Tab> <C-R>=''<CR>
	"imap <buffer> <Esc> <C-R>='<C-E>'

    autocmd InsertEnter <buffer> call b:FormInstance.onInsertEnter()
    autocmd InsertLeave <buffer> call b:FormInstance.onInsertLeave()
    autocmd BufHidden <buffer> autocmd! * <buffer>

    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
endfunction

function! s:Form.getItems(id) dict
    return get(self.items, a:id, [])
endfunction

function! s:Form.setItems(id, list) dict
    let self.items[a:id] = a:list
    if self.getCurrentItemIndex(a:id) == -1 && !empty(a:list)
        call self.setValue(a:id, a:list[0])
    endif
endfunction

function! s:Form.getCurrentItemIndex(id) dict
    return index(self.getItems(a:id), self.getValue(a:id))
endfunction

function! s:Form.getValue(id) dict
    return get(self.values, a:id, 0)
endfunction

function! s:Form.getValues() dict
    let l:result = {}

    for l:control in self.controls
        let l:result[l:control.id] = self.getValue(l:control.id)
    endfor

    return l:result
endfunction

function! s:Form.setValue(id, value) dict
    let l:control = self.getControl(a:id)

    if has_key(self.values, a:id)
        unlet self.values[a:id]
    endif

    if l:control.type == 'checkbox'
        call l:control.setValue(a:value)
        let self.values[a:id] = a:value
    elseif l:control.type == 'radio'
        let self.values[a:id] = a:value
        let l:index = self.getCurrentItemIndex(a:id)
        let l:idx = 0
        for i in range(len(self.controls))
            if self.controls[i].id == l:control.id
                call self.controls[i].setValue(l:idx == l:index)
                let l:idx += 1
            endif
        endfor
    elseif l:control.type == 'combobox'
        call l:control.setValue(a:value)
        let self.values[a:id] = a:value
    endif

    if type(self.changeCallback) == type(function('tr'))
        call self.changeCallback(a:id, self.getValue(a:id))
    endif
endfunction

function! s:Form.setValues(map) dict
    for [ l:id, l:value ] in items(a:map)
        call self.setValue(l:id, l:value)
    endfor
endfunction

function! s:Form.getCurrentControlIndex(...) dict
    let l:guess = a:0 ? a:1 : 1
    let [ l:line, l:col ] = getpos('.')[1:2]

    while 1
        let l:index = -1
        let l:controls = filter(copy(self.controls), 'v:val.y == l:line')

        for l:control in l:controls
            if l:control.hitTest(l:col, l:line)
                return l:control.index
                break
            endif
        endfor

        if l:index == -1
            if l:guess == 0
                return -1
            endif

            for l:control in l:controls
                if l:control.hitTest(l:col, l:line, l:guess)
                    return l:control.index
                    break
                endif
            endfor
        endif

        if l:index == -1
            if l:guess > 0
                let l:line += 1
            else
                let l:line -= 1
            endif

            if l:line < 1 || l:line > line('$')
                return -1
            endif

            if l:guess > 0
                let l:col = 1
            else
                let l:col = strlen(getline(l:line))
            endif
        endif
    endwhile
endfunction

function! s:Form.getControl(idOrIndex) dict
    if type(a:idOrIndex) == type('')
        let l:index = -1

        for i in range(len(self.controls))
            if self.controls[i].id == a:idOrIndex
                let l:index = i
                break
            endif
        endfor
    else
        let l:index = a:idOrIndex
    endif

    return self.controls[l:index]
endfunction

function! s:Form.focusPrevious() dict
    let l:index = self.getCurrentControlIndex(0)

    if l:index == -1
        let l:index = self.getCurrentControlIndex(-1)
    else
        let l:index = (l:index - 1 + len(self.controls)) % len(self.controls)
    endif

    call self.focus(l:index)
endfunction

function! s:Form.focusNext() dict
    let l:index = self.getCurrentControlIndex(0)

    if l:index == -1
        let l:index = self.getCurrentControlIndex(+1)
    else
        let l:index = (l:index + 1) % len(self.controls)
    endif

    call self.focus(l:index)
endfunction

function! s:Form.focus(idOrIndex, ...) dict
    let l:focusInputArea = a:0 ? a:1 : 0
    let l:control = self.getControl(a:idOrIndex)
    call l:control.focus(l:focusInputArea)
endfunction

function! s:Form.touchCurrent() dict
    let l:control = self.getControl(self.getCurrentControlIndex(+1))

    call self.focus(l:control.index, 1)

    if l:control.type == 'checkbox'
        call self.setValue(l:control.id, !self.getValue(l:control.id))
    elseif l:control.type == 'radio'
        let l:index = 0
        for l:ctrl in self.controls
            if l:ctrl.id == l:control.id
                if l:ctrl.index == l:control.index
                    call self.setValue(l:control.id, self.getItems(l:control.id)[l:index])
                    break
                endif
                let l:index += 1
            endif
        endfor
    elseif l:control.type == 'combobox'
        let l:index = self.getCurrentItemIndex(l:control.id)
        let l:down = l:index > 0 ? join(map(range(0, l:index - 1), '"<C-N>"'), '') : ''
        execute 'imap <buffer> . <C-R>=b:FormInstance.onComboboxShow()<CR>' . l:down
        call l:control.setValue('')
        let self.activeCombo = l:control.index
        let self.popupActive = 1
        call feedkeys('R.', 'm')
    elseif l:control.type == 'button' && type(self.buttonCallback) == type(function('tr'))
        call self.buttonCallback(l:control.id)
    endif
endfunction

function! s:Form.onComboboxShow() dict
    call complete(col('.'), self.getItems(self.controls[self.activeCombo].id))
    return ''
endfunc

function! s:Form.onInsertEnter() dict
    let self.content = getline('^', '$')
endfunction

function! s:Form.onInsertLeave() dict
    if self.popupActive
        let self.popupActive = 0
        let l:control = self.controls[self.activeCombo]
        let l:value = getline('.')[l:control.x : col('.') - 1]
        call setline(1, self.content)
        call self.setValue(l:control.id, l:value)
        call self.focus(self.activeCombo)
    else
        call setline(1, self.content)
        call self.focus(self.getControl(self.getCurrentControlIndex(+1)).index)
    endif
endfunction

function! vft#InitCurBuf()
    let l:form = deepcopy(s:Form)
    call l:form.initialize()
    return l:form
endf
