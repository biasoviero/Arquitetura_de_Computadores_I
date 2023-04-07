; Beatriz Forneck Soviero
; Cartão 00342227

	.model small
	.stack
	
CR		equ		0dh
LF		equ		0ah

	.data
	
FileName			db	256 dup (?)			; Nome do arquivo a ser lido
FileBuffer			db	10 dup (?)			; Buffer de leitura do arquivo
FileHandle			dw	0					; Handler do arquivo

;;Flags que informam se os comandos foram chamados, 1 se sim, 0 se não
comandoV			db 0
comandoG			db 0
comandoA			db 0

MsgCRLF				db	CR, LF, 0
MsgErroOpenFile		db	"Erro na abertura do arquivo.", CR, LF, 0
MsgErroReadFile		db	"Erro na leitura do arquivo.", CR, LF, 0
MsgCodigoValido		db 	"Codigo corresponde ao codigo do arquivo.", CR, LF, 0
MsgCodigoInvalido	db 	"Codigo nao corresponde ao codigo do arquivo.", CR, LF, 0
MsgCalculado		db	"O codigo do arquivo eh: ", CR, LF, 0

;;Variáveis da sprintf_w
sw_n	dw	0
sw_f	db	0
sw_m	dw	0
String	db	10 dup (?)

comando				db 256 dup(?)			;Linha de comando lida
calculado			dw 4 dup(?) 			;Código do arquivo calculado

codigo				db 64 dup(?)			;Código de verificação informado

xString				db 64 dup(?)
x					dw 4 dup(0)				;Variável para o cálculo do Código VERSAO CERTA



	.code
	.startup
	
	call LinhaComando		;Salva a linha de comando na string comando
	
	call SplitComando		;Ignora os espaços e verifica quais flags foram ligadas
	
	cmp comandoA, 1			;Comando -a foi chamado?
	jne Main2
	call LeBytes			;Lê o arquivo
	
Main2:

	cmp comandoV, 1			;Comando -v foi chamado?
	jne Main3
	call ComparaCod			;Compara o código informado com o código calculado
	
Main3:


	.exit
	
;===================================================================
;Função LinhaComando
;Lê a linha de comando informada e a armazena na variável comando
;===================================================================

LinhaComando	proc near


	push 	ds							;Salva informações do segmento
	push 	es
	
	mov ax,ds 							;Troca DS <-> ES, para poder usa o MOVSB
	mov bx,es
	mov ds,bx
	mov es,ax
	
	mov si,80h 							;Obtém o tamanho do string e coloca em CX
	mov ch,0
	mov cl,[si]
	inc cl
	
	mov si,81h 							; inicializa o ponteiro de origem
	lea di,comando 						; inicializa o ponteiro de destino
										;comando <- linha de comando exceto o nome do programa
	rep movsb
	
	pop es 								; retorna as informações dos registradores de segmentos
	pop ds
	
	mov bx, ds							;Destroca DS <-> ES
	mov es, bx
	
	ret
	
LinhaComando endp


;==========================================================================================
;Função SplitComando
;Percorre a string comando, ignora os espaços e seta as flags para os comandos informados
;==========================================================================================

SplitComando proc near
	
	lea si, comando		;Lê a string comando

SplitLoop:

	lodsb				;Lê caractere
	
	cmp al, " "			;Encontrou espaço? Skip
	je SplitLoop
	
	cmp al, "-"			;Encontrou hifen? Skip
	je SplitLoop
	
	cmp al, "a"			;Verifica qual foi o comando chamado
	je Arq
	
	cmp al, "v"			
	je Cod
	
	cmp al, "g"
	je Calcula
	
FimSplit:
	ret
	
SplitComando endp

;========================================
;Comando -a
;Lê o nome do arquivo, seta a flag a
;========================================

Arq:
	lodsb
	lea di, FileName
	
	
ArqLoop:	
	lodsb					;Carrega o caractere
	cmp al, CR				;Verifica se chegou ao fim
	je LeuArq				
	cmp al, ' '				;Verifica se encontrou um espaço
	je LeuArq
	stosb					;Se não é CR nem espaço, armazena o caractere em FileName
	jmp ArqLoop
	
LeuArq:			
	mov al, 0				;Termina string com 0
	stosb
	dec si
	mov comandoA, 1			;Liga a flag
		
	jmp SplitLoop
	
;======================================================================
;Comando -v
;Lê o código informado e converte suas letras minúculas para maiúsculas
;======================================================================

Cod:
	mov comandoV, 1			;Liga a flag
	lodsb					;Lê o caractere
	lea di, codigo			;Aponta o destino para a variável codigo
	
