. += {
    version: (.image.version|split(".")|.[0:3]|join(".")),
    architecture: $arch
}
