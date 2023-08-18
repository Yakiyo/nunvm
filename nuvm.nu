#!/usr/bin/env nu

const nuvm_version = "0.1.0" # nuvm version

module _utils {
  # get platform
  export def get_os [] {
    $nu.os-info | get name
  }

  # get architecture
  export def get_arch [] {
    $nu.os-info | get arch
  }
}

use _utils

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
def "nuvm install" [] {
  print "TODO!"
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