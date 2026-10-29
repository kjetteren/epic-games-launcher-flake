# Updates package.nix to Epic's current .deb build. Run from the flake root:
#
#   nix run .#update
#
# Leaves package.nix untouched and exits non-zero if the .deb's dependencies or
# file layout changed: that kind of change still builds fine but breaks the
# launcher at runtime, so it needs a look by hand.

latest_url=${EGL_DEB_URL:-https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher-x86_64.deb}
file=package.nix

if [[ ! -f $file ]]; then
  echo "error: run this from the flake's root (no $file here)" >&2
  exit 1
fi

for key in version url hash; do
  if [[ $(grep -cE "^ *$key = \"[^\"]+\";$" "$file") != 1 ]]; then
    echo "error: expected exactly one $key line in $file" >&2
    exit 1
  fi
done

current_version=$(sed -nE 's/^ *version = "([^"]+)";$/\1/p' "$file")
current_url=$(sed -nE 's/^ *url = "([^"]+)";$/\1/p' "$file")
current_hash=$(sed -nE 's/^ *hash = "([^"]+)";$/\1/p' "$file")

# Epic's download link always serves the newest build by redirecting to that
# build's own URL. package.nix pins the build's URL instead of the link, so it
# doesn't break as soon as Epic releases something newer.
url=$(curl -fsS --retry 3 -o /dev/null -w '%{redirect_url}' "$latest_url")
# Drop the query string (?launcherfilename=...), a download name hint, and
# the redirect's extra encoding of the build's + (%252B -> %2B)
url=${url%%\?*}
url=${url//%25/%}

# The URL goes into package.nix as is, so allow only characters that are safe
# there and in the sed replacement below
url_pattern='^https://[A-Za-z0-9._~%/:+-]+$'

if [[ ! $url =~ $url_pattern ]]; then
  echo "error: expected $latest_url to redirect to a plain https URL, got '$url'" >&2
  exit 1
fi

json=$(nix store prefetch-file --json "$url")
hash=$(jq -r .hash <<<"$json")
deb=$(jq -r .storePath <<<"$json")
version=$(dpkg-deb -f "$deb" Version)
# Nix store names can't contain Debian's epoch colon or pre-release tilde.
# Epic's build suffix (0.95.2+gfa9ad49) goes too, since the URL already has it.
version=${version#*:}
version=${version%%+*}
version=${version//\~/-}

if [[ $url == "$current_url" && $hash == "$current_hash" ]]; then
  echo "Already up to date: $current_version"
  exit 0
fi

# The .deb's Depends line, which package.nix provides for. A new entry needs a
# matching nixpkgs package in package.nix before this check is updated.
expected_depends="libayatana-appindicator3-1 libgtk-3-0 libwebkit2gtk-4.1-0"
depends=$(dpkg-deb -f "$deb" Depends |
  tr ',' '\n' |
  sed -E 's/\(.*\)//; s/^ +//; s/ +$//; /^$/d' |
  sort -u |
  tr '\n' ' ')
depends=${depends% }

if [[ $depends != "$expected_depends" ]]; then
  echo "error: the .deb's dependencies changed" >&2
  echo "  expected: $expected_depends" >&2
  echo "  now:      $depends" >&2
  exit 1
fi

# Paths package.nix relies on
contents=$(dpkg-deb -c "$deb" | awk '{ print $6 }' | sed 's|^\./||')

for path in \
  usr/bin/EpicGamesLauncher \
  usr/lib/epic-games-launcher/libEOSSDK-Linux-Shipping.so \
  usr/share/applications/epic-games-launcher.desktop; do
  if ! grep -qxF "$path" <<<"$contents"; then
    echo "error: the .deb no longer contains $path" >&2
    exit 1
  fi
done

sed -i -E "s|^( *version = \")[^\"]+(\";)$|\1${version}\2|" "$file"
sed -i -E "s|^( *url = \")[^\"]+(\";)$|\1${url}\2|" "$file"
sed -i -E "s|^( *hash = \")[^\"]+(\";)$|\1${hash}\2|" "$file"

echo "Updated: $current_version -> $version"
