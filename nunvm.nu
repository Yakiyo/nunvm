# nunvm - Nushell Node Version Manager
# Implementing nvm in nushell
#
# To use, source this file in your config.nu file
# For using with non-nushell shells, create a separate 
# script file which invokes it with nu
#
# Copyright 2023 Yakiyo. All rights reserved. MIT license.

use std log

(_nunvm_set_log_level)
# nunvm version
const nunvm_version = "0.1.0" 

# Nodejs dist url
const node_dist = "https://nodejs.org/dist"

# Nodejs version manager in nushell
#
# https://github.com/Yakiyo/nunvm
def main [
  --version(-v) # Display current nunvm version
] {
  if $version {
    print $"v($nunvm_version)"
    return
  }
  help main
}

# Install a version of nodejs
def "main install" [
  version?: string # The version to install
  --lts            # Install lts version
  --latest         # Install latest version
] {
  # resolve version
  let version: string = if $version == null and $lts == false and $latest == true {
    let v = (_nunvm_get_latest)
    log info $"Resolving version latest to (ansi blue)($v)(ansi reset)"
    $v
  } else if $version == null and $lts == true and $latest == false {
    let v = (_nunvm_get_lts)
    log info $"Resolving version lts to (ansi blue)($v)(ansi reset)"
    $v
  } else if $version != null and $lts == false and $latest == false {
    if not (_nunvm_is_valid_version $version) {
      _nunvm_throw "E_INVALID_VERSION" $"($version) is not a valid string"
    }
    let v = (_nunvm_prepend_version $"($version)")
    $v
  } else if ([$env.PWD ".nvmrc"] | path join | path exists) {
    let v = (_nunvm_read_rc)
    log info $"Using version (ansi blue)($v)(ansi reset) from .nvmrc"
    $v
  } else {
    _nunvm_throw "E_TOO_MANY_ARGS" "Only one of `version`, `--lts` and `--latest` must be used at a time"
  }

  let version_path = (_nunvm_installations | path join $version)
  if ($version_path | path exists) {
    _nunvm_throw "E_EXISTING_VERSION" $"Nodejs version ($version) already exists. Consider uninstalling it before installing it again"
  }
  let url = _nunvm_make_url $version
  let archive_path = ($nu.temp-path | path join (_nunvm_file_name $version))
  log debug $archive_path

  log info $"Downloading archive from ($url)"
  log info $"Saving file to ($archive_path)"
  http get -r $url | save -r -f -p $archive_path
  log info "Extracting file from archive"
  _nunvm_unarchive $archive_path (_nunvm_installations)
  let ext_less_file_name = ((_nunvm_file_name $version) | str replace -r '.zip|.tar|.gz' '')
  let archived_dir = (_nunvm_installations | path join $ext_less_file_name)
  log debug $"Unarchived directory in ($archived_dir)"
  mv $archived_dir (_nunvm_installations | path join $version)

  log info "Removing archive file"
  try { 
    rm -f $archive_path
  } catch { 
    log error "Unable to delete archive file due to unexpected reasons. Please do it manually"
  }
  print $"Successfully installed nodejs (ansi blue)($version)(ansi reset)"
}

# Uninstall a nodejs version
def "main uninstall" [
  version: string # Version to uninstall
  ] {
  if not (_nunvm_is_valid_version $version) {
    _nunvm_throw "E_INVALID_VERSION" $"($version) is not a valid version string"
  }
  let version = (_nunvm_prepend_version $version)
  let p = (_nunvm_installations | path join $version)
  if not ($p | path exists) {
    _nunvm_throw "E_VERSION_NOT_INSTALLED" $"($version) is not installed. Cannot uninstall it"
  }
  try { rm -rf $p } catch { _nunvm_throw "E_EXT_ERROR" "Unable to remove installated version" }
  print "Succesfully removed installation"
}

# View version of currently active nodejs
def "main current" [] {
  if (which "node" | is-empty) {
    print "No version of nodejs currently active"
  } else {
    node -v
  }
}

# Use an installed version
def "main use" [
  version: string # the version to use (alias not supported yet)
] {
  if not (_nunvm_is_valid_version $version) {
    _nunvm_throw "E_INVALID_VERSION" $"($version) is not a valid version string"
  }
  let version = (_nunvm_prepend_version $version)
  let src = (_nunvm_installations | path join $version)
  if not ($src | path exists) {
    _nunvm_throw "E_VERSION_NOT_INSTALLED" $"($version) is not installed. Cannot uninstall it"
  }
  let dest = (_nunvm_current)
  log info $"Symlinking ($src) to ($dest)"
  _nunvm_symln $src $dest
  print $"Successfully set ($version) as current"
}

# Show the currently used path value
def "main path" [] {
  _nunvm_current
}

# View all installed versions of nodejs
def "main ls" [] {
  let installations = _nunvm_installations
  if not ($installations | path exists) {
    print "No version of nodejs installed"
    return
  }
  ls -s $installations | select name | each { |it| $it.name }
}

# View all available versions of nodejs
def "main ls-remote" [] {
  http get 'https://nodejs.org/dist/index.json' | reverse | each { |it| _nunvm_fmt_version $it }
}