CodLoop:	
	
	lodsb					;Carrega o caractere
	cmp al, CR				;Verifica se chegou ao fim
	je LeuCod				
	cmp al, ' '				;Verifica se encontrou um espaço
	je LeuCod
	cmp al, 'f'				;Verifica se letras minúsculas foram informadas
	jbe Minuscula
	
Save:
	stosb					;Se não é CR nem espaço, armazena o caractere em FileName
	jmp CodLoop
	
Minuscula:
	cmp al, "F"				;Converte minúsculas para maiúsculas
	jbe Save
	sub al, 32
	jmp Save
	
LeuCod:			
	mov al, 0				;Termina string com 0
	stosb
	dec si
	jmp SplitLoop
	
;========================================================================
;Comando -g
;Seta a flag g
;========================================================================
	
Calcula:
	mov comandoG, 1			;Liga a flag
	jmp SplitLoop

;========================================================================
;LeBytes
;Lê o arquivo FileName e calcula o seu código de verificação
;========================================================================

LeBytes proc near
				
		mov [x], 0					;Inicializa os 64 bits de x com 0
		mov [x + 2], 0
		mov [x + 4], 0
		mov [x + 6], 0
		
		;Abrir arquivo

		mov		al,0				;Abre o arquivo para leitura
		lea		dx,FileName			;Aponta DS para o FileName
		mov		ah,3dh				;Abre o arquivo
		int		21h
		
		jnc		Continua1			;Erro na abertura do arquivo
		lea		bx,MsgErroOpenFile
		call	printf_s
		jmp		Final
Continua1:

		mov		FileHandle,ax		;FileHandle = ax
		
		;Ler arquivo
		
ReadByte:
		mov 	bx, FileHandle
		mov		ah,3fh				;Lê do arquivo
		mov		cx,1				;Lê um byte
		lea 	dx, FileBuffer
		int		21h
		jnc		Continua2			;Erro na leitura do arquivo
		lea		bx,MsgErroReadFile
		call	printf_s
		mov		al,1
		jmp		CloseAndFinal

Continua2:	
		cmp		ax,0				;Terminou o arquivo?
		jne		Continua3
		mov al, 0
		jmp Display

Continua3:		
		xor bx, bx					;Limpa bx
		mov bl, FileBuffer			;Salva o byte lido em bl
		
		add [x], bx					;Add bx ao byte menos significativo de x
		adc [x + 2], 0 				;Add carry aos outros bytes de x
		adc [x + 4], 0
		adc [x + 6], 0
		
		jno ReadByte				;Se deu overflow então x assume seu valor máximo
		mov [x + 6], 0ffffh
		mov [x + 2], 0ffffh
		mov [x + 4], 0ffffh
		mov [x], 0ffffh
Display:		
		call SalvaCod				;Salva o código como uma string do número em hexadecimal
		cmp comandoG, 1				;Se g foi chamado, printa uma mensagem informando o código calculado
		jne CloseAndFinal			
		call PrintCod
					
CloseAndFinal:	
		mov bx, FileHandle			;Fecha o arquivo
		mov ah, 3eh
		int 21h
Final:			
		mov [si], 0					;Move 0 para o final de v
		ret

LeBytes endp

;=====================================================================
;Função PrintCod
;Exibe uma mensagem informando o código calculado
;=====================================================================

PrintCod proc near
		lea  bx,  MsgCalculado
		call printf_s			
		lea bx, xString
		call printf_s
		ret
PrintCod endp

;====================================================================
;Função SalvaCod
;Avalia quais bytes de x são diferentes de 0 e os converte para hexa
;====================================================================

SalvaCod proc near

		lea di, xString			;Aponta ponteiro para a fonte xString
		
		cmp [x + 6], 0			;Byte mais significativo de x é diferente de 0? Converte para string em hexa
		je Byte3
		mov ax, [x + 6]
		call ConverteHex
Byte3:
		cmp [x + 4], 0 			; 2° byte mais significativo de x é diferente de 0? Converte para string em hexa
		je Byte2
		mov ax, [x + 4]
		call ConverteHex
Byte2:
		cmp [x + 2], 0			;3° byte mais significativo de x é diferente de 0? Converte para string em hexa
		je Byte1
		mov ax, [x + 2]
		call ConverteHex
		
Byte1:
		mov ax, [x]				;Converte x para hexa
		call ConverteHex
			
		ret

SalvaCod endp

