_export() {
    pushd "$SCRIPT_DIR"
    echo "PROFILE_BSP_COMMIT='$(git rev-parse HEAD)'" > ".profile"
    find "linux/$1" "u-boot/$1" ".profile" | tar acvf "$OLDPWD/$1.tar.xz" --files-from -
    popd
}

_import() {
    tar axvf "$1" -C "$SCRIPT_DIR"
    pushd "$SCRIPT_DIR"
    if source "$SCRIPT_DIR/.profile" && [[ -n "${PROFILE_BSP_COMMIT:-}" ]] && [[ "$(git rev-parse HEAD)" != "$PROFILE_BSP_COMMIT" ]]
    then
        echo "Profile was exported when bsp is at commit $PROFILE_BSP_COMMIT."
        echo "You can use 'git switch -d $PROFILE_BSP_COMMIT' to ensure the best compatability."
    fi
    popd
}

_install() {
    local disk="$1" file="${2:-}" i
    local ext="${file##*.}"

    if [[ ! -b "$disk" ]]
    then
        error $EXIT_BAD_BLOCK_DEVICE "$disk"
    fi

    if [[ -n "$file" ]] && [[ ! -f "$file" ]]
    then
        error $EXIT_BAD_FILE "$file"
    fi

    sudo umount -R /mnt || true

    if [[ -b "$disk"3 ]]
    then
        # latest rbuild image
        sudo mount "$disk"3 /mnt
        sudo mount "$disk"2 /mnt/boot/efi
        sudo mount "$disk"1 /mnt/config
    elif [[ -b "$disk"2 ]]
    then
        # old rbuild image
        sudo mount "$disk"2 /mnt
        sudo mount "$disk"1 /mnt/config
    elif [[ -b "$disk"1 ]]
    then
        # armbian
        sudo mount "$disk"1 /mnt
    else
        error $EXIT_BAD_BLOCK_DEVICE "$disk"2
    fi

    case "$ext" in
        deb)
            sudo cp "$file" /mnt
            sudo systemd-nspawn -D /mnt apt-get install -y --allow-downgrades --reinstall "/$(basename "$file")"
            ;;
        dtbo)
            sudo cp "$file" /mnt/boot/dtbo
            sudo systemd-nspawn -D /mnt u-boot-update
            ;;
        dtb)
            sudo find /mnt/usr/lib/linux-image-*/ -name "$(basename "$file")" -exec mv "{}" "{}.bak" \; -exec cp "$file" "{}" \;
            ;;
        "")
            if [[ -z "$file" ]]
            then
                sudo systemd-nspawn -D /mnt
            else
                error $EXIT_UNSUPPORTED_OPTION "$file"
            fi
            ;;
        *)
            error $EXIT_UNSUPPORTED_OPTION "$file"
            ;;
    esac

    sudo umount -R /mnt

    sync
}