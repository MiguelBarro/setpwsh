" Tests for SetPwsh plugin

" vim feature
set nocp
set cpo&vim

"""""""""""""""""""""""""""""""""
" prolog and epilog for each test
"""""""""""""""""""""""""""""""""

" Hint the location of the plugin to test using the env variable SETPWSH_RUNTIMEDIR
func SetUp()
    call assert_true(
                \ exists('$SETPWSH_RUNTIMEDIR') && isdirectory($SETPWSH_RUNTIMEDIR),
                \ "Please set the env variable SETPWSH_RUNTIMEDIR to the plugin runtime dir"
                \ )
    let &packpath = $SETPWSH_RUNTIMEDIR
endfunc

" After each test remove the plugin
func TearDown()

    " Unload the plugin 
    let globals = [
                \ 'g:loaded_setpwsh',
                \ 'g:setpwsh_shell',
                \ 'g:setpwsh_enabled',
                \ 'g:setpwsh_ftp_from_wsl',
                \ 'g:setpwsh_ssh_from_wsl',
                \ 'g:setpwsh_enable_test',
                \ 'g:setpwsh_netrw_viewer'
                \ ]

    for g in globals
        if exists(g)
            execute $"unlet {g}"
        endif
    endfor

    if exists(':SetPwsh')
        delcommand SetPwsh
    endif

    " Restore default shell values
    set shell& shellcmdflag& shellpipe& shellredir&
        \ shellquote& shellxquote& shelltemp&

endfunc

"""""""""""
" Ancillary
"""""""""""

" Set powershell as shell
func s:set_powershell()
    "Load the plugin
    packadd setpwsh
    SetPwsh Desktop NoViewer

    call assert_equal('powershell', &shell, "SetPwsh")
endfunc

" Set pwsh as shell
func s:set_pwsh()
    "Load the plugin
    packadd setpwsh
    SetPwsh NoViewer

    call assert_equal('pwsh', &shell, "SetPwsh")
endfunc

"Remove BOM from string
func s:remove_bom(str)
    let start = 0
    const bom = [0xef, 0xbb, 0xbf]
    while index(bom, char2nr(a:str[start])) >= 0
        let start += 1
    endwhile
    return strpart(a:str, start)
endfunc

" :! (bang) testing helper function. Precondition: plugin already loaded
func s:bang_tests(shellname)

    const ref = ['a', 'b', 'c', 'd', 'e']

    " redir cannot capture shell output on vim because is directly forwarded
    " to the terminal
    if has("gui_running")
        " Check bang command
        redir => output
        exe "normal :!1..5 | \\% {[char]($_+96)}\<CR>\<CR>"
        redir END

        " let output = split(output, "\<CR>\<LF>")
        let output = split(output, '\r\n')
        call assert_equal(ref, output[1:5], a:shellname)
    endif

    " Check read from bang
    let cline = getpos('$')[1]
    read !1..5 | \% { [char]($_+96) }
    call assert_equal(ref , getline(cline+1, cline+5), a:shellname)

    " Check filtering: :'<,'>!"-->$_<--"
    exe (cline+1) . ',' . (cline+5) . '!"-->$_<--"'
    let fref = map(copy(ref), '"-->".v:val."<--"')
    call assert_equal(fref , getline(cline+1, cline+5), a:shellname)

    " Check using buffer as stdin
    if has("gui_running")
        redir => output
        exe $"normal :{cline+1},{cline+5}w !$_ -replace '--', ''\<CR>\<CR>"
        redir END
        let gref = map(copy(ref), '">".v:val."<"')
        let output = split(trim(output), '\r\n')
        call assert_equal(gref , output[0:4], a:shellname)
    endif
endfunc

