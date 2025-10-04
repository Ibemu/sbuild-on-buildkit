variable "MAKEFILE_DIR" {}
variable "APT_PROXY" {
    default = ""
}
variable "CACHEBUST" {
    default = "1"
}

target "default" {
    name = "build-${dist}-${arch}"
    target = "deploy"
    dockerfile = "${MAKEFILE_DIR}/Dockerfile"
    entitlements = ["security.insecure"]
    matrix = {
        dist = [
            "noble",
            "jammy",
            "focal",
            "bionic",
            "xenial",
            "trusty",
        ]
        arch = [
            "amd64",
            "arm64",
        ]
    }
    args = {
        DIST = dist
        ARCH = arch
        APT_PROXY = APT_PROXY
        CACHEBUST = CACHEBUST
    }
    output = [
        {
            type = "local"
            dest = "./build/${dist}-${arch}"
        }
    ]
}
