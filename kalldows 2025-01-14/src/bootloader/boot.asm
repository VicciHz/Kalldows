org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT 12 header
;
jmp short start
nop

bdb_oem: 				 	db 'MSWIN4.1' ; 8 bytes
bdb_bytes_per_sector:    	dw 512
bdb_sectors_per_cluster: 	db 1
bdb_reserved_sectors: 	 	dw 1
bdb_fat_count: 			 	db 2
bdb_dir_entries_count    	dw 0E0h
bdb_total_sectors: 		 	dw 2880 	   			; 2880 * 512 = 1.44mb
bdb_media_descriptor_type:  db 0F0H		   			; F0 = 3.5" floppy disk
bdb_sectors_per_fat: 		dw 9		   			; 9 sectors/fat
bdb_sectors_per_track: 		dw 18
bdb_heads: 					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; extended boot record
ebr_drive_number:			db 0					; 0x00 floppy, 0x80 hdd
							db 0					; reserved
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 23h, 56h, 78h	; serial number
ebr_volume_label:			db 'NANOBYTE OS'		; 11 bytes
ebr_system_id:				db 'FAT12   '			; 8 bytes

;
; Code goes here
;


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

	; read something from floppy disk
	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl

	mov ax, 1							; LBA=1, second sector from disk
	mov cl, 1							; 1 sector to read
	mov bx, 0x7E00						; data should be after the bootloader
	call disk_read			

	; print message
	mov si, msg_welcome
	call puts
	mov si, msg_cont
	call puts
	
	cli							; disable interuppts, this way CPU cant get out of "halt" state
	hlt

;
; Error handlers
;
floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h								; wait for keypress
	jmp 0FFFFh:0						; jump to begining of BIOS, should reboot

.halt:
	cli							; disable interuppts, this way CPU cant get out of "halt" state
	hlt

;
; Disk routines 
;

;
; Converts an LBA address to a CHS address
; parameters:
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder
;	- dh: head
;

lba_to_chs:
	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack

	inc dx								; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										;dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl							; dl = head
	mov ch, al							; ch = cylinder (lowe 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in cl

	pop ax
	mov dl, al							; restore dl
	pop ax
	ret

;
; Reads sectors from a disk
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- es: bx: memory address wherwe to store read data
;
disk_read: 
	push ax								; save registors we will modify
	push bx
	push cx
	push dx
	push di

	push cx								; temporarily save cl (number of sectors to rad)
	call lba_to_chs						; compute chs
	pop ax								; al = number of sectors to read

	mov ah, 02h
	mov di, 3							; retry count

.retry:
	pusha								; save all registers, we dont know what bios modifies
	stc									; set carry flag, some bios dont set it
	int 13h								; carry flag cleared = success
	jnc .done							; jump if carry not set

	; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; all attempts are exhausted
	jmp floppy_error

.done:
	popa

	pop di								
	pop dx
	pop cx
	pop bx
	pop ax								; restore registors modified

	mov si, msg_disk_read
	call puts

	ret

;
; Resets disk controller
; Parameters:
;	dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_welcome: db 'Welcome to Kalldows!', ENDL, 0
msg_cont: db 'This operating system was created by Vicci', ENDL, 'Its only purpose is to prove to Kalle that assembly is the best language ever made', ENDL, 0

; success
msg_disk_read: db 'Disc read status: [OK]', ENDL, 0

; fail
msg_read_failed db 'Disc read status: [FAILED]', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
