package main

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:sys/posix"

/***** GLOBAL VARIABLES *****/
original_properties: posix.termios

/***** TERMINAL *****/

// An error reporting function
die :: proc(s: cstring) {
	// Clear the terminal and reposition the cursor
	clear_screen()
	reposition_cursor()

	restoreTerminal()
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
	raw = original_properties

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


editorReadKey :: proc() -> u8 {
	nread: libc.ssize_t
	c: u8

	for {
		nread = posix.read(posix.STDIN_FILENO, &c, 1)

		if nread == 1 do break

		if nread == -1 && posix.errno() != .EAGAIN do die("Read Failed")
	}

	return c

}

/***** INPUT HANDLING *****/

editorProcessKeyPress :: proc() {
	c: u8 = editorReadKey()

	fmt.printf("%d %c\r\n", c, rune(c))

	switch c {
	case ctrl_key('q'):
		// Clear the terminal and reposition the cursor
		clear_screen()
		reposition_cursor()
		restoreTerminal()
		os.exit(0)
	}
}

/***** OUTPUT HANDLING *****/
editorRefreshScreen :: proc() {

	clear_screen()
	reposition_cursor()

	editorDrawRows()
	reposition_cursor()

}

/**
* Draw a "~"
*/
editorDrawRows :: proc() {
	for y in 0 ..< 24 {
		posix.write(posix.STDOUT_FILENO, raw_data(string("~\r\n")), 3)
	}
}

/***** INIT *****/

main :: proc() {

	enableRawMode()

	for {
		editorRefreshScreen()
		editorProcessKeyPress()
	}

}


/************* HELPER FUNCTIONS *************/
/**
* When you press ctrl + a key, the ctrl just masks bit 5 and 6 of the 8 bits (read from right to left, 0 indexed)
* and sends that input to stdin. We will mimic that by AND-ing our key with 0x01f. We can compare the returned value
* from this function with the stdin char read to see if ctrl+key is pressed!
*/
ctrl_key :: proc(key: u8) -> u8 {
	return key & 0x01f
}

clear_screen :: proc() {
	// We are writing  4 bytes. \x1b is the first byte, and [2J the other 3.
	// Most terminal escape characters start with the escape character \x1b and a [
	// Now escape characters take in arguments, kinda like a function.
	// So the function/command we want to use is `J` which is for clearning the screen and the argument
	// we pass to the command `J` is `2`
	// 2 here tells J to clear the whole screen.
	// There's also 0 and 1. 0 means clear the screen from the cursor to the end.
	// And 1 means clear screen upto the cursor.
	posix.write(posix.STDOUT_FILENO, raw_data(string("\x1b[2J")), 4)
}

reposition_cursor :: proc() {
	posix.write(posix.STDOUT_FILENO, raw_data(string("\x1b[H")), 3) // Reposition the cursor to start the top left

}
/************* HELPER FUNCTIONS *************/
