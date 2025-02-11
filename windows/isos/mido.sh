#!/bin/sh

# Copyright (C) 2023 Elliot Killick <contact@elliotkillick.com>
# Licensed under the MIT License. See LICENSE file for details.

[ "$DEBUG" ] && set -x

# Prefer Dash shell for greater security if available
if [ "$BASH" ] && command -v dash > /dev/null; then
    exec dash "$0" "$@"
fi

# Test for 4-bit color (16 colors)
if [ "0$(tput colors 2> /dev/null)" -ge 16 ]; then
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    NC='\033[0m'
fi

# Avoid printing messages as potential terminal escape sequences
echo_ok() { printf "%b%s%b" "${GREEN}[+]${NC} " "$1" "\n" >&2; }
echo_info() { printf "%b%s%b" "${BLUE}[i]${NC} " "$1" "\n" >&2; }
echo_err() { printf "%b%s%b" "${RED}[!]${NC} " "$1" "\n" >&2; }

format() { fmt --width 80; }

word_count() { echo $#; }

usage() {
    echo "Mido - The secure Microsoft Windows Downloader (for Unix)"
    echo ""
    echo "Usage: $0 <windows_media>..."
    echo ""
    echo "Download specified list of Windows media."
    echo ""
    echo "Specify \"all\", or one or more of the following Windows media:"
    echo "  win7x64-ultimate"
    echo "  win81x64"
    echo "  win10x64"
    echo "  win11x64 (untested, testers wanted)"
    echo "  win81x64-enterprise-eval"
    echo "  win10x64-enterprise-eval"
    echo "  win11x64-enterprise-eval (untested, testers wanted)"
    echo "  win10x64-enterprise-ltsc-eval (most secure)"
    echo "  win2008r2"
    echo "  win2012r2-eval"
    echo "  win2016-eval"
    echo "  win2019-eval"
    echo "  win2022-eval (untested, testers wanted)"
    echo ""
    echo "Each ISO download takes between 3 - 7 GBs."
    echo ""
    echo "Updates"
    echo "-------"
    echo "All the downloads provided here are the most up-to-date releases that Microsoft provides. This is ensured by programmatically checking Microsoft's official download pages to get the latest download link. In other cases, the Windows version in question is no longer supported by Microsoft meaning a direct download link (stored in Mido) will always point to the most up-to-date release." | format
    echo ""
    echo "Remember to update Windows to the latest patch level after installation."
    echo ""
    echo "Overuse"
    echo "-------"
    echo "Newer consumer versions of Windows including win81x64, win10x64, and win11x64 are downloaded through Microsoft's gated download web interface. Do not overuse this interface. Microsoft may be quick to do ~24 hour IP address bans after only a few download requests (especially if they are done in quick succession). Being temporarily banned from one of these downloads (e.g. win11x64) doesn't cause you to be banned from any of the other downloads provided through this interface." | format
    echo ""
    echo "Privacy Preserving Technologies"
    echo "-------------------------------"
    echo "The aforementioned Microsoft gated download web interface is currently blocking Tor (and similar technologies). They say this is to prevent people in restricted regions from downloading certain Windows media they shouldn't have access to. This is fine by most standards because Tor is too slow for large downloads anyway and we have checksum verification for security." | format
    echo ""
    echo "Language"
    echo "--------"
    echo "All the downloads provided here are for English (United States). This helps to great simplify maintenance and minimize the user's fingerprint. If another language is desired then that can easily be configured in Windows once it's installed." | format
    echo ""
    echo "Architecture"
    echo "------------"
    echo "All the downloads provided here are for x86-64 (x64). This is the only architecture Microsoft ships Windows Server in. Also, the only architecture Qubes OS supports." | format
}

# Media naming scheme info:
# Windows Server has no architecture because Microsoft only supports amd64 for this version of Windows (the last version to support x86 was Windows Server 2008 without the R2)
# "eval" is short for "evaluation", it's simply the license type included with the Windows installation (only exists on enterprise/server) and must be specified in the associated answer file
# "win7x64" has the "ultimate" edition appended to it because it isn't "multi-edition" like the other Windows ISOs (for multi-edition ISOs the edition is specified in the associated answer file)

for arg in "$@"; do
    if [ "$arg" = "-h" ] ||  [ "$arg" = "--help" ]; then
        usage
        exit
    fi
done

if [ $# -lt 1 ]; then
    usage >&2
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        win7x64-ultimate)
            win7x64_ultimate="win7x64-ultimate.iso"
            ;;
        win81x64)
            win81x64="win81x64.iso"
            ;;
        win10x64)
            win10x64="win10x64.iso"
            ;;
        win11x64)
            win11x64="win11x64"
            ;;
        win81x64-enterprise-eval)
            win81x64_enterprise_eval="win81x64-enterprise-eval.iso"
            ;;
        win10x64-enterprise-eval)
            win10x64_enterprise_eval="win10x64-enterprise-eval.iso"
            ;;
        win11x64-enterprise-eval)
            win11x64_enterprise_eval="win11x64-enterprise-eval.iso"
            ;;
        win10x64-enterprise-ltsc-eval)
            win10x64_enterprise_ltsc_eval="win10x64-enterprise-ltsc-eval.iso"
            ;;
        win2008r2)
            win2008r2="win2008r2.iso"
            ;;
        win2012r2-eval)
            win2012r2_eval="win2012r2-eval.iso"
            ;;
        win2016-eval)
            win2016_eval="win2016-eval.iso"
            ;;
        win2019-eval)
            win2019_eval="win2019-eval.iso"
            ;;
        win2022-eval)
            win2022_eval="win2022-eval.iso"
            ;;
        all)
            win7x64_ultimate="win7x64-ultimate.iso"
            win81x64="win81x64.iso"
            win10x64="win10x64.iso"
            win11x64="win11x64.iso"
            win81x64_enterprise_eval="win81x64-enterprise-eval.iso"
            win10x64_enterprise_eval="win10x64-enterprise-eval.iso"
            win11x64_enterprise_eval="win11x64-enterprise-eval.iso"
            win10x64_enterprise_ltsc_eval="win10x64-enterprise-ltsc-eval.iso"
            win2008r2="win2008r2.iso"
            win2012r2_eval="win2012r2-eval.iso"
            win2016_eval="win2016-eval.iso"
            win2019_eval="win2019-eval.iso"
            win2022_eval="win2022-eval.iso"
            ;;
        *)
            echo_err "Invalid Windows media specified: $arg"
            exit 1
            ;;
    esac
