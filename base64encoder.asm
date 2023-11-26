; Executable name	: base64encoder
; Version		: 1.1
; Created date		: 17.11.2023
; Author		: Kenny Wolf
; Description		: A program which converts binary data into base64 encoding

SECTION .data           	; Section containing initialised data
 
    Base64Table:        db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    OutBuf:				db "xxxx"
	OutBufLen:			equ $-OutBuf

SECTION .bss            	; Section containing uninitialized data

    InBufLen:			equ 3
	InBuf:				resb InBufLen
 
SECTION .text           	; Section containing code
 
global _start			; Linker needs this to find the entry point!
 
_start:

read:
		; Read chunk from stdin to InBuf
		mov rax, 0					; sys_read
		mov rdi, 0					; File descriptor stdin
		mov rsi, InBuf				; Destination buffer
		mov rdx, InBufLen			; Maximum # of bytes to read
		syscall

		; Check number of bytes read
		cmp rax, 0					; Any bytes received?
		je exit						; If not, exit the program

		xor r10, r10				; Clear r10
		mov r10, rax				; Save # of bytes read

		cmp rax, 2					; Call subroutine if two bytes read
		je twobyte

		cmp rax, 1
		je onebyte

		; Clear r10, r11 and rax
		xor r10, r10
		xor r11, r11
		xor rax, rax

process:
		mov eax, [InBuf]

		; Convert little endian to big endian and shifting right by 8 to remove 0x00
		; which we only got because we saved a 24 bit value into a 32 bit register
		bswap eax					; Swap
		shr eax, 8					; Shift by 8

		; Clean rdx, rbx
		xor rdx, rdx
		xor rbx, rbx
		mov edx, eax				; Copy eax in edx

		; Get second char in 3 byte data
		shr edx, 6					; Move first char away
		and edx, 0x3F				; Mask third and fourth char
		mov bl, [Base64Table+rdx]	; Lookup and add to ebx on fourth place
		xor rdx, rdx				; Clear rdx
		mov edx, eax				; Copy eax to edx

		and edx, 0x3F				; Get first char with masking
		mov bh, [Base64Table+rdx]	; Lookup and add to ebx on the trhid place
		xor rdx, rdx				; Clear rdx
		mov edx, eax

		shl ebx, 16					; Move third and fourth place of ebx to first and second

		shr edx, 18					; Move first, second and third char out of edx
		mov bl, [Base64Table+rdx]	; Lookup remaining fourth char and add to ebx
		xor rdx, rdx				; Clear rdx
		mov edx, eax

		shr edx, 12					; Move first and second char away from edx
		and edx, 0x3F				; Mask fourth char
		mov bh, [Base64Table+rdx]	; Lookup remaining third char and add to place
		mov [OutBuf+r11], ebx		; Move content of ebx to output
		push r11					; Save r11 to stack
		push r10					; Save r10 to stack
		call write					; Write output
		pop r10						; Pop r10 from stack
		pop r11						; Pop r11 from stack

		add r11, 4					; Add 4 to output index
		cmp r11, r10				; Check if all data read was processed
		jl process					; If r11 is lower, go to process
		jmp read					; Else read new data

onebyte:
		; Clear registers
		xor rdx, rdx
		xor rbx, rbx
		xor rax, rax

		; Add two == and move them up 16 to make space for last two chars
		mov bh, 0x3D
		mov bl, 0x3D
		shl ebx, 16

		mov eax, [InBuf]
		and eax, 0xFF				; Mask all other bytes except last one
		shl eax, 4					; Add 0000 at the end
		mov edx, eax
		shr edx, 6					; Move first char ouf of edx
		and edx, 0x3F				; Mask everything except second 6 bits
		mov bl, [Base64Table+rdx]	; Lookup and write to bh
		xor rdx, rdx
		mov edx, eax

		and edx, 0x3F				; Mask second char
		mov bh, [Base64Table+rdx]	; Lookup first char

		; Write and exit program
		mov [OutBuf], ebx
		call write
		jmp exit

twobyte:
		; Clear registers
		xor rdx, rdx
		xor rbx, rbx
		xor rax, rax

		mov eax, [InBuf]
		and eax, 0xFFFF				; Mask all other bytes except last two
		bswap eax
		shr eax, 16					; bswap ax doesn't work so need to do it manually
		shl eax, 2					; Add 00 at the end

		; Add one =
		mov bh, 0x3D
		mov edx, eax

		and edx, 0x3F
		mov bl, [Base64Table+rdx]
		xor rdx, rdx
		mov edx, eax

		shl ebx, 16
		shr edx, 6
		and edx, 0x3F
		mov bh, [Base64Table+rdx]
		xor rdx, rdx
		mov edx, eax

		shr edx, 12
		and edx, 0x3F
		mov bl, [Base64Table+rdx]

		; Write and exit program
		mov [OutBuf], ebx
		call write
		jmp exit

write:
		mov rax, 1
		mov rdi, 1
		mov rsi, OutBuf
		mov rdx, OutBufLen
		syscall
		ret

exit:
		mov rdi, 0
		mov rax, 60
		syscall
