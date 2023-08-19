# nunvm - Nushell Node Version Manager
# Implementing nvm in nushell
#
# To use, source this file in your config.nu file
# For using with non-nushell shells, create a separate 
# script file which invokes it with nu
#
# Copyright 2023 Yakiyo. All rights reserved. MIT license.

use std log

# nunvm version
const nunvm_version = "0.1.0" 

# Nodejs dist url
const node_dist = "https://nodejs.org/dist"

# Nodejs version manager in nushell
#
# https://github.com/Yakiyo/nunvm
def nunvm [
  --version(-v) # Display current nunvm version
] {
  if $version {
    print $"v($nunvm_version)"
    return
  }
  help nunvm
}

# Install a version of nodejs
def "nunvm install" [
  version?: string # The version to install
  --lts # Install lts version
  --latest # Install latest version
] {
  # resolve version
  mut v = ""
  if $version == null and $lts == false and $latest == true {
    $v = (_nunvm_get_latest)
    log info $"Resolving version latest to (ansi blue)($v)(ansi reset)"
  } else if $version == null and $lts == true and $latest == false {
    $v = (_nunvm_get_lts)
    log info $"Resolving version lts to (ansi blue)($v)(ansi reset)"
  } else if $version != null and $lts == false and $latest == false {
    if not (_nunvm_is_valid_version $version) {
      _nunvm_throw $"($version) is not a valid string"
    }
    $v = (_nunvm_prepend_version $"($version)")
  } else if ([$env.PWD ".nvmrc"] | path join | path exists) {
    $v = (_nunvm_read_rc)
    log info $"Using version (ansi blue)($v)(ansi reset) from .nvmrc"
  } else {
    _nunvm_throw "Only one of `version`, `--lts` and `--latest` must be used at a time"
  }

  let version = $v
  let url = _nunvm_make_url $version
  let archive_path = (_nunvm_home | path join $"(_nunvm_file_name $version)")
  let version_path = (_nunvm_installations | path join $version)
  if ($version_path | path exists) {
    _nunvm_throw $"Nodejs version ($version) already exists. Consider uninstalling it before installing it again"
  }
  log info $"Downloading archive from ($url)"
  log info $"Saving file to ($archive_path)"
  http get -r $url | save -r -f -p $archive_path

  log info "Extracting file from archive"
  _nunvm_unarchive $archive_path (_nunvm_installations | path join $version)

  log info "Removing archive file"
  try { 
    rm -f $archive_path
  } catch { 
    log error "Unable to delete archive file due to unexpected reasons. Please do it manually"
  }
  print $"Successfully installed nodejs (ansi blue)($version)(ansi reset)"
}

# Uninstall a nodejs version
def "nunvm uninstall" [version: string] {
  if not (_nunvm_is_valid_version $version) {
    _nunvm_throw $"($version) is not a valid version string"
  }
  let version = (_nunvm_prepend_version $version)
  let p = (_nunvm_installations | path join $version)
  if not ($p | path exists) {
    _nunvm_throw $"($version) is not installed. Cannot uninstall it"
  }
  try { rm -rf $p } catch { _nunvm_throw "Unable to remove installated version" }
  print "Succesfully removed installation"
}

# View version of currently active nodejs
def "nunvm current" [] {
  if (which "node" | is-empty) {
    print "No version of nodejs currently active"
  } else {
    node -v
  }
}
# View all installed versions of nodejs
def "nunvm ls" [] {
  let installations = _nunvm_installations
  if not ($installations | path exists) {
    print "No version of nodejs installed"
    return
  }
  ls -s $installations | select name | each { |it| $it.name }
}

# View all available versions of nodejs
def "nunvm ls-remote" [] {
  http get 'https://nodejs.org/dist/index.json' | reverse | each { |it| _nunvm_fmt_version $it }
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
def _nunvm_throw [error: string] {
  error make --unspanned { msg: $"(ansi red_bold)($error)(ansi reset)" }
}

# read `.nvmrc` from current dir
def _nunvm_read_rc [] {
  let v = ([$env.PWD ".nvmrc"] | path join | open | str trim)
  if not (_nunvm_is_valid_version $v) {
    _nunvm_throw $".nvmrc contains ($v), which is not a valid version string"
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