done

local_dir="$(dirname -- "$(readlink -f -- "$0")")"
cd "$local_dir" || exit

set -e

handle_curl_error() {
    error_code="$1"

    case "$error_code" in
        6 | 7)
            echo_err "Failed to contact Microsoft servers! Is there an Internet connection?"
            ;;
        23)
            # TODO: Perform verification of any already downloaded ISOs and then exit here
            echo_err "Failed at writing Windows media to disk! Out of disk space or permission error?"
            ;;
        26)
            echo_err "Ran out of memory during download!"
            ;;
        36)
            echo_err "Failed to continue earlier download!"
            ;;
        22)
            echo_err "Microsoft servers returned failing HTTP status code!"
            ;;
        *)
            # Must be some other server error (possibly with this specific request/file)
            # This is when accounting for all possible errors in the curl manual assuming a correctly formed HTTP(S) request, using only the curl features we're using, and a sane build
            echo_err "Server returned an error status!"
            ;;
    esac

    return "$error_code"
}

part_ext=".PART"
unverified_ext=".UNVERIFIED"

scurl_file() {
    out_file="$1"
    tls_version="$2"
    url="$3"

    part_file="${out_file}${part_ext}"

    # --location: Microsoft likes to change which endpoint these downloads are stored on but is usually kind enough to add redirects
    # --fail: Return an error on server errors where the HTTP response code is 400 or greater
    curl --progress-bar --location --output "$part_file" --continue-at - --fail --proto =https "--tlsv$tls_version" -- "$url" || {
        error_code=$?
        handle_curl_error "$error_code"

        # Clean up and make sure future resumes don't happen from bad download resume files
        if [ -f "$out_file" ]; then
            # If file is empty, bad HTTP code, or bad download resume file
            if [ ! -s "$out_file" ] || [ "$error_code" = 22 ] || [ "$error_code" = 36 ]; then
                echo_info "Deleting failed download..."
                rm -f "$out_file"
            fi
        fi

        return 1
    }

    # Full downloaded succeeded, ready for verification check
    mv "$part_file" "${out_file}${unverified_ext}"
}

