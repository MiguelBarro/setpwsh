" setpwsh.vim: Sets up pwsh as a full fledge shell
" GetLatestVimScripts: 6106 1 :AutoInstall: setpwsh.vmb

if exists('g:loaded_setpwsh') || &cp
  finish
endif

let g:loaded_setpwsh = '1.1.1' " version number

" dummy version replaced by the actual ones if possible
command -nargs=* SetPwsh

" Check if powershell is present
if !executable('pwsh')
    if has('win32')
        " fallback to desktop version (always available)
        let g:setpwsh_shell = "powershell"
    else
        if exists('g:setpwsh_enabled') && g:setpwsh_enabled
            echomsg "setpwsh plugin: pwsh is not available in the system"
            finish
        endif
    endif
endif

let s:save_cpo = &cpo
set cpo&vim

" Options:
" g:setpwsh_enabled        -> if 1 automatically sets up powershell/pwsh when the plugin is loaded
" g:setpwsh_shell          -> only for windows. Chooses between pwsh (core) or powershell (desktop). Defaults pwsh.
" g:setpwsh_ftp_from_wsl   -> if 1 sets up netrw global options to rig wsl ftp (only windows). Defaults 0.
" g:setpwsh_ssh_from_wsl   -> if 1 sets up netrw global options to rig wsl ssh & scp (only windows). Defaults 0.
" g:setpwsh_enable_test    -> if 1 performs testing for privileges (slows down startup). Defaults 0.
" g:setpwsh_netrw_viewer   -> if 1 sets up the shell to be used as netrw viewer (only windows). Defaults 1.
" $setpwsh_encoding        -> decides powershell binary encoding for input and output pipes. Defaults utf8.
"                             Possible values: ascii, utf7, utf8, unicode, uft32

if has('win32')
    if !exists('g:setpwsh_shell') || g:setpwsh_shell !=? "powershell"
        let g:setpwsh_shell = "pwsh"
    endif
else
    let g:setpwsh_shell = "pwsh"
endif

if !exists('g:setpwsh_enabled')
    let g:setpwsh_enabled = 0
endif

if !exists('g:setpwsh_ftp_from_wsl')
    let g:setpwsh_ftp_from_wsl = 0
endif

if !exists('g:setpwsh_ssh_from_wsl')
    let g:setpwsh_ssh_from_wsl = 0
endif

if !exists('g:setpwsh_enable_test')
    let g:setpwsh_enable_test = 0
endif

if !exists('g:setpwsh_netrw_viewer')
    let g:setpwsh_netrw_viewer = 1
endif

if !exists('$setpwsh_encoding')
  let $setpwsh_encoding = 'utf8'
endif

" Commands:
" SetPwsh -> Sets up the shell and related options
" Arguments:
" "Desktop" -> sets up the desktop version of powershell (only windows)
" "NoViewer" -> do not associated as netrw viewer (only windows)
" "FtpFromWsl" -> sets up netrw global options to rig wsl ftp (only windows)
" "SshFromWsl" -> sets up netrw global options to rig wsl ssh & scp (only windows)
command! -nargs=* -complete=customlist,s:cspwsh SetPwsh call s:SetPwsh(<f-args>)

function s:cspwsh(...)
    return ["Desktop", "FtpFromWsl", "SshFromWsl", "NoViewer"]
endfunction

let s:script_dir = expand('<sfile>:p:h') .. '/../scripts/'

