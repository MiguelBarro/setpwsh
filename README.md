# setpwsh

A Vim plugin to improve powershell integration.

## Motivation

Using powershell as windows ['shell'](https://vimhelp.org/options.txt.html#%27shell%27) with the defaults settings (see [dos-pwsh](https://vimhelp.org/os_dos.txt.html#dos-pwsh)) is a poor experience:

+ Commands perfectly valid in terminal cannot be used due to the [defective way windows CRT parses command lines](https://devblogs.microsoft.com/oldnewthing/20100917-00/?p=12833).
  Powershell binary uses also this CRT parsing strategy. For example from cmd:
  ```pws
      > pwsh -C Get-Item "C:\Program Files"
  ```
  **pwsh.exe** will receive as arguments (according with CRT rules):
  ```pwsh
      Arg 0 is <Get-Item>
      Arg 1 is <C:\Program Files>
  ```
  and fails due to the lack of quotation marks.
  This issue does not plague pwsh for linux or mac.

+ Powershell heavily relies on pipelines to join different cmdlets. It will be very convenient to profit from vim's integrated filtering capabilities to feed those pipelines.

This plugin rigs the ['shell'](https://vimhelp.org/options.txt.html#%27shell%27), ['shellcmdflag'](https://vimhelp.org/options.txt.html#%27shellcmdflag%27) and other related options to
workaround the above issues.

## Installation

An obvious precondition is having powershell core installed. Though, on windows it will work with the builtin powershell desktop if core is not available or the user enforces it (see [Usage](#usage)).

In order to install powershell core (pwsh) I advise:
• Windows. Use `winget`:
```cmd
    > winget install Microsoft.Powershell
```
• Ubuntu. Use `snap`:
```bash
    $ sudo apt install snapd
    $ sudo snap install powershell --classic
```
• MacOs. Use `brew`:
```bash
    $ brew install powershell/tap/powershell-lts
```

This plugin can be installed using any popular plugin manager (vim-plug, Vundle, etc...) but vim plugin integration is
extremely easy in later releases ([version8.0](https://vimhelp.org/version8.txt.html#version8.0) introduced package support):

+ A [vimball] is distributed by [www.vim.org](www.vim.org). Installation is as easy as sourcing the vimball file:
  ```vim
    :source setpwsh.vba
  ```
  so is uninstall:
  ```vim
    :RmVimball setpwsh.vba
  ```

+ The github repo can be cloned direcly into the `$VIMRUNTIME/pack` directory as explained in [matchit-install](https://vimhelp.org/usr_05.txt.html#matchit-install). Though using this approach many useless files in this repo will be installed too.

+ Use [getscript](https://vimhelp.org/pi_getscript.txt.html#getscript) plugin to automatically download an update it. Update the local
  `$VIMRUNTIME/GetLatest/GetLatestVimScripts.dat` adding a line associated with this plugin.

Once installed the [:SetPwsh](#usage) command must be used to modify the ['shell'](https://vimhelp.org/options.txt.html#%27shell%27) options. The most common place to do it is the [.vimrc](https://vimhelp.org/starting.txt.html#vimrc) file. Add the following lines:
```vim
    packadd setpwsh
    SetPwsh
```

If you use a plugin manager like Vim-Plug you can install and load SetPwsh like this in you `vimrc` file:
```vim
call plug#begin()
    Plug 'MiguelBarro/setpwsh', { 'rtp': 'start/setpwsh'   }
call plug#end()

" --- Pwsh options
" Enable SetPwsh plugin
let g:setpwsh_enabled = 1

" SetPwsh netrw viewer feature: 1 To Enable or 0 Disable
let g:setpwsh_netrw_viewer = 0
```

## Usage

There is only a single command:
```vim
    :SetPwsh [Desktop | FtpFromWsl | SshFromWsl]
```
This command will modify ['shell'](https://vimhelp.org/options.txt.html#%27shell%27) and related options to use the
powershell. It admits the following argument flags that are only meaningful in windows:

+ Desktop     Use powershell desktop instead of powershell core.
+ FtpFromWsl  Sets up netrw global options to rig wsl ftp.
+ SshFromWsl  Sets up netrw global options to rig wsl ssh & scp.

### Bang commands

Once ['shell'](https://vimhelp.org/options.txt.html#%27shell%27) and related options are modified by the `:SetPwsh`
command, the [:!cmd](https://vimhelp.org/various.txt.html#%3A%21cmd) will respond to powershell as on a terminal. For example:
```vim
    :!Get-Item "C:\Program Files"
```
will work properly.

Is possible to read powershell pipeline output into the current buffer using [:read!](https://vimhelp.org/insert.txt.html#%3Aread%21). For example:
```vim
    :read !1..5 | \% { [char]($_+96) }
```
will fill the current buffer with:
```vim
 1  a
 2  b
 3  c
 4  d
 5  e
```

we can use a [filter](https://vimhelp.org/change.txt.html#filter) command to modify the buffer. The plugin allows creating powershell filters where the buffer input is translated into a powershell pipeline input. The `$_` automatic variable will match each input line. For example in the above buffer doing:
```vim
    :1,5!"-->$_<--"
```
will turn the buffer into:
```vim
 1  -->a<--
 2  -->b<--
 3  -->c<--
 2  -->d<--
 5  -->e<--
```

if we do not want to filter the buffer but running a powershell pipeline with
it as input we can use [:write_c](https://vimhelp.org/editing.txt.html#%3Awrite_c). For example:
```vim
    :1,5w !"-->$_<--"
```
will execute the same commands without modifying the buffer.

The same applies to the [system()](https://vimhelp.org/builtin.txt.html#system%28%29) function. For example:
```vim
    :echo system('1..5 | % { [char]($_+96) }')
```
will show:
```vim
 a
 b
 c
 d
 e
```

For a more detailed and comprehensive usage explanation refer to the actual [plugin docs](https://github.com/MiguelBarro/setpwsh/releases/download/1.0/setpwsh.html).
