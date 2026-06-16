package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:sys/posix"

original_properties: posix.termios

// An error reporting function
die :: proc(s: cstring) {
	posix.perror(s)
	os.exit(1)
}

// turn off echoing in terminal
// enabling raw mode
enableRawMode :: proc() {
	// Write original properties to the struct
	if ok := posix.tcgetattr(posix.STDIN_FILENO, &original_properties); ok != posix.result(0) do die("tcgetattr failed")

	if ok := posix.atexit(restoreTerminal); ok != 0 do die("atexit failed")


	raw: posix.termios // tremios struct	

	// get current parameters
	if ok := posix.tcgetattr(posix.STDIN_FILENO, &raw); ok != posix.result(0) do die("tcgetattr failed")

	// remove ECHO from set of input flags (no input feedback)
	raw.c_lflag -= {.ECHO}

	// turn off canoniclal mode (read byte by byte)
	raw.c_lflag -= {.ICANON}

	// Disable ctrl+c and ctrl+z ssignal interrupts
	raw.c_lflag -= {.ISIG}

	// Disable ctrl+s and ctrl+q and ctrl+v
	raw.c_iflag -= {.IXON, .ICRNL}
	raw.c_lflag -= {.IEXTEN}

	// Disable output post processing
	raw.c_oflag -= {.OPOST}


	raw.c_cflag += {.CS8}

	raw.c_cc[.VMIN] = 0
	raw.c_cc[.VTIME] = 1

	//Set these terminal attributes
	if ok := posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw); ok != posix.result(0) do die("tcsetattr failed")

}

restoreTerminal :: proc "cdecl" () {
	// Add context
	context = runtime.default_context()
	if ok := posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &original_properties); ok != posix.result(0) do die("tcsetattr failed")
}

main :: proc() {

	enableRawMode()

	// read directly from stdin as bytes into buffer c
	for {
		c: u8 // read the current character

		if ok := posix.read(posix.STDIN_FILENO, &c, 1); ok == -1 do die("read failed")

		if c == 'q' do break

		if libc.iscntrl(i32(c)) != 0 {
			fmt.printf("%d \r\n", c)
		} else {
			fmt.printf("%d %c\r\n", c, rune(c))
		}
	}
}
