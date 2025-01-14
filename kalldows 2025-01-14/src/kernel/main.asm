org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

; prints a string to the screen
puts:
	;save registers we will modyfy
	push si
	push ax

.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0e
	mov bh, 0
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret
	
main:
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00

	; print message
	mov si, msg_welcome
	call puts

	mov si, msg_cont
	call puts
	
	hlt

.halt:
	jmp .halt

msg_welcome: db 'Welcome to Kalldows!', ENDL, 0
msg_cont: db 'This operating system was created by Vicci', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