;============================================================================
;Função ConverteHex
;Converte um número inteiro para string que corresponde ao seu valor em hexa
;Recebe número a ser convertido em ax e armazena a string no ponteiro em DI
;============================================================================

ConverteHex proc near
		mov cx, 0				;CX = 0, DX = 0
		mov dx, 0
Printa1:
		cmp ax, 0				;Resto == 0? Termina
		je Printa2
		mov bx, 16				;Converte para hexa pelo método das divisões
		div bx
		push dx
		inc cx					;Incrementa contador
		xor dx, dx
		jmp Printa1
Printa2:
		cmp cx, 0				;Contador chegou ao fim? Termina
		je PrintaFim
		pop dx
		cmp dx, 9				;Verifica se o dígito é um número
		jle Printa3
		add dx, 7				;Se for letra, soma 7 
Printa3:
		add dx, 48				;Soma 48 para converter para código ASCII
		mov al, dl
		stosb					;Armazena em DI
		dec cx
		jmp Printa2
PrintaFim:
		cmp ax, [x]				;Se o número a ser convertido for o menos significativo de x, armazena um 0 na string para terminá-la
		jne Retorna
		mov al, 0
		stosb
Retorna:
		ret
ConverteHex endp

;======================================================
;Função ComparaCod
;Compara o código informado com o código calculado
;======================================================

ComparaCod proc near

		lea si, xString			;Aponta a fonte para a string com o código calculado
		lea di, codigo			;Aponta o destino para a string com o código informado
		mov cx, 8				;Informa que são 8 bits
		repe cmpsb				;Compara as duas strings
		
		jne Invalido			;Caso que é válido
		lea bx, MsgCodigoValido
		call printf_s
		lea bx, MsgCRLF
		call printf_s
		jmp ComparaFim
Invalido:
								;Caso em que é inválido
		lea bx, MsgCodigoInvalido
		call printf_s
		lea bx, MsgCRLF
		call printf_s
		call PrintCod

ComparaFim:			
		ret

ComparaCod endp

;--------------------------------------------------------------------
;Função: Escrever um string na tela
;
;void printf_s(char *s -> BX) {
;	While (*s!='\0') {
;		putchar(*s)
; 		++s;
;	}
;}
;--------------------------------------------------------------------
printf_s	proc	near


;	While (*s!='\0') {
	mov		dl,[bx]
	cmp		dl,0
	je		ps_1

;		putchar(*s)
	push	bx
	mov		ah,2
	int		21H
	pop		bx

;		++s;
	inc		bx
		
;	}
	jmp		printf_s
		
ps_1:
	ret
	
printf_s	endp

;========================================================================
;Função: Converte um inteiro (n) para (string)
;		 sprintf(string, "%d", n)
;========================================================================

sprintf_w	proc	near

;void sprintf_w(char *string, WORD n) {
	mov		sw_n,ax

;	k=5;
	mov		cx,5
	
;	m=10000;
	mov		sw_m,10000
	
;	f=0;
	mov		sw_f,0
	
;	do {
sw_do:

;		quociente = n / m : resto = n % m;	// Usar instrução DIV
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
;		if (quociente || f) {
;			*string++ = quociente+'0'
;			f = 1;
;		}
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
;		n = resto;
	mov		sw_n,dx
	
;		m = m/10;
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
;		--k;
	dec		cx
	
;	} while(k);
	cmp		cx,0
	jnz		sw_do

;	if (!f)
;		*string++ = '0';
	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:


;	*string = '\0';
	mov		byte ptr[bx],0
		
;}
	ret
		
sprintf_w	endp


;--------------------------------------------------------------------
;Função:Converte um ASCII-DECIMAL para HEXA
;Entra: (S) -> DS:BX -> Ponteiro para o string de origem
;Sai:	(A) -> AX -> Valor "Hex" resultante
;Algoritmo:
;	A = 0;
;	while (*S!='\0') {
;		A = 10 * A + (*S - '0')
;		++S;
;	}
;	return
;--------------------------------------------------------------------


atoi	proc near

		; A = 0;
		mov		ax,0
		
atoi_2:
		; while (*S!='\0') {
		cmp		byte ptr[bx], 0
		jz		atoi_1

		; 	A = 10 * A
		mov		cx,10
		mul		cx

		; 	A = A + *S
		mov		ch,0
		mov		cl,[bx]
		add		ax,cx

		; 	A = A - '0'
		sub		ax,'0'

		; 	++S
		inc		bx
		
		;}
		jmp		atoi_2

atoi_1:
		; return
		ret

atoi	endp

;--------------------------------------------------------------------
		end
;--------------------------------------------------------------------
