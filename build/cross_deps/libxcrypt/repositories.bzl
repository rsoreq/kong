"""A module defining the third party dependency OpenResty"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def libxcrypt_repositories():
    """Defines the libcrypt repository"""

    # many distros starts replace glibc/libcrypt with libxcrypt
    # thus crypt.h and libcrypt.so.1 are missing from cross tool chain
    # ubuntu2004: 4.4.10
    # ubuntu2204: 4.4.27
    http_archive(
        name = "cross_deps_libxcrypt",
        url = "https://github.com/besser82/libxcrypt/releases/download/v4.5.2/libxcrypt-4.5.2.tar.xz",
        sha256 = "71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071",
        strip_prefix = "libxcrypt-4.5.2",
        build_file = "//build/cross_deps/libxcrypt:BUILD.libxcrypt.bazel",
    )