if has('win32')

    function s:SetPwsh(...) abort

        " Check if pwsh has privileges to query the command line
        " (on network connections this privilege may be revoked)
        if g:setpwsh_enable_test

            if g:setpwsh_shell ==? "pwsh"
                let s:testcmd = "KABHAGUAdAAtAFAAcgBvAGMAZQBzAHMAIAAtAEkAZAAgACQAcABpAGQAKQAuAEM"
                              \."AbwBtAG0AYQBuAGQATABpAG4AZQAgACsAIAAiAHcAbwByAGsAcwAiAA=="
            else 
                let s:testcmd = "WwBTAHkAcwB0AGUAbQAuAEUAbgB2AGkAcgBvAG4AbQBlAG4AdABdADoAOgBDAG8A"
                              \."bQBtAGEAbgBkAEwAaQBuAGUAIAArACAAIgB3AG8AcgBrAHMAIgA="
            endif

            if system(g:setpwsh_shell . " -NoLogo -NoProfile -EncodedCommand " . s:testcmd) !~ 'works'
                echomsg "setpwsh plugin: pwsh has not enough privileges in the system"
                return
            endif
        endif

        if executable('pwsh')
            set shell=pwsh
        else
            set shell=powershell
        endif

        if has('gui_running')
            let &shellcmdflag='-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "'
                \   . s:script_dir . 'gvim_pwsh_proxy.ps1"'
            set shellpipe=\|\ Tee-Object\ -FilePath\ %s\ -Encoding\ utf8
        else
            let &shellcmdflag='-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "'
                \   . s:script_dir . 'vim_pwsh_proxy.ps1"' 
            set shellpipe=2>&1\ \|\ Tee-Object\ -FilePath\ %s\ -Encoding\ utf8
        endif

        set shellredir=>%s
        set shellquote=
        set shellxquote=(
        set nostmp

        " Using wsl ssh from netrw (see :help netrw-p14):
        let l:ignore_wsl = 0
        if (join(a:000) =~? 'wsl') && !executable('wsl')
            echomsg "setpwsh plugin: wsl is not installed"
            let l:ignore_wsl = 1
        endif

        " + temporary filenames must be translated by wslpath
        " + g:netrw_ssh|scp_cmd must be redirected to wsl binaries and must be 'executable' files
        let l:enable_wsl_tools = 0
        for s in a:000

            if s ==? "Desktop"
                set shell=powershell
            elseif s ==? "NoViewer"
                let g:setpwsh_netrw_viewer = 0
            elseif s ==? "FtpFromWsl" && !l:ignore_wsl
                if has('gui_running')
                    " ftp.ps1 is fed from the pipeline
                    let g:netrw_ftp_cmd = "$input | " .s:script_dir . "ftp.ps1"
                else
                    let g:netrw_ftp_cmd = s:script_dir . "ftp.ps1"
                endif
                let l:enable_wsl_tools = 1
            elseif s ==? "SshFromWsl" && !l:ignore_wsl
                let g:netrw_ssh_cmd = s:script_dir . "ssh.ps1"
                let g:netrw_scp_cmd = s:script_dir . "scp.ps1"
                let l:enable_wsl_tools = 1
            else
                echomsg "setpwsh plugin: SetPwsh unknown argument " . s
            endif

        endfor

        " engage viewer if requested
        if g:setpwsh_netrw_viewer
            if exists('g:Openprg')
                echoe "setpwsh plugin: Openprg is already set and is not replaced"
            else
                let g:Openprg = &shell . ' -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "'
                    \   . s:script_dir . 'openprg_pwsh_proxy.ps1"'
            endif
        endif

        " + PATHEXT must be modified to include .PS1 extension (this way executable() will be powershell friendly)
        if l:enable_wsl_tools
            if !($PATHEXT=~'\.PS1')
                let $PATHEXT.=';.PS1'
            endif
            set shellslash
        endif

    endfunction

else

    function s:SetPwsh(...) abort

        if !executable('pwsh')
            echomsg "setpwsh plugin: pwsh is not available in the system"
            return
        endif

        set shell=pwsh
        let &shellcmdflag='-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File '
            \   . s:script_dir . 'vim_pwsh_linux_proxy.ps1'
        set shellquote=
        set shellxquote=(
        set shellredir=>%s
        set shellpipe=>%s

    endfunction

endif

if g:setpwsh_enabled
    if has('win32')
        let cmdline = "SetPwsh"
        if g:setpwsh_shell ==? "powershell"
            let cmdline .= " Desktop"
        endif
        if !g:setpwsh_netrw_viewer
            let cmdline .= " NoViewer"
        endif
        if g:setpwsh_ftp_from_wsl
            let cmdline .= " FtpFromWsl"
        endif
        if g:setpwsh_ssh_from_wsl
            let cmdline .= " SshFromWsl"
        endif
        execute cmdline
    else
        call s:SetPwsh()
    endif
endif

let &cpo = s:save_cpo
unlet s:save_cpo
