; wczytywanie i wyœwietlanie tekstu wielkimi literami
; (inne znaki siê nie zmieniaj¹)

.686
.model flat
extern _ExitProcess@4 : PROC
extern _MessageBoxW@16 : PROC
extern __write : PROC 			; (dwa znaki podkreœlenia)
extern __read : PROC			; (dwa znaki podkreœlenia)
public _main

.data
tytul_Unicode	dw 'T','e','k','s','t',' ','w',' '
				dw 'f','o','r','m','a','c','i','e',' '
				dw 'U','T','F','-','1','6', 0		
tekst_pocz		db 10, 'Proszê napisaæ jakiœ tekst '
				db 'i nacisnac Enter', 10
koniec_t		db ?
buffor			db 80 dup (?)
answer			dw 80 dup (?)
nowa_linia		db 10
liczba_znakow	dd ?
buf_odwrocona_kolejnosc	db	80 dup (?)
buf_utf16		dw 80 dup (?), 0

pl_latin2		db 0a5h,086h,0a9h,088h,0e4h,0a2h,098h,0abh,0beh
				db 0a4h,08fh,0a8h,09dh,0e3h,0e0h,097h,08dh,0bdh
rozmiar_pl_latin2 = $ - pl_latin2


pl_utf_16		dw 0105H, 0107H, 0119H, 0142H, 0144H, 00F3H, 015BH, 017AH, 017CH
				dw 0104H, 0106H, 0118H, 0141H, 0143H, 00D3H, 015AH, 0179H, 017BH

liczba_slow		dw	0

.code
_main PROC

; wyœwietlenie tekstu informacyjnego

; liczba znaków tekstu
	mov ecx,(OFFSET koniec_t) - (OFFSET tekst_pocz)
	push ecx
	push OFFSET tekst_pocz									; adres tekstu
	push 1													; nr urz¹dzenia (tu: ekran - nr 1)
	call __write											; wyœwietlenie tekstu pocz¹tkowego
	add esp, 12												; usuniecie parametrów ze stosu

; czytanie wiersza z klawiatury
	push 80													; maksymalna liczba znaków
	push OFFSET buffor
	push 0													; nr urz¹dzenia (tu: klawiatura - nr 0)
	call __read												; czytanie znaków z klawiatury
	add esp, 12												; usuniecie parametrów ze stosu
; kody ASCII napisanego tekstu zosta³y wprowadzone
; do obszaru 'magazyn'

; funkcja read wpisuje do rejestru EAX liczbê
; wprowadzonych znaków (³¹cznie ze znakiem \n)
	mov liczba_znakow, eax
	SUB liczba_znakow, 1

	; spisanie pozycji pocz¹tków s³ów
	; 0 1 2 3 4 5 6 7 8 9 10
	; A l a   m a   k o t a
	mov ecx, liczba_znakow
	mov esi, 1		; przechowuje ostatni index
wrzucenie_na_stos_indeksow_poczatkow_slow:
	mov dl, buffor[esi-1]									; pobranie kolejnego znaku
	cmp dl, 20h
	jne sprawdz_czy_pierwsze_slowo

	PUSH esi
	inc liczba_slow
	jmp nie_jest_spacja

	sprawdz_czy_pierwsze_slowo:
		cmp esi, 1
		jne nie_jest_spacja
		PUSH 0				; PUSH esi
		inc liczba_slow

	nie_jest_spacja:
		inc esi
	loop wrzucenie_na_stos_indeksow_poczatkow_slow

	mov ECX, dword PTR liczba_slow
	mov EBX, liczba_znakow
	sub EBX, 1
	mov EDI, 0						; i
przepisanie_w_odwrotnej_kolejnosci:
	POP EDX							; stos; index pierwszego znaku nowego s³owa
	mov ESI, EDX
	przepisanie_slowa:
		MOV AL, buffor[ESI]							; przepisujemy do AL znak z buffora
		MOV buf_odwrocona_kolejnosc[EDI], AL		; do buffora z odwrócon¹ kolejnoœci¹ znaków w nowej kolejnoœci zapisujemy znak

		INC ESI
		INC EDI

		cmp ESI, EBX
		jna przepisanie_slowa

		mov buf_odwrocona_kolejnosc[EDI], 20h
		INC EDI
		SUB EDX, 2
		MOV EBX, EDX
	loop przepisanie_w_odwrotnej_kolejnosci

	; konwersja Latin2 -> UTF-16
	mov ECX, liczba_znakow
	mov ESI, 0
	mov EDI, 0
	mov bl, 0
	petla_konwersji:
		PUSH ECX			; przechowanie stanu
		mov AL, buf_odwrocona_kolejnosc[ESI]
		mov ECX, rozmiar_pl_latin2
		mov EDX, 0			; index tablicy polskich znaków
		znaki_diakrytyczne_petla_konwersji:
			mov AH, pl_latin2[EDX]
			cmp AH, AL
			JE zmien
			inc EDX
			loop znaki_diakrytyczne_petla_konwersji
			JMP zwykle_znaki_konwersja

			zmien:
				mov AX, pl_utf_16[EDX*2]
				mov buf_utf16[EDI], AX
				JMP skoncz_konwersje

		zwykle_znaki_konwersja:
			mov AL, buf_odwrocona_kolejnosc[ESI]
			mov AH, 00h
			mov buf_utf16[EDI], AX

		skoncz_konwersje:
				cmp AL, 20h
				JNE koncz_wasc_wstydu_oszczedz
				add EDI, 2
				cmp bl, 0
				JE dodaj_slonce

				mov buf_utf16[EDI], 0D83Ch
				add EDI, 2
				mov buf_utf16[EDI], 0DF11h
				mov bl, 0
				JMP dodaj_spacje

				dodaj_slonce:
					mov buf_utf16[EDI], 2600H
					mov bl, 1
					JMP dodaj_spacje

				dodaj_spacje:
					add EDI, 2
					mov buf_utf16[EDI], 20h
				koncz_wasc_wstydu_oszczedz:
			POP ECX
			add ESI, 1
			add EDI, 2

	SUB ECX, 1
	cmp ECX, 0
	JA petla_konwersji

	push 0
	push OFFSET tytul_Unicode
	push OFFSET buf_utf16
	push 0
	call _MessageBoxW@16

	push 0
	call _ExitProcess@4										; zakoñczenie programu
_main ENDP
END