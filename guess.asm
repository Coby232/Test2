
SYS_EXIT  equ 1
SYS_READ  equ 3
SYS_WRITE equ 4
STDIN     equ 0
STDOUT    equ 1

section .text	
	global _start
_start:
call __prompt_1
call __userInput
call __checkInput
;call __syscall

;level1
	; Get random number
	
	call __open
	mov ebx, _dev_random
	mov ecx, 0 ; RDONLY
	call __syscall

	mov ebx, eax
	push eax
	call __read
	mov ecx, randint
	mov edx, 4 ; 4 bytes of random; 32-bit
	call __syscall
	
	call __close
	pop ebx
	call __syscall

	mov eax, [randint]
	;the random number needs to be fetched before starting the levels

																				;EASY LEVEL
 ;checks if the number of tries has reached limited
_modup:
	add eax, maxrand
	jmp __easy_level

_moddown:
	sub eax, maxrand

__easy_level:

	cmp eax, maxrand
	jg _moddown
	cmp eax, 1 ; Is it lower than 1?
	jl _modup

	mov [randint], eax

	;call __write
	;mov ebx, 1
	;mov ecx, randint
	;mov edx, 4
	;call __syscall

	; Write hello message
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, hello
	mov edx, hello_len
	call __syscall

_loop:

	; Write prompt

	mov eax, [tries]
	mov ebx, 1 ; Optimization warning: May change. Do not use if tries > 9. Use standard __itoa instead.
	mov ecx, 10 ; Optimized
	call __itoa_knowndigits
	
	mov ecx, eax
	mov edx, ebx
	
	call __write
	mov ebx, 1 ; Stdout
	call __syscall
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, prompt
	mov edx, prompt_len
	call __syscall
	
	; Read input

	call __read
	mov ebx, 0 ; Stdin
	mov ecx, inputbuf
	mov edx, inputbuf_len
	call __syscall

	; Convert into integer

	mov ecx, eax
	sub ecx, 1 ; Get rid of extra newline
	
	cmp ecx, 1 ; Is the length of the number less than 1? (invalid)
	jl _reenter

	mov ebx, ecx

	mov eax, 0 ; Initalize eax
	jmp _loopconvert_nomul
;;;;
_loopconvert:

	imul eax, 10 ; Multiply by 10
	
_loopconvert_nomul:

	mov edx, ebx
	sub edx, ecx
	
	push eax
	
	mov ah, [inputbuf+edx]
	
	sub ah, 48 ; ASCII digits offset
	
	cmp ah, 0 ; Less than 0?
	jl _reenter
	cmp ah, 9 ; More than 9?
	jg _reenter

	movzx edx, ah
	
	pop eax
	add eax, edx

	loop _loopconvert
	
	jmp _convertok

_reenter:

	; Write message

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, reenter
	mov edx, reenter_len
	call __syscall

	; Repeat enter

	jmp _loop
	
_toohigh:

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toohigh
	mov edx, toohigh_len
	call __syscall

	jmp _again

_toolow:
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toolow
	mov edx, toolow_len
	call __syscall

_again:

	cmp dword [tries], 1 ; Is this the last try?
	jle _lose

	sub dword [tries], 1 ; Minus one try.
	
	jmp _loop

_lose:

	; You lose

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose
	mov edx, youlose_len
	call __syscall

	mov eax, [randint]
	call __itoa

	mov ecx, eax
	mov edx, ebx
	call __write
	mov ebx, 1 ; Stdout
	call __syscall

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose2
	mov edx, youlose2_len
	call __syscall

	mov ebx, 2 ; Exit code for OK, lose.

	jmp _exit

_convertok:

	; Compare input

	cmp eax, [randint]
	jg _toohigh
	jl _toolow

	; You win

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youwin
	mov edx, youwin_len
	call __syscall

	mov ebx, 1 ; Exit code for OK, win.

_exit:

	push ebx

	; Print normal goodbye

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, goodbye
	mov edx, goodbye_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Report OK.

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, _ok
	mov edx, _ok_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Exit

	call __exit
	pop ebx
	call __syscall
	
; Procedures

__itoa_init:

	; push eax
	; push ebx
	; We do not have to preserve as it will contain
	; A return value

	pop dword [_itoabuf]

	push ecx
	push edx

	push dword [_itoabuf]
	
	ret

__itoa: ; Accept eax (i), return eax (a), ebx (l)

	call __itoa_init

	mov ecx, 10 ; Start with 10 (first 2-digit)
	mov ebx, 1 ; If less than 10, it has 1 digit.

__itoa_loop:

	cmp eax, ecx
	jl __itoa_loopend

	imul ecx, 10 ; Then go to 100, 1000...
	add ebx, 1 ; Then go to 2, 3...
	jmp __itoa_loop

__itoa_knowndigits: ; Accept eax (i), ebx (d), ecx (m), return eax (a), ebx (l)

	call __itoa_init

__itoa_loopend:

	; Prepare for loop
	; edx now contains m
	; ecx is now ready to count.
	; eax already has i
	; ebx already has d.

	mov edx, ecx
	mov ecx, ebx
	
	push ebx

