#!/bin/sh

# TODO: Document exit codes: 1, 2, 3, 130
# TODO: Support switching to another user other than root
# TODO: Support saving a file if saving fails but the edit was successful?
# TODO: Support read and write permissions
# TODO: Better error messages and error codes
# TODO: Put into function and allow for it to be sourced or executed
# TODO: Remove mktemp dependency for a posix compliant impl
# TODO: Param to pass editor
# TODO: Use signals (USR1 and USR2) to communicate 'checkpoints' between processes
# doasedit: sudoedit for doas.

set -e

print_help() {
	printf "Usage: %s<file-to-edit>\n" "$(basename "${0}")" >&2
}

[ "${#}" -lt 1 ] &&	print_help && exit 1

# process arguments

DOASEDIT_PATH="${1}"

# Set the editor to use to DOASEDIT_EDITOR or VISUAL if unset or EDITOR if unset
DOASEDIT_EDITOR="${DOASEDIT_EDITOR:-${VISUAL:-${EDITOR}}}"
# Fallbacks incase no editor was set
if [ -z "${DOASEDIT_EDITOR}" ]; then
	if command -v 'vim' >/dev/null 2>&1; then
		DOASEDIT_EDITOR='vim'
	elif command -v 'vi' >/dev/null 2>&1; then
		DOASEDIT_EDITOR='vi'
	else
		printf "Error: No editor found.\n" >&2
		printf "Set VISUAL (or EDITOR) to the editor to be used for editing.\n" >&2
		exit 1
	fi
fi

# Create a working directory, secure temporary directory. `mktemp -d` is atomic.
DOASEDIT_WORK_DIR=$(mktemp -d -t doasedit.XXXXXXXXXX)

# Easy self resource management
trap '
	[ -n "${DOASEDIT_FILE_PID}" ] && { kill -1 "${DOASEDIT_FILE_PID}" 2>/dev/null || true; }
	rm -rf "${DOASEDIT_WORK_DIR} || true"
' EXIT INT HUP TERM


DOASEDIT_FILE="${DOASEDIT_WORK_DIR}/$(basename "${DOASEDIT_PATH}")"
DOASEDIT_FILE_PIPE="${DOASEDIT_WORK_DIR}/pipe"

mkfifo "${DOASEDIT_FILE_PIPE}"

# Access to the file is managed in a privileged shell instance
doas sh -c '
	set -e
	
	DOASEDIT_FILE="${1}"
	DOASEDIT_FILE_PIPE="${2}"

	if [ ! -f "${DOASEDIT_FILE}" ]; then
		printf "Error: File not found or is not a regular file: \"${DOASEDIT_FILE}\"\n" 1>&2
		exit 3
	fi
	
	DOASEDIT_TMP=$(mktemp -t "doasedit.XXXXXXXXXX")

	trap "rm -f \"${DOASEDIT_TMP}\"" EXIT INT HUP TERM
	cp --preserve=all --reflink=auto "${DOASEDIT_FILE}" "${DOASEDIT_TMP}"

	# Send existing file contents for editing
	cat "${DOASEDIT_FILE}" > "${DOASEDIT_FILE_PIPE}"

	cat < "${DOASEDIT_FILE_PIPE}" > "${DOASEDIT_TMP}"
	mv -f "${DOASEDIT_TMP}" "${DOASEDIT_FILE}"
	trap "" EXIT INT HUP TERM
' sh "${DOASEDIT_PATH}" "${DOASEDIT_FILE_PIPE}" &

DOASEDIT_FILE_PID="${!}"

# Get the file contents, store in a temporary file and edit the file
cat "${DOASEDIT_FILE_PIPE}" > "${DOASEDIT_FILE}"

${DOASEDIT_EDITOR} -- "${DOASEDIT_FILE}" || true

if [ "$(realpath "${DOASEDIT_PATH}")" = "/etc/doas.conf" ]; then
	while ! doas -C "${DOASEDIT_FILE}"; do
		printf "try again (y/n)?: "
		read -r DOASEDIT_USER_RESPONSE
		if [ "${DOASEDIT_USER_RESPONSE}" = 'y' ] || [ "${DOASEDIT_USER_RESPONSE}" = 'Y' ]; then
			${DOASEDIT_EDITOR} -- "${DOASEDIT_FILE}" || true
		else
			# Traps should handle all edge cases
			exit 1
		fi
	done
fi

cat "${DOASEDIT_FILE}" > "${DOASEDIT_FILE_PIPE}"
printf "File '%s' has been updated.\n" "${DOASEDIT_PATH}"

# Wait for the background process to finish
wait "${DOASEDIT_FILE_PID}"
