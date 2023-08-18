#!/usr/bin/env nu

use std log

# nuvm version
const nuvm_version = "0.1.0" 

const node_dist = "https://nodejs.org/dist"

# Entry point
def nuvm [
  --version(-v) # Display current nuvm version
] {
  if $version {
    print $nuvm_version
    return
  }
  help nuvm
}

# Install a version of nodejs
def "nuvm install" [
  version?: string # The version to install
  --lts # Install lts version
  --latest # Install latest version
] {
  mut v = ""
  if $version == null and $lts == false and $latest == true {
    $v = (_nuvm_get_latest)
    log info $"Resolving version latest to (ansi blue)($v)(ansi reset)"
  } else if $version == null and $lts == true and $latest == false {
    $v = (_nuvm_get_lts)
    log info $"Resolving version lts to (ansi blue)($v)(ansi reset)"
  } else if $version != null and $lts == false and $latest == false {
    if not (_nuvm_is_valid_version $version) {
      _nuvm_throw $"($version) is not a valid string"
    }
    $v = (_nuvm_prepend_version $"($version)")
  } else {
    _nuvm_throw "Only one of `version`, `--lts` and `--latest` must be used at a time"
  }
  let version = $v
  let url = _nuvm_make_url $version
  let archive_path = (_nuvm_home | path join $"(_nuvm_file_name $version)")
  let version_path = (_nuvm_installations | path join $version)
  if ($version_path | path exists) {
    _nuvm_throw $"Nodejs version ($version) already exists. Consider uninstalling it before installing it again"
  }
  log info $"Downloading archive from ($url)"
  log info $"Saving file to ($archive_path)"
  http get -r $url | save -r -f -p $archive_path

  log info "Extracting file from archive"
  _nuvm_unarchive $archive_path (_nuvm_installations | path join $version)

  log info "Removing archive file"
  try { 
    rm -f $archive_path
  } catch { 
    log error "Unable to delete archive file due to unexpected reasons. Please do it manually"
  }
  print $"Successfully installed nodejs (ansi blue)($version)(ansi reset)"
}

# View version of currently active nodejs
def "nuvm current" [] {
  if (which "node" | is-empty) {
    print "No version of nodejs currently active"
  } else {
    node -v
  }
}
# View all installed versions of nodejs
def "nuvm ls" [] {
  let installations = _nuvm_installations
  if not ($installations | path exists) {
    print "No version of nodejs installed"
    return
  }
  ls -s $installations | select name | each { |it| $it.name }
}

# View all available versions of nodejs
def "nuvm ls-remote" [] {
  http get 'https://nodejs.org/dist/index.json' | reverse | each { |it| _nuvm_fmt_version $it }
}

# format a version string
def _nuvm_fmt_version [it] {
  mut s: string = $it.version
  if $it.lts != false {
    $s = $"($s) \(($it.lts)\)"
  }
  $s
}

# get platform
def _nuvm_get_os [] {
  $nu.os-info | get name | str downcase
}

# get architecture
def _nuvm_get_arch [] {
  let host_arch: string = ($env.NUVM_ARCH? | default ($nu.os-info | get arch | str downcase))
  #FIXME: this is wanky, need to check i*86, not i86
  match $host_arch {
    "x86_64" | "amd64" => "x64",
    "i86" => "x86",
    _ => $host_arch,
  }
}

# appropiate file name for each platform
def _nuvm_file_name [version: string] {
  mut fname = ""
  if (_get_os | str contains "windows") {
    $fname = $"node-($version | str downcase)-win-(_get_arch).zip"
  } else {
    $fname = $"node-($version | str downcase)-(_get_os)-(_get_arch).tar.gz"
  }
  echo $fname
}

# form url to download from
def _nuvm_make_url [version: string] {
  $"($node_dist)/($version)/(_file_name $version)"
}

# throw an error
def _nuvm_throw [error: string] {
  error make --unspanned { msg: $"(ansi red_bold)($error)(ansi reset)" }
}

# lowercase version and if does not start with `v`, add it
def _nuvm_prepend_version [version: string] {
  let version = ($version | str downcase)
  if not ($version | str starts-with "v") {
    $"v($version)"
  } else {
    $version
  }
}

# Path to nuvm home. Use `NUVM_DIR` env or default to `~/.nuvm`
def _nuvm_home [] {
  $env.NUVM_DIR? | default ($nu.home-path | path join ".nuvm")
}

# $nuvm_home/installations
def _nuvm_installations [] {
  _nuvm_home | path join "installations"
}

# Where to store the current version. Use `NUVM_CURRENT` or default to `$nuvm_home/current`
def _nuvm_current [] {
  $env.NUVM_CURRENT? | default (_nuvm_home | path join "current")
}

# unarchive zip files using platform specific tools
# for windows use powershell's Expand-Archive func, for others
# use tar
def _nuvm_unarchive [
  archive_path: string
  dest_path: string
] {
  match $"(_get_os)" {
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
def _nuvm_is_valid_version [version: string] {
  # the regex isnt exactly completely correct but it gets the job done
  ($version | parse -r "^v?([0-9]+).([0-9]+).([0-9]+)$" | is-empty) == false 
}

# Get lts version
def _nuvm_get_lts [] {
  http get 'https://nodejs.org/dist/index.json' | where { |x| $x.lts != false } | get 0.version
}

# Get latest version
def _nuvm_get_latest [] {
  http get 'https://nodejs.org/dist/index.json' | get 0.version 
}