"system() testing helper function. Precondition: plugin already loaded
func s:system_tests(shellname)

    const ref = ['a', 'b', 'c', 'd', 'e']

    " On gVim with powershell desktop the temporary files'
    " BOM cannot be removed (the powershell script can not
    " access its name).
    " The test manually removes the BOM in the specific case.

    " Check system()
    let output = system("1..5 | % {[char]($_+96)}")
    if a:shellname ==# "Desktop" && has("gui_running")
        let output = s:remove_bom(output)
    endif
    let output = split(output)
    call assert_equal(ref , output, a:shellname)

    let output = system('% { "-->$_<--" }', "vim") 
    if a:shellname ==# "Desktop" && has("gui_running")
        let output = s:remove_bom(output)
    endif
    call assert_equal("-->vim<--" , trim(output), a:shellname)

    let output = system('% { "-->$_<--" }', ref) 
    if a:shellname ==# "Desktop" && has("gui_running")
        let output = s:remove_bom(output)
    endif
    let output = split(output)
    let fref = map(copy(ref), '"-->".v:val."<--"')
    call assert_equal(fref, output, a:shellname)

"   TODO: systemlist() Not working for now, it must be fixed
"   " Check systemlist()
"   let output = systemlist("1..5 | % {[char]($_+96)}")
"   call assert_equal(ref , output, "powershell")
 
    " Backtick execution is a particular case of system()
    " open this very file
    let this_script = expand("<script>")
    exe $"view `(Get-Item -Path {this_script}).FullName`"
    call assert_equal(bufnr(''), bufnr(this_script), a:shellname)

endfunc

"script execution helper function. Precondition: plugin already loaded
func s:script_tests(shellname)

    const ref = ['a', 'b', 'c', 'd', 'e']
    const fref = map(copy(ref), '"-->".v:val."<--"')

    " Check script execution
    " - Create a dummy script
    let scriptname = tempname() . '.ps1'
    call writefile(['process { "-->$_<--" }'], scriptname, 'D')

    " gVim on windows must use $input for filtering
    if !has('win32') || !has("gui_running")
        " - Create a dummy input: a, b, c, d, e
        let cline = getpos('$')[1]
        call append(cline, ref)

        " - Use the script as a filter: :<,>!./filter.ps1
        exe $"normal :{cline+1},{cline+5}!{scriptname}\<CR>\<CR>"
        call assert_equal(fref , getline(cline+1, cline+5), a:shellname)
    endif

    " $input for filtering works everywhere
    " - Create a dummy input: a, b, c, d, e
    let cline = getpos('$')[1]
    call append(cline, ref)

    " - Use the script as a filter: :<,>!./filter.ps1
    exe $"normal :{cline+1},{cline+5}!$input | {scriptname}\<CR>\<CR>"
    call assert_equal(fref , getline(cline+1, cline+5), a:shellname)

endfunc

"binary execution helper function. Precondition: plugin already loaded
func s:binary_tests(shellname)

    const ref = ['a', 'b', 'c', 'd', 'e']

    " Check binary execution
    if has('win32')
        let xxd_sref = "00000000: 610d 0a62 0d0a 630d 0a64 0d0a 650d 0a    a..b..c..d..e.."
        if has("gui_running")
            " gVim uses pipes instead of temp files. The pipes use LF (0xa) as line ending
            let xxd_ref = "00000000: 610a 620a 630a 640a 650a                 a.b.c.d.e."
        else
            let xxd_ref = xxd_sref
        endif
    else
        let xxd_sref = "00000000: 610a 620a 630a 640a 650a                 a.b.c.d.e."
        let xxd_ref = xxd_sref
    endif

    " Use xxd binary as a filter: :<,>!xxd
    let cline = getpos('$')[1]
    call append(cline, ref)
    exe $"normal :{cline+1},{cline+5}!xxd\<CR>\<CR>"
    call assert_equal(xxd_ref, getline(cline+1), a:shellname)

    " $input for filtering works everywhere
    " - Create a dummy input: a, b, c, d, e
    let cline = getpos('$')[1]
    call append(cline, ref)

    " - Use xxd binary as a filter: :<,>!$input | xxd
    exe $"normal :{cline+1},{cline+5}!$input | xxd\<CR>\<CR>"
    call assert_equal(xxd_sref, getline(cline+1), a:shellname)

endfunc