manual_verification() {
    media_verification_failed_list="$1"
    checksum_verification_failed_list="$2"

    echo_info "Manual verification instructions"
    echo "    1. Get checksum (may already be done for you):" >&2
    echo "    sha256sum <ISO_FILENAME>" >&2
    echo "" >&2
    echo "    2. Verify media:" >&2
    echo "    Web search: https://duckduckgo.com/?q=%22CHECKSUM_HERE%22" >&2
    echo "    Onion search: https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/?q=%22CHECKSUM_HERE%22" >&2
    echo "    \"No results found\" or unexpected results indicate the media has been modified and should not be used." >&2
    echo "" >&2
    echo "    3. Remove the $unverified_ext extension from the file after performing or deciding to skip verification (not recommended):" >&2
    echo "    mv <ISO_FILE>$unverified_ext <ISO_FILE>" >&2
    echo "" >&2

    for media in $media_verification_failed_list; do
        # Read current checksum in list and then read remaining checksums back into the list (effectively running "shift" on the variable)
        # POSIX sh doesn't support indexing so do this instead to iterate both lists at once
        # POSIX sh doesn't support here-strings (<<<). We could also use the "cut" program but that's slower
IFS=' ' read -r checksum checksum_verification_failed_list << EOF
$checksum_verification_failed_list
EOF

        echo "    ${media}${unverified_ext} = $checksum" >&2
        echo "        Web search: https://duckduckgo.com/?q=%22$checksum%22" >&2
        echo "        Onion search: https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/?q=%22$checksum%22" >&2
        echo "        mv ${media}${unverified_ext} $media" >&2
        echo "" >&2
    done

    echo "    Theses searches can be performed in a web/Tor browser or using ddgr (Fedora/Debian packages available) terminal search tool if preferred." >&2
    echo "    Once validated, consider updating the checksums in Mido by submitting a pull request on GitHub." >&2

    # If you're looking for a single secondary source to cross-reference checksums then try here: https://files.rg-adguard.net/search
    # This site is recommended by the creator of Rufus in the Fido README and has worked well for me
}

consumer_download() {
    # Download newer consumer Windows versions from behind gated Microsoft API
    # This function aims to precisely emulate what Fido does down to the URL requests and HTTP headers (exceptions: updated user agent and referer adapts to Windows version instead of always being "windows11") but written in POSIX sh (with coreutils) and curl instead of PowerShell (also simplified to greatly reduce attack surface)
    # However, differences such as the order of HTTP headers and TLS stacks (could be used to do TLS fingerprinting) still exist
    #
    # Command emulated: ./Fido -Win 10 -Lang English -Verbose
    # "English" = "English (United States)" (as opposed to the default "English (International)")
    # For testing Fido, replace all "https://" with "http://" and remove all instances of "-MaximumRedirection 0" (to allow redirection of HTTP traffic to HTTPS) so HTTP requests can easily be inspected in Wireshark
    # Fido (command-line only) works under PowerShell for Linux if that makes it easier for you
    # UPDATE: Fido v1.4.2+ no longer works without being edited on Linux due to these issues on the Fido GitHub repo (and possibly others after these): #56 and #58
    #
    # If this function in Mido fails to work for you then please test with the Fido script before creating an issue because we basically just copy what Fido does exactly:
    # https://github.com/pbatard/Fido

    out_file="$1"
    # Either 8, 10, or 11
    windows_version="$2"

    url="https://www.microsoft.com/en-us/software-download/windows$windows_version"
    if [ "$windows_version" = 8 ] || [ "$windows_version" = 10 ]; then
        url="${url}ISO"
    fi

    user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0"
    # uuidgen: For MacOS (installed by default) and other systems (e.g. with no /proc) that don't have a kernel interface for generating random UUIDs
    session_id="$(cat /proc/sys/kernel/random/uuid 2> /dev/null || uuidgen --random)"

    # Get product edition ID for latest release of given Windows version
    # Product edition ID: This specifies both the Windows release (e.g. 22H2) and edition ("multi-edition" is default, either Home/Pro/Edu/etc., we select "Pro" in the answer files) in one number
    # This is the *only* request we make that Fido doesn't. Fido manually maintains a list of all the Windows release/edition product edition IDs in its script (see: $WindowsVersions array). This is helpful for downloading older releases (e.g. Windows 10 1909, 21H1, etc.) but we always want to get the newest release which is why we get this value dynamically
    # Also, keeping a "$WindowsVersions" array like Fido does would be way too much of a maintenance burden
    # Remove "Accept" header that curl sends by default
    iso_download_page_html="$(curl --user-agent "$user_agent" --header "Accept:" --fail --proto =https --tlsv1.3 -- "$url")" || {
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    iso_download_page_html="$(echo "$iso_download_page_html" | head --bytes 102400)"
    # tr: Filter for only numerics to prevent HTTP parameter injection
    product_edition_id="$(echo "$iso_download_page_html" | grep --extended-regexp --only-matching '<option value="[0-9]+">Windows' | cut --delimiter '"' --fields 2 | head --lines 1 | tr --complement --delete '0-9' | head --bytes 16)"
    [ "$VERBOSE" ] && echo "Product edition ID: $product_edition_id" >&2

    # Permit Session ID
    # "org_id" is always the same value
    curl --output /dev/null --user-agent "$user_agent" --header "Accept:" --fail --proto =https --tlsv1.2 -- "https://vlscppe.microsoft.com/tags?org_id=y6jn8c31&session_id=$session_id" || {
        # This should only happen if there's been some change to how this API works (copy whatever fix Fido implements)
        handle_curl_error $?
        return $?
    }

    # Extract everything after the last slash
    url_segment_parameter="${url##*/}"

    # Get language -> skuID association table
    # SKU ID: This specifies the language of the ISO. We always use "English (United States)", however, the SKU for this changes with each Windows release
    # We must make this request so our next one will be allowed
    # --data "" is required otherwise no "Content-Length" header will be sent causing HTTP response "411 Length Required"
    language_skuid_table_html="$(curl --request POST --user-agent "$user_agent" --data "" --header "Accept:" --fail --proto =https --tlsv1.3 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=getskuinformationbyproductedition&sessionId=$session_id&productEditionId=$product_edition_id&sdVersion=2")" || {
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    language_skuid_table_html="$(echo "$language_skuid_table_html" | head --bytes 10240)"
    # tr: Filter for only alphanumerics or "-" to prevent HTTP parameter injection
    sku_id="$(echo "$language_skuid_table_html" | grep "English (United States)" | sed 's/&quot;//g' | cut --delimiter ',' --fields 1  | cut --delimiter ':' --fields 2 | tr --complement --delete '[:alnum:]-' | head --bytes 16)"
    [ "$VERBOSE" ] && echo "SKU ID: $sku_id" >&2

    # Get ISO download link
    # If any request is going to be blocked by Microsoft it's always this last one (the previous requests always seem to succeed)
    # --referer: Required by Microsoft servers to allow request
    iso_download_link_html="$(curl --request POST --user-agent "$user_agent" --data "" --referer "$url" --header "Accept:" --fail --proto =https --tlsv1.3 -- "https://www.microsoft.com/en-US/api/controls/contentinclude/html?pageId=6e2a1789-ef16-4f27-a296-74ef7ef5d96b&host=www.microsoft.com&segments=software-download,$url_segment_parameter&query=&action=GetProductDownloadLinksBySku&sessionId=$session_id&skuId=$sku_id&language=English&sdVersion=2")" || {
        # This should only happen if there's been some change to how this API works
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    iso_download_link_html="$(echo "$iso_download_link_html" | head --bytes 4096)"

    if ! [ "$iso_download_link_html" ]; then
        # This should only happen if there's been some change to how this API works
        echo_err "Microsoft servers gave us an empty response to our request for an automated download. Please manually download this ISO in a web browser: $url"
        manual_verification="true"
        return 1
    fi

    if echo "$iso_download_link_html" | grep --quiet "We are unable to complete your request at this time."; then
        echo_err "Microsoft blocked the automated download request based on your IP address. Please manually download this ISO in a web browser here: $url"
        manual_verification="true"
        return 1
    fi

    # Filter for 64-bit ISO download URL
    # sed: HTML decode "&" character
    # tr: Filter for only alphanumerics or punctuation
    iso_download_link="$(echo "$iso_download_link_html" | grep --only-matching "https://software.download.prss.microsoft.com.*IsoX64" | cut --delimiter '"' --fields 1 | sed 's/&amp;/\&/g' | tr --complement --delete '[:alnum:][:punct:]' | head --bytes 512)"

    if ! [ "$iso_download_link" ]; then
        # This should only happen if there's been some change to the download endpoint web address
        echo_err "Microsoft servers gave us no download link to our request for an automated download. Please manually download this ISO in a web browser: $url"
        manual_verification="true"
        return 1
    fi

    echo_ok "Got latest ISO download link (valid for 24 hours): $iso_download_link"

    # Download ISO
    scurl_file "$out_file" "1.3" "$iso_download_link"
}

enterprise_eval_download() {
    # Download enterprise evaluation Windows versions

    out_file="$1"
    tls_version="$2"
    windows_version="$3"
    enterprise_type="$4"

    url="https://www.microsoft.com/en-us/evalcenter/download-$windows_version"

    iso_download_page_html="$(curl --location --fail --proto =https --tlsv1.3 -- "$url")" || {
        handle_curl_error $?
        return $?
    }

    # Limit untrusted size for input validation
    iso_download_page_html="$(echo "$iso_download_page_html" | head --bytes 102400)"

    if ! [ "$iso_download_page_html" ]; then
        # This should only happen if there's been some change to where this download page is located
        echo_err "Windows enterprise evaluation download page gave us an empty response"
        return 1
    fi

    iso_download_links="$(echo "$iso_download_page_html" | grep --only-matching "https://go.microsoft.com/fwlink/p/?LinkID=[0-9]\+&clcid=0x[0-9a-z]\+&culture=en-us&country=US")" || {
        # This should only happen if there's been some change to the download endpoint web address
        echo_err "Windows enterprise evaluation download page gave us no download link"
        return 1
    }

    # Limit untrusted size for input validation
    iso_download_links="$(echo "$iso_download_links" | head --bytes 1024)"

    if [ "$enterprise_type" = "enterprise" ]; then
        # Select x64 download link
        iso_download_link=$(echo "$iso_download_links" | head --lines 2 | tail --lines 1)
    elif [ "$enterprise_type" = "ltsc" ]; then
        # Select x64 LTSC download link
        iso_download_link=$(echo "$iso_download_links" | head --lines 4 | tail --lines 1)
    else
        # Only one download link (Server)
        iso_download_link="$iso_download_links"
    fi

    # Follow redirect so proceeding log message is useful
    iso_download_link="$(curl --location --output /dev/null --silent --write-out "%{url_effective}" --head --fail --proto =https "--tlsv$tls_version" -- "$iso_download_link")" || {
        # This should only happen if the Microsoft servers are down
        handle_curl_error $?
        return $?
    }

    echo_ok "Got latest ISO download link: $iso_download_link"

    # Download ISO
    scurl_file "$out_file" "$tls_version" "$iso_download_link"
}

exit_abrupt() {
    exit_code="${1:-$?}"
    echo "" >&2
    echo_err "Mido was exited abruptly! PARTially downloaded or UNVERIFIED Windows media may exist. Please re-run this Mido command and do not use the bad media."
    exit "$exit_code"
}

echo_info "Downloading Windows media from official Microsoft servers..."

# All trappable (excludes KILL and STOP), by default fatal to shell process (excludes CHLD and CONT), and non-unused (excludes STKFLT) signals in order from 1-20 according to signal(7)
# SIG prefixes removed for POSIX sh compatibility
trap exit_abrupt HUP INT QUIT ILL TRAP ABRT BUS FPE USR1 SEGV USR2 PIPE ALRM TERM TSTP

# Disable shell globbing
# This isn't necessary given that all unquoted variables (e.g. for determining word count) are set directly by us but it's just a precaution
set -f

media_list="$win7x64_ultimate $win81x64 $win10x64 $win11x64 $win81x64_enterprise_eval $win10x64_enterprise_eval $win11x64_enterprise_eval $win10x64_enterprise_ltsc_eval $win2008r2 $win2012r2_eval $win2016_eval $win2019_eval $win2022_eval"

media_download_failed_list=""

for media in $media_list; do
    case "$media" in
        "$win7x64_ultimate")
            echo_info "Downloading Windows 7..."
            # Source, Google search this (it can be found many places): "dec04cbd352b453e437b2fe9614b67f28f7c0b550d8351827bc1e9ef3f601389" "download.microsoft.com"
            # This Windows 7 ISO bundles MSU update packages
            # It's the most up-to-date Windows 7 ISO that Microsoft offers (August 2018 update): https://files.rg-adguard.net/files/cea4210a-3474-a17a-88d4-4b3e10bd9f66
            # In particular interest to us is the update that adds support for SHA-256 driver signatures so Qubes Windows Tools installs correctly
            #
            # Microsoft purged Windows 7 from all their servers...
            # More info about this event: https://github.com/pbatard/Fido/issues/64
            # Luckily, the ISO is still available on the Wayback Machine so get the last copy of it from there
            # This is still secure because we validate with the checksum from before the purge
            # The only con then is that web.archive.org is a much slower download source than the Microsoft servers
            echo_info "Microsoft has unfortunately purged any and all downloads of Windows 7 from their servers so this identical download is sourced from: web.archive.org"
            scurl_file "$media" "1.3" "https://web.archive.org/web/20221228154140/https://download.microsoft.com/download/5/1/9/5195A765-3A41-4A72-87D8-200D897CBE21/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_ULTIMATE_x64FRE_en-us.iso"
            ;;
        "$win81x64")
            echo_info "Downloading Windows 8.1..."
            consumer_download "$media" 8
            ;;
        "$win10x64")
            echo_info "Downloading Windows 10..."
            consumer_download "$media" 10
            ;;
        "$win11x64")
            echo_info "Downloading Windows 11..."
            consumer_download "$media" 11
            ;;

        "$win81x64_enterprise_eval")
            echo_info "Downloading Windows 8.1 Enterprise Evaluation..."
            # This download link is "Update 1": https://files.rg-adguard.net/file/166cbcab-1647-53d5-1785-6ef9e22a6500
            # A more up-to-date "Update 3" enterprise ISO exists but it was only ever distributed by Microsoft through MSDN which means it's impossible to get a Microsoft download link now: https://files.rg-adguard.net/file/549a58f2-7813-3e77-df6c-50609bc6dd7c
            # win81x64 is "Update 3" but that's isn't an enterprise version (although technically it's possible to modify a few files in the ISO to get any edition)
            # If you want "Update 3" enterprise though (not from Microsoft servers), then you should still be able to get it from here: https://archive.org/details/en_windows_8.1_enterprise_with_update_x64_dvd_6054382_202110
            # "Update 1" enterprise also seems to be the ISO used by other projects
            # Old source, used to be here but Microsoft deleted it: http://technet.microsoft.com/en-us/evalcenter/hh699156.aspx
            # Source: https://gist.github.com/eyecatchup/11527136b23039a0066f
            scurl_file "$media" "1.2" "https://download.microsoft.com/download/B/9/9/B999286E-0A47-406D-8B3D-5B5AD7373A4A/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_ENTERPRISE_EVAL_EN-US-IR3_CENA_X64FREE_EN-US_DV9.ISO"
            ;;
        "$win10x64_enterprise_eval")
            echo_info "Downloading Windows 10 Enterprise Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-10-enterprise enterprise
            ;;
        "$win11x64_enterprise_eval")
            echo_info "Downloading Windows 11 Enterprise Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-11-enterprise enterprise
            ;;
        "$win10x64_enterprise_ltsc_eval")
            echo_info "Downloading Windows 10 Enterprise LTSC Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-10-enterprise ltsc
            ;;

        "$win2008r2")
            echo_info "Downloading Windows Server 2008 R2..."
            # Old source, used to be here but Microsoft deleted it: https://www.microsoft.com/en-us/download/details.aspx?id=11093
            # Microsoft took down the original download link provided by that source too but this new one has the same checksum
            # Source: https://github.com/rapid7/metasploitable3/pull/563
            scurl_file "$media" "1.2" "https://download.microsoft.com/download/4/1/D/41DEA7E0-B30D-4012-A1E3-F24DC03BA1BB/7601.17514.101119-1850_x64fre_server_eval_en-us-GRMSXEVAL_EN_DVD.iso"
            ;;
        "$win2012r2_eval")
            echo_info "Downloading Windows Server 2012 R2 Evaluation..."
            enterprise_eval_download "$media" 1.2 windows-server-2012-r2 server
            ;;
        "$win2016_eval")
            echo_info "Downloading Windows Server 2016 Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-server-2016 server
            ;;
        "$win2019_eval")
            echo_info "Downloading Windows Server 2019 Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-server-2019 server
            ;;
        "$win2022_eval")
            echo_info "Downloading Windows Server 2022 Evaluation..."
            enterprise_eval_download "$media" 1.3 windows-server-2022 server
            ;;
    esac || {
        media_download_failed_list="$media_download_failed_list $media"
    }
