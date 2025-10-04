# syntax=docker/dockerfile:1-labs
FROM ubuntu:noble AS builder-base
RUN groupadd -g 1234 builder && \
    useradd -m -s /bin/bash -u 1234 -g 1234 builder
ARG APT_PROXY
COPY <<EOF /etc/apt/apt.conf.d/02proxy
$APT_PROXY
EOF
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
        arch-test \
        distro-info-data \
        iproute2 \
        mmdebstrap \
        sbuild/noble-backports \
        uidmap \
        zstd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER builder
RUN mkdir -p /home/builder/.cache/sbuild /home/builder/.config/sbuild /home/builder/build
WORKDIR /home/builder/src/

FROM builder-base AS builder
ARG DIST=noble
ARG ARCH=amd64
RUN --security=insecure --mount=type=tmpfs,target=/tmp --mount=type=tmpfs,target=/var/cache/apt/archives <<EOF
#!/bin/bash
ARGS=(
    '--verbose'
    '--skip=output/dev'
    '--variant=buildd'
    '--include=ca-certificates'
    '--aptopt=/etc/apt/apt.conf.d/02proxy'
    '--components=main,universe'
)
case "${DIST}" in
trusty)
    ARGS+=(
        '--setup-hook=mkdir -p $1/etc $1/var/lib/dpkg'
        '--setup-hook=touch $1/var/lib/dpkg/available'
        '--setup-hook=printf "root:x:0:0:root:/root:/bin/bash\n" > $1/etc/passwd'
        '--setup-hook=printf "root:x:0:\nmail:x:8:\nutmp:x:43:\n" > $1/etc/group'
    )
    sed -i 's/--build=source/-S/g' /usr/share/perl5/Sbuild/Build.pm
    ;;
xenial)
    ARGS+=(
        '--extract-hook=chroot $1 pam-auth-update --package --force'
    )
    sed -i 's/--build=source/-S/g' /usr/share/perl5/Sbuild/Build.pm
    ;;
esac
ARGS+=(
    "--arch=${ARCH}"
    "${DIST}"
    "/home/builder/.cache/sbuild/${DIST}-${ARCH}.tar.zst"
)
mmdebstrap "${ARGS[@]}"
EOF
COPY <<'EOF' /home/builder/.config/sbuild/config.pl
# Set the chroot mode to be unshare.
$chroot_mode = 'unshare';

$external_commands = { "build-failed-commands" => [ [ '%SBUILD_SHELL' ] ] };

# Uncomment below to specify the distribution; this is the same as passing `-d unstable` to sbuild.
# Specifying the distribution is currently required for piuparts when the changelog targets UNRELEASED.  See #1088928.
#$distribution = 'experimental';
#$distribution = 'unstable';
#$distribution = 'bookworm-backports';

# Specify an extra repository; this is the same as passing `--extra-repository` to sbuild.
#$extra_repositories = ['deb http://deb.debian.org/debian bookworm-backports main'];
#$extra_repositories = ['deb http://deb.debian.org/debian experimental main'];

# Specify the build dependency resolver; this is the same as passing `--build-dep-resolver` to sbuild.
# When building with extra repositories, often 'aptitude' is better than 'apt' (the default).
#$build_dep_resolver = 'aptitude';

# Build Architecture: all packages; this is the same as passing `-A` to sbuild.
$build_arch_all = 1;

# Build the source package in addition to the other requested build artifacts; this is the same as passing `-s` to sbuild.
$build_source = 1;

# Produce a .changes file suitable for a source-only upload; this is the same as passing `--source-only-changes` to sbuild.
$source_only_changes = 1;

## Run lintian after every build (in the same chroot as the build); use --no-run-lintian to override.
$run_lintian = 0;
# Display info tags.
$lintian_opts = ['--display-info', '--verbose', '--fail-on', 'error,warning', '--info'];
# Display info and pedantic tags, as well as overrides.
#$lintian_opts = ['--display-info', '--verbose', '--fail-on', 'error,warning', '--info', '--pedantic', '--show-overrides'];

## Run autopkgtest after every build (in a new, clean, chroot); use --no-run-autopkgtest to override.
$run_autopkgtest = 0;
# Specify autopkgtest options.  The commented example below is the default since trixie.
#$autopkgtest_opts = ['--apt-upgrade', '--', 'unshare', '--release', '%r', '--arch', '%a' ];

## Run piuparts after every build (in a new, temporary, chroot); use --no-run-piuparts to override.
# this does not work in bookworm
$run_piuparts = 0;
# Build a temporary chroot.
$piuparts_opts = ['--no-eatmydata', '--distribution=%r', '--fake-essential-packages=systemd-sysv'];
# Build a temporary chroot that uses apt-cacher-ng as a proxy to save bandwidth and time and doesn't disable eatmydata to speed up processing.
#$piuparts_opts = ['--distribution=%r', '--bootstrapcmd=mmdebstrap --skip=check/empty --variant=minbase --aptopt="Acquire::http { Proxy \"http://127.0.0.1:3142\"; }"'];

$build_dir = '/home/builder/build';
$clean_source = 0;
$verbose = 1;

1;
EOF

FROM builder AS build
COPY . /home/builder/src/
ARG CACHEBUST=1
RUN --security=insecure --mount=type=tmpfs,target=/tmp mknod -m600 /dev/console c 5 1 && \
    sbuild --dist=${DIST} --arch=${ARCH} | tee /home/builder/sbuild.log || :
RUN if [ $(ls -A /home/builder/build/ | wc -l) -eq 0 ]; then mv /home/builder/sbuild.log /home/builder/build/; fi

FROM scratch AS deploy
COPY --from=build /home/builder/build/. /
