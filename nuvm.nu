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
  version: string
  --nuvm-dir?: string
] {
  let version = _prepend_version $version
  let url = _make_url $version
  log info $"Downloading archive from ($url)..."
  http get -r $url | save -r -f -p node.zip 
}

# View version of currently active nodejs
def "nuvm current" [] {
  if (which "node" | is-empty) {
    print "No version of nodejs currently active"
  } else {
    node -v
  }
}

# View all available versions of nodejs
def "nuvm ls-remote" [] {
  http get 'https://nodejs.org/dist/index.json' | reverse | each { |it| $it.version }
}


# get platform
def _get_os [] {
  $nu.os-info | get name | str downcase
}

# get architecture
def _get_arch [] {
  let host_arch: string = ($env.NUVM_ARCH? | default ($nu.os-info | get arch | str downcase))
  #FIXME: this is wanky, need to check i*86, not i86
  match $host_arch {
    "x86_64" | "amd64" => "x64",
    "i86" => "x86",
    _ => $host_arch,
  }
}

# appropiate file name for each platform
def _file_name [version: string] {
  mut fname = ""
  if (_get_os | str contains "windows") {
    $fname = $"node-($version | str downcase)-win-(_get_arch).zip"
  } else {
    $fname = $"node-($version | str downcase)-(_get_os)-(_get_arch).tar.gz"
  }
  echo $fname
}

# form url to download from
def _make_url [version: string] {
  $"($node_dist)/($version)/(_file_name $version)"
}

# throw an error
def _throw [error: string] {
  error make --unspanned { msg: $"(ansi red_bold)($error)(ansi reset)" }
}

# lowercase version and if does not start with `v`, add it
def _prepend_version [version: string] {
  let version = ($version | str downcase)
  if not ($version | str starts-with "v") {
    $"v($version)"
  } else {
    $version
  }
}

def _nuvm_home [] {
  $env.NUVM_DIR? | default ($nu.home-path | path join ".nuvm")
}

def _nuvm_installations [] {
  _nuvm_home | path join "installations"
}

def _nuvm_current [] {
  $env.NUVM_CURRENT
}