" Check on error propagation via v:shell_error
func s:shell_error_tests(shellname)

    " Errors on system() calls
    " Check error on unknown command
    try
        call system("unknown-command")
    catch /\<E282:/
        call assert_notequal(0, v:shell_error, a:shellname)
    endtry

    " known command
    let command = has("win32") ? "dir" : "ls"
    call system(command)
    call assert_equal(0, v:shell_error, a:shellname)

    " Check error on binary command
    call system("xxd unknown-file")
    call assert_notequal(0, v:shell_error, a:shellname)

    let this_script = expand("<script>")
    exe $"call system(\"xxd {this_script}\")"
    call assert_equal(0, v:shell_error, a:shellname)

    " Check error on cmdlet
    call system("Get-Item -Path unknown-file")
    call assert_notequal(0, v:shell_error, a:shellname)

    call system($"Get-Item -Path {this_script}")
    call assert_equal(0, v:shell_error, a:shellname)
 
    " Errors on bang commands
    " Check error on unknown command
    exe "normal :!unknown-command\<CR>\<CR>"
    call assert_notequal(0, v:shell_error, a:shellname)

    " Check error on known command
    exe $"normal :!{command}\<CR>\<CR>"
    call assert_equal(0, v:shell_error, a:shellname)

    " Check error on binary command
    exe "normal :!xxd unknown-file\<CR>\<CR>"
    call assert_notequal(0, v:shell_error, a:shellname)

    exe $"normal :!xxd {this_script}\<CR>\<CR>"
    call assert_equal(0, v:shell_error, a:shellname)

    " Check error on cmdlet
    exe "normal :!Get-Item -Path unknown-file\<CR>\<CR>"
    call assert_notequal(0, v:shell_error, a:shellname)

    exe $"normal :!Get-Item -Path {this_script}\<CR>\<CR>"
    call assert_equal(0, v:shell_error, a:shellname)

    " Check filtering errors
    new Xdummy

    call setline(1, ['unknown-file'])
    exe "normal :1,1!xxd $_\<CR>\<CR>"
    call assert_notequal(0, v:shell_error, a:shellname)

    call setline(1, ['unknown-file'])
    exe "normal :1,1!Get-Item -Path $_\<CR>\<CR>"
    call assert_notequal(0, v:shell_error, a:shellname)

    call setline(1, [this_script])
    exe "normal :1,1!xxd $_\<CR>\<CR>"
    call assert_equal(0, v:shell_error, a:shellname .. " 1,1!xxd $_")

    call setline(1, [this_script])
    exe "normal :1,1!Get-Item -Path $_\<CR>\<CR>"
    call assert_equal(0, v:shell_error, a:shellname .. " 1,1!Get-Item -Path $_")

endfunc

" TODO: Cannot check gVim reading stdin because the following does not work:
" call test_feedinput(":read !$input | \\% { \"Entering $_\" }\<CR>a\<CR>b\<CR>c\<CR>\x04\<CR>")

"""""""
" Tests
"""""""

if executable('pwsh')

    func Test_setpwsh_bang_core()
        call s:set_pwsh()
        call s:bang_tests("Core")
    endfunc

    func Test_setpwsh_system_core()
        call s:set_pwsh()
        call s:system_tests("Core")
    endfunc

    func Test_setpwsh_script_core()
        call s:set_pwsh()
        call s:script_tests("Core")
    endfunc

    func Test_setpwsh_binary_core()
        call s:set_pwsh()
        call s:binary_tests("Core")
    endfunc

    func Test_setpwsh_shell_error_core()
        call s:set_pwsh()
        call s:shell_error_tests("Core")
    endfunc

endif " pwsh

" executable('powershell') doesn't work because powershell is
" an alias of pwsh in linux & mac
if has('win32')

    func Test_setpwsh_bang_desktop()
        call s:set_powershell()
        call s:bang_tests("Desktop")
    endfunc

    func Test_setpwsh_system_desktop()
        call s:set_powershell()
        call s:system_tests("Desktop")
    endfunc

    func Test_setpwsh_script_desktop()
        call s:set_powershell()
        call s:script_tests("Desktop")
    endfunc

    func Test_setpwsh_binary_desktop()
        call s:set_powershell()
        call s:binary_tests("Desktop")
    endfunc

    func Test_setpwsh_shell_error_desktop()
        call s:set_powershell()
        call s:shell_error_tests("Desktop")
    endfunc

endif " powershell

" vim: set sw=4 ts=4 et:
