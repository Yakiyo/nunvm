# nunvm

Nunvm is a rewrite of [nvm](https://github.com/nvm-sh/nvm) in [nushell](https://nushell.sh). Unlike nvm, nunvm is cross-platform, meaning it can run on windows too.

## Installation
Installation is easy. Just copy the [nunvm.nu](./nunvm.nu) file and save it in a directory/folder which is added to your system `PATH`.

On unix systems (linux/mac), you should name the file as `nunvm` (without the extension) and then it can be invoked from the terminal
```sh
$ nunvm --version
```

On windows, create a `nunvm.bat` file, with the following content, and add that directory to `PATH`
```bat
nu nunvm.nu
```
Be sure to use the specific path of nunvm.nu file if it does not exist within the same directory as the bat file.

### Post-installation
For using the version of Node installaed by nunvm, you need to see the nunvm current directory to your system path. The path can be viewed by running the following command
```sh
$ nunvm path
```
If you're using bash/zsh, add the following line to your `.bashrc`/`.zshrc` file:
```
$ export PATH="$(nunvm path)":$PATH
```
For powershell, the following can be added to `profile.ps1`
```powershell
$Dir = nunvm path
$User = [System.EnvironmentVariableTarget]::User
$Path = [System.Environment]::GetEnvironmentVariable('Path', $User)
if (!(";${Path};".ToLower() -like "*;${Dir};*".ToLower())) {
  [System.Environment]::SetEnvironmentVariable('Path', "${Path};${InstallDir}", $User)
  $Env:Path += ";${Dir}"
}
```

## Features

- Cross platform, unlike nvm which only works for unix like systems
- Is decently fast
- Some actions are customizable
- Supports reading from `.nvmrc` file in current directory, similar to nvm
- All subcommands of nvm like install, uninstall, alias, unalias, list, list-remote are supported
- nunvm symlinks directories for setting active node versions whereas nvm uses shiming

### Cons
- nunvm requires some tools be preinstalled. This may be solved in the future when [nupm](https://github.com/nushell/nupm) becomes stable and it is easier to install third-party modules/scripts that can be used instead of system apps. The required necessities are as follows
    - on unix system, it requires the `ln` tool for creating/removing symlinks and requires `tar` for extracting archives
    - on windows, powershell is required for extracting from archives and the `mklink` tool for creating symlinks
- On windows, the `use` subcommand of nunvm requires elevated privileges, because the `use` command deletes the previous symlink, if any, and that requires elevated privileges. So when using `nunvm use`, users might need to run the terminal with admin privileges. This issue has been found for windows for now, unsure about linux/mac
- nunvm is still not thoroughly tested so bugs may prevail

## Usage
Using nunvm is similar to nvm. 

For installing a version of node, do
```sh
$ nunvm install v18.2.1 # install specific version

$ nunvm install --latest # latest version

$ nunvm install --lts # lts version

$ nunv install # install specified version in `./.nvmrc`
```

For uninstall, do
```sh
$ nunvm uninstall v18.1.0
```

Aliasing and unaliasing can be done with `nunvm alias` & `nunvm unalias`.

Use `nunvm ls` for listing locally installed version and `nunvm ls-remote` for listing all available node versions.

Run `nunvm use <VERSION>` to set a node version to active. This requires the steps mentioned in [post-installation](#post-installation). If version is unspecified, then it tries to use version from `./.nvmrc`. `VERSION` must be a locally installed one.

For queries or issues, feel free to open an [new issue](https://github.com/Yakiyo/nunvm/issues).

## NOTE
This project was made as a fun project in my free time, and while it works fine as intended, it is not an industry standard tool and no guarantes can be made about it. Using a more trusted tool like [nvm](https://github.com/nvm-sh/nvm) or [nvm-windows](https://github.com/coreybutler/nvm-windows) for production grade apps should be prefered.

## Author

**nunvm** © [Yakiyo](https://github.com/Yakiyo). Authored and maintained by Yakiyo.

Released under [MIT](https://opensource.org/licenses/MIT) License

If you like this project, consider leaving a star ⭐ and sharing it with your friends and colleagues.