done

# shellcheck disable=SC2086
if [ "$(word_count $media_list)" -gt "$(word_count $media_download_failed_list)" ]; then
    echo_info "Verifying integrity..."
fi

# SHA256SUMS file
# Some of these Windows ISOs are EOL (e.g. win81x64) so their checksums will always match
# For all other Windows ISOs, a new release will make their checksums no longer match
#
# IMPORTANT: These checksums are not necessarily subject to being updated
# Unfortunately, the maintenance burden would be too large and even if I did there would still be some time gap between Microsoft releasing a new ISO and me updating the checksum (also, users would have to update this script)
# For these reasons, I've opted for a slightly more manual verification where you have to look up the checksum to see if it's a well-known Windows ISO checksum
# Ultimately, you have to trust Microsft because they could still include a backdoor in the verified ISO (keeping Windows air gapped could help with this)
# Community contributions for these checksums are welcome
SHA256SUMS="$(cat << EOF
dec04cbd352b453e437b2fe9614b67f28f7c0b550d8351827bc1e9ef3f601389  win7x64-ultimate.iso
d8333cf427eb3318ff6ab755eb1dd9d433f0e2ae43745312c1cd23e83ca1ce51  win81x64.iso
# Windows 10 22H2 May 2023 Update
a6f470ca6d331eb353b815c043e327a347f594f37ff525f17764738fe812852e  win10x64.iso
# Windwws 11 22H2 May 2023 Update
8059a99b8902906a90afe068ac00465c52588c2bd54f5d9d96c1297f88ef1076  win11x64.iso
2dedd44c45646c74efc5a028f65336027e14a56f76686a4631cf94ffe37c72f2  win81x64-enterprise-eval.iso
ef7312733a9f5d7d51cfa04ac497671995674ca5e1058d5164d6028f0938d668  win10x64-enterprise-eval.iso
ebbc79106715f44f5020f77bd90721b17c5a877cbc15a3535b99155493a1bb3f  win11x64-enterprise-eval.iso
e4ab2e3535be5748252a8d5d57539a6e59be8d6726345ee10e7afd2cb89fefb5  win10x64-enterprise-ltsc-eval.iso
30832ad76ccfa4ce48ccb936edefe02079d42fb1da32201bf9e3a880c8ed6312  win2008r2.iso
6612b5b1f53e845aacdf96e974bb119a3d9b4dcb5b82e65804ab7e534dc7b4d5  win2012r2-eval.iso
1ce702a578a3cb1ac3d14873980838590f06d5b7101c5daaccbac9d73f1fb50f  win2016-eval.iso
6dae072e7f78f4ccab74a45341de0d6e2d45c39be25f1f5920a2ab4f51d7bcbb  win2019-eval.iso
3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255325  win2022-eval.iso
EOF
)"