# Create an alias 
def "main alias" [
  version: string # The version to alias
  alias: string   # Alias name
] {
  if not (_nunvm_is_valid_version $version) {
    _nunvm_throw "E_INVALID_VERSION" $"($version) is not a valid version string"
  }
  let version = _nunvm_prepend_version $version
  if not (_nunvm_installations | path join $version | path exists) {
    _nunvm_throw "E_VERSION_NOT_INSTALLED" $"($version) is not installed. Cannot alias to it"
  }
  # this is a map of version as value and alias as it's key
  let aliases = _nunvm_alias
  let aliases = ($aliases | upsert $alias $version)
  $aliases | to json -i 4 | save -f (_nunvm_alias_file)
  print "Created new alias"
}

# Remove an alias
def "main unalias" [
  alias: string # the alias to remove
] {
  _nunvm_alias | upsert $alias null | to json -i 4 | save -f (_nunvm_alias_file)
}

# format a version string
def _nunvm_fmt_version [it] {
  mut s: string = $it.version
  if $it.lts != false {
    $s = $"($s) \(($it.lts)\)"
  }
  $s
}

# get platform
def _nunvm_get_os [] {
  $nu.os-info | get name | str downcase
}

# get architecture
def _nunvm_get_arch [] {
  let host_arch: string = ($env.NUNVM_ARCH? | default ($nu.os-info | get arch | str downcase))
  #FIXME: this is wanky, need to check i*86, not i86
  match $host_arch {
    "x86_64" | "amd64" => "x64",
    "i86" => "x86",
    _ => $host_arch,
  }
}

# appropiate file name for each platform
def _nunvm_file_name [version: string] {
  mut fname = ""
  if (_nunvm_get_os | str contains "windows") {
    $fname = $"node-($version | str downcase)-win-(_nunvm_get_arch).zip"
  } else {
    $fname = $"node-($version | str downcase)-(_nunvm_get_os)-(_nunvm_get_arch).tar.gz"
  }
  echo $fname
}

# form url to download from
def _nunvm_make_url [version: string] {
  $"($node_dist)/($version)/(_nunvm_file_name $version)"
}

# throw an error
def _nunvm_throw [tag: string, error: string] {
  error make --unspanned { 
    msg: $"(ansi red_bold)($tag)(ansi reset)\n($error)"
  }
}

# read `.nvmrc` from current dir
def _nunvm_read_rc [] {
  let v = ([$env.PWD ".nvmrc"] | path join | open | str trim)
  if not (_nunvm_is_valid_version $v) {
    _nunvm_throw "E_INVALID_VERSION" $".nvmrc contains ($v), which is not a valid version string"
  }
  $v
}

# lowercase version and if does not start with `v`, add it
def _nunvm_prepend_version [version: string] {
  let version = ($version | str downcase)
  if not ($version | str starts-with "v") {
    $"v($version)"
  } else {
    $version
  }
}

# Path to nunvm home. Use `NUNVM_DIR` env or default to `~/.nunvm`
def _nunvm_home [] {
  $env.NUNVM_DIR? | default ($nu.home-path | path join ".nunvm")
}

# $nunvm_home/installations
def _nunvm_installations [] {
  _nunvm_home | path join "installations"
}

# Where to store the current version. Use `NUNVM_CURRENT` or default to `$nunvm_home/current`
def _nunvm_current [] {
  $env.NUNVM_CURRENT? | default (_nunvm_home | path join "current")
}

def _nunvm_alias_file [] {
  [(_nunvm_home) "alias.json"] | path join
}

# json file containing info about aliases
def _nunvm_alias [] {
  let p = (_nunvm_alias_file)
  # Create parent dir first
  let dir = ($p | path dirname)
  mkdir $dir
  if not ($p | path exists) {
    log info "Missing alias file. Creating it"
    "{}" | save -f $p
  }
  # handle case when file exists, but is empty
  open $p | default {}
}

# unarchive zip files using platform specific tools
# for windows use powershell's Expand-Archive func, for others
# use tar
def _nunvm_unarchive [
  archive_path: string
  dest_path: string
] {
  match $"(_nunvm_get_os)" {
    "windows" => {
      powershell -Command $"\"Expand-Archive '($archive_path)' -DestinationPath ($dest_path) -Force\""
    }
    _ => {
      tar xf $archive_path --directory=($dest_path)
    }
  }
}

# Check if a string is a valid version
# String must start with a `v`
def _nunvm_is_valid_version [version: string] {
  # the regex isnt exactly completely correct but it gets the job done
  ($version | parse -r "^v?([0-9]+).([0-9]+).([0-9]+)$" | is-empty) == false 
}

# Get lts version
def _nunvm_get_lts [] {
  http get 'https://nodejs.org/dist/index.json' | where { |x| $x.lts != false } | get 0.version
}

# Get latest version
def _nunvm_get_latest [] {
  http get 'https://nodejs.org/dist/index.json' | get 0.version 
}

# create symlinks. Use `mklink` on windows, otherwise use `ln`
# mklink: https://learn.microsoft.com/windows-server/administration/windows-commands/mklink
# ln: https://www.gnu.org/software/coreutils/ln
def _nunvm_symln [
  src: string # the original directory
  dest: string # the path to create symlink at
] {
  match $"(_nunvm_get_os)" {
    "windows" => {
      if ($dest | path exists) {
        rm $dest
      }
      mklink /d $dest $src
    }
    _ => {
      ln -sf $src $dest
    }
  }
}

# Read `$env.NUNVM_LOG` and set it to `$env.NU_LOG_LEVEL`
def-env _nunvm_set_log_level [] {
  let nunvm_log = $env.NUNVM_LOG?
  if $nunvm_log != null {
    $env.NU_LOG_LEVEL = $nunvm_log
  }
}