__itoa_loop2:

	push eax

	; Divide m by 10 into m

	mov eax, edx
	mov edx, 0 ; Exponent is 0
	mov ebx, 10 ; Divide by 10

	idiv ebx
	mov ebx, eax ; New m
	
	; Divide number by new m into (1)

	mov eax, [esp] ; Number
	mov edx, 0 ; Exponent is 0
	idiv ebx ; (1)

	; Store into buffer

	mov edx, [esp+4] ; Each dword has 4 bytes
	sub edx, ecx
	
	add eax, 48 ; Offset (1) as ASCII number
	
	mov [_itoabuf+edx], eax

	sub eax, 48 ; Un-offset (1) to prepare for next step

	; Multiply (1) by m into (1)

	imul eax, ebx

	; Subtract number by (1) into number
	
	mov edx, ebx ; Restore new-m back to edx as m
	
	pop ebx ; Number
	sub ebx, eax ; New number
	mov eax, ebx	

	loop __itoa_loop2

	; Return buffer array address and
	; Pop preserved ebx as length

	mov eax, _itoabuf
	pop ebx

	; Pop preserved registers and restore

	pop edx
	pop ecx	

	ret
;;;;
																						; MEDIUM LEVEL
_modup2:
	add eax, maxrand
	jmp __medium_level

_moddown2:
	sub eax, maxrand
	
__medium_level:
	cmp eax, maxrand
	jg _moddown2
	cmp eax, 1 ; Is it lower than 1?
	jl _modup2

	mov [randint], eax

	;call __write
	;mov ebx, 1
	;mov ecx, randint
	;mov edx, 4
	;call __syscall

	; Write hello message
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, hello
	mov edx, hello_len
	call __syscall

_loop2:

	; Write prompt

	mov eax, [tries]
	mov ebx, 1 ; Optimization warning: May change. Do not use if tries > 9. Use standard __itoa instead.
	mov ecx, 10 ; Optimized
	call __itoa_knowndigits2
	
	mov ecx, eax
	mov edx, ebx
	
	call __write
	mov ebx, 1 ; Stdout
	call __syscall
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, prompt
	mov edx, prompt_len
	call __syscall
	
	; Read input

	call __read
	mov ebx, 0 ; Stdin
	mov ecx, inputbuf
	mov edx, inputbuf_len
	call __syscall

	; Convert into integer

	mov ecx, eax
	sub ecx, 1 ; Get rid of extra newline
	
	cmp ecx, 1 ; Is the length of the number less than 1? (invalid)
	jl _reenter2

	mov ebx, ecx

	mov eax, 0 ; Initalize eax
	jmp _loopconvert_nomul2
;;;;
_loopconvert2:

	imul eax, 10 ; Multiply by 10
	
_loopconvert_nomul2:

	mov edx, ebx
	sub edx, ecx
	
	push eax
	
	mov ah, [inputbuf+edx]
	
	sub ah, 48 ; ASCII digits offset
	
	cmp ah, 0 ; Less than 0?
	jl _reenter2
	cmp ah, 9 ; More than 9?
	jg _reenter2

	movzx edx, ah
	
	pop eax
	add eax, edx

	loop _loopconvert2
	
	jmp _convertok2

_reenter2:

	; Write message

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, reenter
	mov edx, reenter_len
	call __syscall

	; Repeat enter

	jmp _loop2
	
_toohigh2:

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toohigh
	mov edx, toohigh_len
	call __syscall

	jmp _again

_toolow2:
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toolow
	mov edx, toolow_len
	call __syscall

_again2:

	cmp dword [tries], 1 ; Is this the last try?
	jle _lose2

	sub dword [tries], 1 ; Minus one try.
	
	jmp _loop2

_lose2:

	; You lose

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose
	mov edx, youlose_len
	call __syscall

	mov eax, [randint]
	call __itoa2

	mov ecx, eax
	mov edx, ebx
	call __write
	mov ebx, 1 ; Stdout
	call __syscall

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose2
	mov edx, youlose2_len
	call __syscall

	mov ebx, 2 ; Exit code for OK, lose.

	jmp _exit

_convertok2:

	; Compare input

	cmp eax, [randint]
	jg _toohigh2
	jl _toolow2

	; You win

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youwin
	mov edx, youwin_len
	call __syscall

	mov ebx, 1 ; Exit code for OK, win.

_exit2:

	push ebx

	; Print normal goodbye

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, goodbye
	mov edx, goodbye_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Report OK.

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, _ok
	mov edx, _ok_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Exit

	call __exit
	pop ebx
	call __syscall
	
; Procedures

__itoa_init2:

	; push eax
	; push ebx
	; We do not have to preserve as it will contain
	; A return value

	pop dword [_itoabuf]

	push ecx
	push edx

	push dword [_itoabuf]
	
	ret

__itoa2: ; Accept eax (i), return eax (a), ebx (l)

	call __itoa_init2

	mov ecx, 10 ; Start with 10 (first 2-digit)
	mov ebx, 1 ; If less than 10, it has 1 digit.

