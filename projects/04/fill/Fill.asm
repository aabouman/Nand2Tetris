// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed.
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.

    @8192
    D=A
    @screen_words
    M=D

    @last_keyboard_state
    M=0
    @curr_keyboard_state
    M=0

    @black_screen_word
    M=-1


(KEYBOARD_LOOP)
    @screen_itr
    M=0

    // Load keyboard state.
    @KBD
    D=M
    @keyboard_state
    M=D
    D=M
    // If keyboard has any button pressed, loop.
    @KEYBOARD_LOOP
    D;JEQ

(SCREEN_LOOP)
    // Check if iterator is larger than R1.
    @screen_words
    D=M
    @screen_itr
    D=D-M
    @SCREEN_END
    D;JLE

    @screen_itr
    D=M
    @SCREEN
    D=D+A
    @screen_index
    M=D

    @black_screen_word
    D=M
    @screen_index
    A=M
    M=D

    // Increment iterator and loop.
    @screen_itr
    M=M+1
    @SCREEN_LOOP
    0;JMP

(SCREEN_END)

    @KEYBOARD_LOOP
    0;JMP
