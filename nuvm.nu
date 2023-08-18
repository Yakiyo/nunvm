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

def "nuvm install" [] {
  print "TODO!"
}

def "nuvm current" [] {
  if (which "node" | is-empty) {
    print "No version of nodejs currently active"
  } else {
    node -v
  }
}