package main

import "core:fmt"
import "core:sys/posix"


original_properties: posix.termios


// turn off echoing in terminal
// enabling raw mode
enableRawMode :: proc() {
	// Write original properties to the struct
	posix.tcgetattr(posix.STDERR_FILENO, &original_properties)
	posix.atexit(restoreTerminal)


	raw: posix.termios // tremios struct

	// get current parameters
	posix.tcgetattr(posix.STDIN_FILENO, &raw)

	// remove ECHO from set of input flags (no input feedback)
	raw.c_lflag -= {.ECHO}

    // turn off canoniclal mode (rread byte by byte)
    raw.c_lflag -= {.ICANON}

	//Set these terminal attributes
	posix.tcsetattr(posix.STDERR_FILENO, .TCSAFLUSH, &raw)


}

restoreTerminal :: proc "cdecl"() {
	posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &original_properties)
}

main :: proc() {

	enableRawMode()

	c: u8 // read the current character

	// read directly from stdin as bytes into buffer c
	for posix.read(posix.STDIN_FILENO, &c, 1) == 1 {
		// Press q to exit the terminal
		if c == 'q' do break
        else do fmt.println(c)
	}
}