__itoa_loop2:

	cmp eax, ecx
	jl __itoa_loopend2

	imul ecx, 10 ; Then go to 100, 1000...
	add ebx, 1 ; Then go to 2, 3...
	jmp __itoa_loop2

__itoa_knowndigits2: ; Accept eax (i), ebx (d), ecx (m), return eax (a), ebx (l)

	call __itoa_init2

__itoa_loopend2:

	; Prepare for loop
	; edx now contains m
	; ecx is now ready to count.
	; eax already has i
	; ebx already has d.

	mov edx, ecx
	mov ecx, ebx
	
	push ebx

__itoa_loop2:

	push eax

	; Divide m by 10 into m

	mov eax, edx
	mov edx, 0 ; Exponent is 0
	mov ebx, 10 ; Divide by 10

	idiv ebx
	mov ebx, eax ; New m
	
	; Divide number by new m into (1)

	mov eax, [esp] ; Number
	mov edx, 0 ; Exponent is 0
	idiv ebx ; (1)

	; Store into buffer

	mov edx, [esp+4] ; Each dword has 4 bytes
	sub edx, ecx
	
	add eax, 48 ; Offset (1) as ASCII number
	
	mov [_itoabuf+edx], eax

	sub eax, 48 ; Un-offset (1) to prepare for next step

	; Multiply (1) by m into (1)

	imul eax, ebx

	; Subtract number by (1) into number
	
	mov edx, ebx ; Restore new-m back to edx as m
	
	pop ebx ; Number
	sub ebx, eax ; New number
	mov eax, ebx	

	loop __itoa_loop2

	; Return buffer array address and
	; Pop preserved ebx as length

	mov eax, _itoabuf
	pop ebx

	; Pop preserved registers and restore

	pop edx
	pop ecx	

	ret
																					;;END OF LEVEL 2
__exit:
	
	mov eax, 1 ; Exit syscall
	ret

__read:

	mov eax, 3 ; Read syscall
	ret

__write:
	
	mov eax, 4 ; Write syscall
	ret

__open:

	mov eax, 5 ; Open syscall
	ret

__close:

	mov eax, 6 ; Close syscall
	ret

__syscall:

	int 0x80 ; Interupt kernel
	ret
;take user input
__prompt_1:
mov eax,4
mov ebx,1
mov ecx,userprompt
mov edx,userprompt_len
int 0x80
;
;
mov eax,4
mov ebx,1
mov ecx,choice_1
mov edx,choice_1_len
int 0x80
;
mov eax,4
mov ebx,1
mov ecx,choice_2
mov edx,choice_2_len
int 0x80
;
mov eax,4
mov ebx,1
mov ecx,choice_3
mov edx,choice_3_len
int 0x80

__userInput:
mov eax,3 ;syscall_read
mov ebx,0 ;stdin
mov ecx,userChoice ;buffer to be stored in userChoice
mov edx,2
int 0x80
ret
__checkInput:
cmp byte[userChoice],'1'
je __easy_level
;cmp byte[userChoice],'2'
;je __medium_level
;cmp byte[userChoice],'3'
;je __hard_level
;int 0x80

;define an error loop to check if user input is invalid


; Data declaration

section .data
	;userprompt about level of difficulty strings
	userprompt db "please choose a level of difficulty",0xa,0xa
	userprompt_len equ $-userprompt

	choice_1 db "1.For Easy Press 1",0xa,0xa
	choice_1_len equ $-choice_1

	choice_2 db "2.For Medium Press 2",0xa,0xa
	choice_2_len equ $-choice_2
	
	choice_3 db "3.For Hard Press 3",0xa,0xa
	choice_3_len equ $-choice_3
	;;

	_dev_random db "/dev/random", 0xa

	maxrand equ 100
	tries dd 6

	prompt db 0xa,"Welcome to the guessing game!",0xa " tries left. Input number (1-100): ",0xa,0xa
	prompt_len equ $-prompt

	hello db 0xa, 0xa, "I am now thinking of a number. What is it?", 0xa,0xa, "Take a guess, from one to one hundred.", 0xa, 0xa
	hello_len equ $-hello

	reenter db "? REENTER", 0xa, "Invalid unsigned integer. Please re-enter your input.", 0xa
	reenter_len equ $-reenter

	toohigh db "That was too high!", 0xa, 0xa
	toohigh_len equ $-toohigh

	toolow db "That was too low!", 0xa, 0xa
	toolow_len equ $-toolow

	youwin db 0x7, 0xa, "#^$&^@%#^@#! That was correct! You win!", 0xa, 0xa
	youwin_len equ $-youwin

	youlose db "You have no more tries left! You lose!", 0xa, "The answer was "
	youlose_len equ $-youlose

	youlose2 db "! Mwahahah!", 0xa, 0xa
	youlose2_len equ $-youlose2

	goodbye db "Goodbye.", 0xa
	goodbye_len equ $-goodbye

	_ok db "Exit OK. There were no errors.", 0xa, 0xa
	_ok_len equ $-_ok

section .bss

	userChoice resb 1
	randint resw 2
	downsize resw 2
	
	_itoabuf resb 1024

	inputbuf resb 1024
	inputbuf_len equ 1024