media_verification_failed_list=""
checksum_verification_failed_list=""

for media in $media_list; do
    if ! [ -f "${media}${unverified_ext}" ]; then
        continue
    fi

    # || true: Workaround Dash "set -e" bug (Bash not affected)
    # Triggering a trap (e.g. INT with CTRL+C) here will not work otherwise (this doesn't happend with "curl" only the "sha256sum" command for some reason)
    checksum="$(sha256sum "${media}${unverified_ext}" | cut --delimiter ' ' --fields 1)" || true

    # Sanity check: Assert correct size of SHA-256 checksum
    if [ ${#checksum} != 64 ]; then
        echo_err "Failed SHA-256 sanity check! Please do not use the UNVERIFIED media (it may be corrupted or malicious). Report this bug on GitHub."
        exit 1
    fi

    if echo "$SHA256SUMS" | grep --quiet "^$checksum  $media$"; then
        echo "$media: OK"
        mv "${media}${unverified_ext}" "$media"
    else
        echo "$media: UNVERIFIED"
        media_verification_failed_list="$media_verification_failed_list $media"
        checksum_verification_failed_list="$checksum_verification_failed_list $checksum"
    fi
done

#
# Ending summary
#

echo "" >&2
exit_code=0

if [ "$media_download_failed_list" ]; then
    for media in $media_download_failed_list; do
        media_download_failed_argument_list="$media_download_failed_argument_list ${media%%.iso}"
    done
    # Remove trailing space for printing
    media_download_failed_argument_list="${media_download_failed_argument_list%% }"

    # shellcheck disable=SC2086
    echo_err "$(word_count $media_download_failed_list) download(s) failed! Please re-run Mido with these arguments to attempt downloading again (any partial downloads will be resumed): $media_download_failed_argument_list"
    exit_code=1
fi

if [ "$media_verification_failed_list" ]; then
    manual_verification "$media_verification_failed_list" "$checksum_verification_failed_list"
    # shellcheck disable=SC2086
    echo_err "$(word_count $media_verification_failed_list) of the downloaded Windows media did NOT match the expected checksum! This means either that the media is a newer release than our current checksum (stored in Mido), was corrupted during download, or that is has been (potentially maliciously) modified! Please manually verify the Windows media before use:$media_verification_failed_list"
    exit_code=1
elif [ "$manual_verification" = "true" ]; then
    manual_verification
    exit_code=1
fi

if [ "$exit_code" = 0 ]; then
    echo_ok "Successfully downloaded and verified integrity of all Windows media!"
else
    echo_ok "Finished! Please see the above errors with information"
    exit "$exit_code"
fi
