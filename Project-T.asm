/*
 * Project_T.asm
 *
 *  Created: 18.02.2015 0:11:13
 *   Author: Lax-T
 */ 

 .INCLUDE "m64adef.inc"


.def	TMP	= R16
.def	reg1 = r17
.def	reg2 = r18
.def	reg3 = r19
.def	reg4 = r20
.def	reg5 = r21
.def	reg6 = r22
.def	reg7 = r23
.def	reg8 = r24
.def	lcdbuf = r25
						;1 é ðåã³ñòð ïîìèëîê
.def	gereg1 = r5		;0 - DS18B20 ïîìèëêà CRC, 1 - DS18B20 íåìà â³äïîâ³ä³ â³ä äàò÷èêà
						;2 - DS18B20 ÊÇ ë³í³¿ äàò÷èêà, 3 - (1) äàí³ ä³éñí³ (áåç äàíîãî á³òó ïðîãðàìè ³ãíîðóþòü òåìïåðàòóðó)
						;4 - ïîìèëêà çâÿçêó ç ååïðîì, 5 - ïîìèëêà çàïèñó ååïðîì, 6 - ðîçðÿä áàòàðå¿ RTC
						;7 - ãîòîâí³òü ñèñòåìè äî ðîáîòè ï³ñëÿ çàïóñêó/ïåðåçàïóñêó
.equ	dscrce = 0
.equ	dscome = 1		
.equ	dspwdn = 2
.equ	dsdtv = 3
.equ	eecerr = 4
.equ	eewerr = 5
.equ	rtcerr = 6
.equ	sysrdy = 7
						;2 é ðåã³ñòð ïîìèëîê ()
.def	gereg2 = r8

.equ	triacer = 0		;0 - íåñïðàâí³ñòü ñèì³ñòîðà
.equ	fanproter = 1	;1 - íåñïðàâí³ñòü êîëà çàõèñòó âåíòèëÿòîðà (çàïîá³æíèê/ïåðåãð³â êîòëà)
.equ	tfaller = 6		;6 - ïîïåðåäæåííÿ ïðî ïàä³ííÿ òåìïåðàòóðè
.equ	triseer = 7		;7 - àâàð³éíèé ð³ñò òåìïåðàòóðè

						;ðåã³ñòð ïîä³é
.def	eventreg = r9

.equ	tfrrestore = 0	;ïðàïîðåöü â³äíîâëåííÿ ðîñòó/ïàä³ííÿ òåìïåðàòóðè
.equ	erractive = 1	;íà äàíèé ìîìåíò º àêòèâíà íåñïðàâí³ñòü/ïîïåðåäæåííÿ (âèçíà÷àº òî÷êó ïåðåõîäó êíîïîê ÎÊ ³ I+)
.equ	gmodwork = 2	;ïåðåõ³ä â ðåæèì ðîçïàëó êîòëà
.equ	gmodstby = 3	;ïåðåõ³ä â ðåæèì ãàñ³ííÿ êîòëà
.equ	passlock = 4	;áëîêóâàííÿ ï³äáîðó ïàðîëÿ
.equ	logclear = 5	;î÷èùåííÿ ëîãó òåìïåðàòóðè
.equ	poweron = 6		;ñòàðò ïðèëàäó

.def	toutreg = r6	;Ïðàïîðö³ ïåðåðèâàíü ñëîò³â ïî òàéìàóòó
.equ	slot1tint = 0
.equ	slot2tint = 1
.equ	slot3tint = 2
.equ	slot4tint = 3
.equ	slot5tint = 4
.equ	slot6tint = 5
.equ	slot7tint = 6
.equ	slot8tint = 7

.def	toutreg2 = r7	;Ïðàïîðö³ ïåðåðèâàíü ñëîò³â ïî òàéìàóòó 2
.equ	slot9tint = 0
.equ	slot10tint = 1
.equ	slot11tint = 2
.equ	slot12tint = 3
.equ	slot13tint = 4
.equ	slot14tint = 5
.equ	slot15tint = 6
.equ	slot16tint = 7

.equ	fasttime = 255-111 ;
.equ	tiktime = 65536-12500 ;



		.CSEG
        .ORG $000        ; (RESET Vector) 
		JMP   Reset
		.ORG $00E		 ; External Interrupt Request 6
		JMP Powerdnint
		.ORG $012        ; (timer2 Comp match Int Vector) 
		JMP   Fpdimm
		.ORG $014        ; (timer2 Ovf Int Vector) 
		JMP   Fasttimer	
		.ORG $01C		 ; Timer/Counter1 Overflow
		JMP  tiktimer		

reset:	ldi tmp, low(ramend)
		out spl, tmp
		ldi tmp, high(ramend)
		out sph, tmp

		ldi tmp, 0b01111111
		out ddra, tmp
		ldi tmp, 0b00010101
		out porta, tmp

		ldi tmp, 0b10010101
		out ddrb, tmp
		ldi tmp, 0b00000000
		out portb, tmp
				
		ldi tmp, 0b00001111
		out ddrc, tmp
		ldi tmp, 0b00000000
		out portc, tmp

		ldi tmp, 0b11001000
		out ddrd, tmp
		ldi tmp, 0b10001000
		out portd, tmp

		ldi tmp, 0b10100000
		out ddre, tmp
		ldi tmp, 0b00000000
		out porte, tmp	
		
		ldi tmp, 0b00000011
		sts ddrg, tmp
		ldi tmp, 0b00000000
		sts portg, tmp	
		
									;êîíô³ãóðàö³éí³ êîíñòàíòè
	
	;	ldi tmp, 0
	;	mov gereg1, tmp			;êîíô³ãóðàö³ÿ ðåã³ñòðà ïîìèëîê
	;	mov gereg2, tmp			;êîíô³ãóðàö³ÿ ðåã³ñòðà ïîìèëîê 2
	;	mov eventreg, tmp		;êîíô³ãóðàö³ÿ ðåã³ñòðà ïîä³é
	;	ldi tmp, 0
	;	sts lcdsit, tmp	
	;;	ldi tmp, 0
	;	sts menusit, tmp
		ldi tmp, 0				;êîíô³ãóðàö³ÿ ïðîãðàìè êîíòðîëþ çàïóñêó
		sts powerupstep, tmp
		sts powerupcount, tmp
		sts powerupevent, tmp		
		call starttik ;ñòàðò ñèñòåìíîãî òàéìåðà
		sei

		ldi tmp, 2 ;÷åðåç 200ìñ âèêëèê ï³äïðîãðàìè çàïóñêó
		sts slotr2, tmp

	;	call searchle	
	;	call searchll		
	;	call readsett				
								;ñòàðò ïðîöåñ³â
	;	call fasttmstart
	;	call startkey
	;	call startdind
	;	call beepstart
	;	call startdscomm
	;	call i2cstart	
	;	call lcdblon
	;	call lcdbias_startpwm
	;	call startlcd	
	;	call starttik	
	;;	call startpass
	;	call startfpcont
		;	
					
	;	ldi tmp, 10;çàïóñê ãðóïè ñåêóíäíèõ ôóíêö³é
	;	sts slotr12, tmp		

	;	ldi tmp, 6;çàïóñê ãðóïè ôóíêö³é óïðàâë³ííÿ ïåðåäíüîþ ïàíåëëþ/äèñïëåºì
	;	sts slotr11, tmp		

	;	ldi tmp, 5;çàïóñê ï³äïðîãðàìè óïðàâë³ííÿ íàñîñîì
	;	sts slotr7, tmp

	;	ldi tmp, 10;çàïóñê ï³äïðîãðàìè óïðàâë³ííÿ âåíòèëÿòîðîì
	;	sts slotr6, tmp

	;	ldi tmp, 7;çàïóñê ï³äïðîãðàìè êîíòðîëþ ïîðîã³â
	;	sts slotr8, tmp

	;	ldi tmp, 12;çàïóñê ï³äïðîãðàìè çàïèñó ëîãó ïîä³é
	;	sts slotr10, tmp
			
;_________________________________________________ SYSDISP ______________________________________________________________
								;Äèñïåò÷åð âèêîíàííÿ îñíîâíîãî öèêëó
sysdisp:bst toutreg, slot1tint	;ñëîò 1	
		brts sysdisp1_1
		rjmp sysdisp2
sysdisp1_1:rcall slot1
		clt
		bld toutreg, slot1tint
		rjmp sysdisp
sysdisp2:bst toutreg, slot2tint	;ñëîò 2
		brts sysdisp21
		rjmp sysdisp3
sysdisp21:rcall slot2
		clt
		bld toutreg, slot2tint
		rjmp sysdisp		
sysdisp3:bst toutreg, slot3tint	;ñëîò 3
		brts sysdisp31
		bst gereg1, sysrdy ;ÿêùî íå âñòàíîâëåíî ïðàïîðåöü ãîòîâíîñò³ ñèñòåìè âèêîíóþòüñÿ ò³ëüêè ïåðø³ 3 ñëîòè
		brtc sysdisp
		rjmp sysdisp4
sysdisp31:rcall slot3
		clt
		bld toutreg, slot3tint
		rjmp sysdisp		
sysdisp4:bst toutreg, slot4tint	;ñëîò 4
		brts sysdisp41
		rjmp sysdisp5
sysdisp41:rcall slot4
		clt
		bld toutreg, slot4tint
		rjmp sysdisp		
sysdisp5:bst toutreg, slot5tint	;ñëîò 5		ìåíþ
		brts sysdisp51
		lds tmp, key
		cpi tmp, 0
		breq sysdisp6
		cpi tmp, 100
		brlo sysdisp51
		rjmp sysdisp6
sysdisp51:rcall slot5
		clt
		bld toutreg, slot5tint
		rjmp sysdisp		
sysdisp6:bst toutreg, slot6tint	;ñëîò 6
		brts sysdisp61
		rjmp sysdisp7
sysdisp61:rcall slot6
		clt
		bld toutreg, slot6tint
		rjmp sysdisp		
sysdisp7:bst toutreg, slot7tint	;ñëîò 7
		brts sysdisp71
		rjmp sysdisp8
sysdisp71:rcall slot7
		clt
		bld toutreg, slot7tint
		rjmp sysdisp		
sysdisp8:bst toutreg, slot8tint	;ñëîò 8
		brts sysdisp81
		rjmp sysdisp9
sysdisp81:rcall slot8
		clt
		bld toutreg, slot8tint
		rjmp sysdisp

sysdisp9:bst toutreg2, slot9tint	;ñëîò 9
		brts sysdisp91
		rjmp sysdisp10
sysdisp91:rcall slot9
		clt
		bld toutreg2, slot9tint
		rjmp sysdisp

sysdisp10:bst toutreg2, slot10tint	;ñëîò 10
		brts sysdisp101
		rjmp sysdisp11
sysdisp101:rcall slot10
		clt
		bld toutreg2, slot10tint
		rjmp sysdisp

sysdisp11:bst toutreg2, slot11tint	;ñëîò 11
		brts sysdisp111
		rjmp sysdisp12
sysdisp111:rcall slot11
		clt
		bld toutreg2, slot11tint
		rjmp sysdisp

sysdisp12:bst toutreg2, slot12tint	;ñëîò 12
		brts sysdisp121
		rjmp sysdisp
sysdisp121:rcall slot12
		clt
		bld toutreg2, slot12tint
		rjmp sysdisp
		
.INCLUDE "main.inc"
.INCLUDE "menu.inc"
.INCLUDE "lcd.inc"

;_________________________________________ ïåðåðèâàííÿ ïðîïàæ³ æèâëåííÿ ___________________________________________________________________________

powerdnint:push tmp		
		call stoplcd	;íåãàéíå â³äêëþ÷åííÿ ñïîæèâà÷³â
		call lcdbloff
		call stopdind
		call beepstop	
		call stopdscomm
		set
		bld toutreg, slot3tint	;âñòàíîâëåííÿ ïðàïîðöÿ äëÿ âèêëèêó ï³äðîãðàìè çàâåðøåííÿ â³äêëþ÷åííÿ
		ldi tmp, 0b00000000
		out eimsk, tmp
		pop tmp
		reti

fpowerdnintst:ldi tmp, 0b00110000 ;äîçâ³ë ïåðåðèâàíü
		out eicrb, tmp
		ldi tmp, 0b01000000
		out eifr, tmp
		ldi tmp, 0b01000000
		out eimsk, tmp
		ret
		
.equ	powerdncount = $263
;_________________________________________________ SYSTIK ______________________________________________________________

tiktimer:push tmp			;Ïåðåðèâàííÿ òàéìåðà 1
		in tmp, sreg
		push tmp
		push reg1
		push reg2		
		push xh
		push xl		
		push zh
		push zl
		ldi tmp, high(tiktime)
		out tcnt1h, tmp
		ldi tmp, low(tiktime)
		out tcnt1l, tmp
		ldi xh, high(slotr1) ; Äèñïåò÷åð ÷àñîâèõ ³íòåðâàë³â
		ldi xl, low(slotr1)
		ldi reg1, 0
tiktim2:ld reg2, x
		cpi reg2, 0
		breq tiktim1
		dec reg2
		cpi reg2, 0
		breq tiktim3
		rjmp tiktim1
tiktim3:ldi zh, high(tiktimxx) ; ïî÷àòêîâèé àäðåñ ì³òêè ìíîæèòüñÿ íà íîìåð ñëîòà ³ îòðèìóºòüñÿ àäðåñ
		ldi zl, low(tiktimxx)	;ïîòð³áíî¿ ³íñòðóêö³¿ BLD (âñòàíîâëåííÿ ïîòð³áíîãî á³òà ïåðåðèâàííÿ)
		mov tmp, reg1		
		lsl tmp		
		add zl, tmp
		clr tmp
		adc zh, tmp	
		set
		ijmp
tiktimxx:bld toutreg, slot1tint
		rjmp tiktim1
		bld toutreg, slot2tint
		rjmp tiktim1
		bld toutreg, slot3tint
		rjmp tiktim1
		bld toutreg, slot4tint
		rjmp tiktim1
		bld toutreg, slot5tint
		rjmp tiktim1
		bld toutreg, slot6tint
		rjmp tiktim1
		bld toutreg, slot7tint
		rjmp tiktim1
		bld toutreg, slot8tint
		rjmp tiktim1
		bld toutreg2, slot9tint
		rjmp tiktim1
		bld toutreg2, slot10tint
		rjmp tiktim1
		bld toutreg2, slot11tint
		rjmp tiktim1
		bld toutreg2, slot12tint
		rjmp tiktim1
		bld toutreg2, slot13tint
		rjmp tiktim1
		bld toutreg2, slot14tint
		rjmp tiktim1
		bld toutreg2, slot15tint
		rjmp tiktim1
		bld toutreg2, slot16tint
		rjmp tiktim1
tiktim1:st x+, reg2
		inc reg1
		cpi reg1, 16
		brne tiktim2
		pop zl
		pop zh
		pop xl
		pop xh		
		pop reg2
		pop reg1
		pop tmp
		out sreg, tmp
		pop tmp
		reti

starttik:push reg1	;çàïóñê ñèñòåìíîãî òàéìåðà
		push zl
		push zh
		ldi tmp, high(tiktime)
		out tcnt1h, tmp
		ldi tmp, low(tiktime)
		out tcnt1l, tmp
		ldi tmp, 0b00000011
		out tccr1b, tmp
		in tmp, timsk
		ori tmp, 0b00000100
		out timsk, tmp
		ldi reg1, 0
		ldi tmp, 0
		mov toutreg, tmp
		mov toutreg2, tmp
		ldi zh, high(slotr1)
		ldi zl, low(slotr1)
starttik1:st z+, tmp
		inc reg1
		cpi reg1, 16
		brne starttik1
		pop zh
		pop zl
		pop reg1
		ret

.equ	slotr1 = $210
.equ	slotr2 = $211
.equ	slotr3 = $212
.equ	slotr4 = $213
.equ	slotr5 = $214
.equ	slotr6 = $215
.equ	slotr7 = $216
.equ	slotr8 = $217
.equ	slotr9 = $218
.equ	slotr10 = $219
.equ	slotr11 = $21a
.equ	slotr12 = $21b
.equ	slotr13 = $21c
.equ	slotr14 = $21d
.equ	slotr15 = $21e
.equ	slotr16 = $21f
;_________________________________________________ Memory manager ____________________________________________________________________________
readsett:push reg1	;çàâàíòàæåííÿ íàëàøòóâàíü ç ïìÿò³
		push zl
		push zh
		ldi zh, high(fantoff)
		ldi zl, low(fantoff)
		ldi tmp, 0
		sts wordadrh, tmp
		ldi reg1, eefantoffadr
readsett2:sts wordadrl, reg1
		call eeread
		lds tmp, i2cdata
		st z+, tmp
		cpi reg1, eepassmodadr
		brsh readsett1
		inc reg1
		rjmp readsett2
readsett1:lds tmp, soundmod;â ÿêîñò³ âèêëþ÷åííÿ ïåðåíîñ á³òó âèêë. çâóêó â ñïåö ðåã³ñòð BEEPFREG
		com tmp;³íâåðñ³ÿ á³òà
		bst tmp, 0
		lds tmp, beepfreg
		bld tmp, 0
		sts beepfreg, tmp
		pop zh
		pop zl
		pop reg1
		ret

clearevent:push reg1		;ï³äïðîãðàìà î÷èùåííÿ ïàìÿò³ ïîä³é
		push reg2
		push reg3
		push reg4
		push r0
		push r1
		ldi tmp, 0		;çáåðåæåííÿ â ååïðîì íîìåðà îñòàííüî¿ êîì³ðêè ñòàðîãî öèêëó
		sts wordadrh, tmp ;öÿ êîì³ðêà áóäå ñòàðòîâîþ äëÿ íîâîãî öèêëó (ç íå¿ ïðîãðàìà ïðè ñòàðò³ ïî÷èíàº ñêàíóâàííÿ)
		ldi tmp, eelastevenuml
		sts wordadrl, tmp
		lds tmp, lastevnuml
		sts i2cdata, tmp
		call eewrite
		ldi tmp, eelastevenumh
		sts wordadrl, tmp
		lds tmp, lastevnumh
		sts i2cdata, tmp
		call eewrite
		lds tmp, timeyear	;ï³äãîòîâêà äàííèõ ïåðøî¿ ïîä³¿
		sts memdata5, tmp
		lds tmp, timemonth
		sts memdata4, tmp
		lds tmp, timedate
		sts memdata3, tmp
		lds tmp, timemin
		sts memdata2, tmp
		lds tmp, timehour
		sts memdata1, tmp
		ldi tmp, 6		;êîä ïîä³¿
		sts memdata6, tmp
		lds reg1, lastevckll	;öèêë³÷íèé íîìåð ñòàðîãî ëîãó ³íêðåìåíòàâàíèé íà 3 áóäå ïî÷àòêîâèì äëÿ íîâîãî
		lds reg2, lastevcklh
		ldi tmp, 3
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		sts memdata8, reg2
		sts memdata9, reg1
		sts lastevckll, reg1
		sts lastevcklh, reg2
		lds reg1, lastevnuml
		lds reg2, lastevnumh
		ldi reg4, 0		;ë³÷èëüíèê çàïèñàíèõ ñëîò³â - áóäå çàïèñàíî 2 ñëîòè ç îäíàêîâèìè äàííèìè ³ öèêë³÷íèì íîìåðîì
clearevent4:ldi tmp, 9		;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 9 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp					
		ldi reg3, 0		;ë³÷èëüíèê çàïèñàíèõ áàéò³â
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)				
clearevent2:sts wordadrl, reg1	;çàïèñ â ïàìÿòü 9 áàéò³â, ùîá ñôîðìóâàòè 1é ñëîò íîâîãî öèêëó ³ çàïèñàòè ïîä³þ ñòèðàííÿ
		sts wordadrh, reg2
		ld tmp, z+
		sts i2cdata, tmp
		rcall eewrite
		inc reg3
		cpi reg3, 9
		brsh clearevent3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp clearevent2
clearevent3:inc reg4
		cpi reg4, 2
		brsh clearevent5
		lds reg1, lastevnuml	;³íêðåìåíò íîìåðà ñëîòà ³ ïîâòîðíèé çàïèñ òèõ ñàìèõ äàííèõ (â ðàì çàëèøàºòüñÿ ñòàðèé íîìåð)
		lds reg2, lastevnumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp clearevent4
clearevent5:pop r1
		pop r0
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret
				
clearlog:push reg1		;ï³äïðîãðàìà î÷èùåííÿ ëîãó òåìïåðàòóðè
		push reg2
		push reg3
		push reg4
		push r0
		push r1
		ldi tmp, 0		;çáåðåæåííÿ â ååïðîì íîìåðà îñòàííüî¿ êîì³ðêè ñòàðîãî öèêëó
		sts wordadrh, tmp ;öÿ êîì³ðêà áóäå ñòàðòîâîþ äëÿ íîâîãî öèêëó (ç íå¿ ïðîãðàìà ïðè ñòàðò³ ïî÷èíàº ñêàíóâàííÿ)
		ldi tmp, eelastlognuml
		sts wordadrl, tmp
		lds tmp, lastlognuml
		sts i2cdata, tmp
		call eewrite
		ldi tmp, eelastlognumh
		sts wordadrl, tmp
		lds tmp, lastlognumh
		sts i2cdata, tmp
		call eewrite
		lds tmp, timeyear	;ï³äãîòîâêà äàííèõ ïåðøî¿ ïîä³¿
		sts memdata4, tmp
		lds tmp, timemonth
		sts memdata3, tmp
		lds tmp, timedate
		sts memdata2, tmp		
		lds tmp, timehour
		sts memdata1, tmp
		bst gereg1, dsdtv
		brts clearlog01
		ldi tmp, $ff
		rjmp clearlog02
clearlog01:lds tmp, tempuni
clearlog02:sts memdata5, tmp ;òåìåðàòóðà, ÿêùî íåäîñòóïíî òî FF (-)
		lds reg1, lastlogckll	;öèêë³÷íèé íîìåð ñòàðîãî ëîãó ³íêðåìåíòàâàíèé íà 3 áóäå ïî÷àòêîâèì äëÿ íîâîãî
		lds reg2, lastlogcklh
		ldi tmp, 3
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		sts memdata6, reg2
		sts memdata7, reg1
		sts lastlogckll, reg1
		sts lastlogcklh, reg2
		lds reg1, lastlognuml
		lds reg2, lastlognumh
		ldi reg4, 0		;ë³÷èëüíèê çàïèñàíèõ ñëîò³â - áóäå çàïèñàíî 2 ñëîòè ç îäíàêîâèìè äàííèìè ³ öèêë³÷íèì íîìåðîì
clearlog4:ldi tmp, 7	;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 7 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp					
		ldi reg3, 0		;ë³÷èëüíèê çàïèñàíèõ áàéò³â
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)				
clearlog2:sts wordadrl, reg1	;çàïèñ â ïàìÿòü 7 áàéò³â, ùîá ñôîðìóâàòè 1é ñëîò íîâîãî öèêëó ³ çàïèñàòè ïîä³þ ñòèðàííÿ
		sts wordadrh, reg2
		ld tmp, z+
		sts i2cdata, tmp
		rcall eewrite
		inc reg3
		cpi reg3, 7
		brsh clearlog3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp clearlog2
clearlog3:inc reg4
		cpi reg4, 2
		brsh clearlog5
		lds reg1, lastlognuml	;³íêðåìåíò íîìåðà ñëîòà ³ ïîâòîðíèé çàïèñ òèõ ñàìèõ äàííèõ (â ðàì çàëèøàºòüñÿ ñòàðèé íîìåð)
		lds reg2, lastlognumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp clearlog4
clearlog5:pop r1
		pop r0
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret
		
clearsett:push reg1		;ï³äïðîãðàìà ñêèäàííÿ íàëàøòóâàíü íà çàâîä		
		push zh
		push zl
		ldi reg1, 0		
		sts wordadrh, reg1
clearsett1:sts wordadrl, reg1
		ldi zh, high(2*dbsett)
		ldi zl, low(2*dbsett)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp,  z
		sts i2cdata, tmp
		call eewrite
		inc reg1
		cpi reg1, 30
		brne clearsett1
		pop zl
		pop zh		
		pop reg1
		ret

dbsett:								;íàá³ð çàâîäñüêèõ íàëàøòóâàíü
.db		10,162,247,75,70,75,5,0,1,0	;0-9
.db		1,60,45,1,1,0,5,90,1,0		;10-19
.db		5,65,0,15,7,4,2,5,5,7	;20-29

fullerase:push reg1		;ï³äïðîãðàìà ïîâíî¿ î÷èñòêè ïàìÿò³
		push zh
		push zl
		ldi reg1, 0		
		sts wordadrh, reg1
fullerase1:sts wordadrl, reg1
		ldi zh, high(2*dbfullerase)
		ldi zl, low(2*dbfullerase)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp,  z
		sts i2cdata, tmp
		call eewrite
		inc reg1
		cpi reg1, 43
		brne fullerase1
		pop zl
		pop zh		
		pop reg1
		ret

dbfullerase:						;íàá³ð çàâîäñüêèõ íàëàøòóâàíü
.db		10,162,247,75,70,75,5,0,1,0	;0-9
.db		1,60,45,1,1,0,5,90,1,0		;10-19
.db		5,65,0,15,7,4,2,5,5,7	;20-29
.db		0,0,0,0,0,0,0,0,0,1		;30-39	
.db		0,1,0,0		;40-43	

searchle:push reg1	;ïîøóê íîìåðà îñòàííüî¿ çàïèñàíî¿ ïîä³¿
		push reg2
		push reg3
		push reg4
		push reg5
		push reg6
		ldi tmp, 0		;çàâàíòàæåííÿ íîìåðà ñëîòà ç ÿêîãî ïî÷àòè ñêàíóâàííÿ
		sts wordadrh, tmp 
		ldi tmp, eelastevenuml
		sts wordadrl, tmp		
		call eeread
		lds reg1, i2cdata	
		ldi tmp, eelastevenumh
		sts wordadrl, tmp		
		call eeread
		lds reg2, i2cdata
		cpi reg2, high(501);ïåðåâ³ðêà ÷è á³ëüøå 500á ÿêùî òàê òî âñòàíîâëþºòüñÿ 1
		brlo searchle0
		cpi reg1, low(501)
		brlo searchle0
		ldi reg1, 1
		ldi reg2, 0		
searchle0:sts lastevnuml, reg1
		sts lastevnumh, reg2
		ldi tmp, 0
		sts evdispl, tmp	;çì³ùåííÿ çàäàºòüñÿ 0
		sts evdisph, tmp
		rcall readevent		;ç÷èòóºòüñÿ çàïèñ ç ¹1
		lds reg3, memdata9	;çàâàíòàæóþòüñÿ çíà÷åííÿ lastevckll, ÿê îïîðíå
		lds reg4, memdata8	;çàâàíòàæóþòüñÿ çíà÷åííÿ lastevcklh, ÿê îïîðíå
searchle3:mov reg5, reg1	;íîìåð ñëîòà êîï³þºòüñÿ
		mov reg6, reg2
		ldi tmp, 1
		add reg5, tmp		;³íêðåìåíòóºòüñÿ íîìåð ñëîòà
		ldi tmp, 0
		adc reg6, tmp		
		cpi reg6, high(501)	;ïåðåâ³ðêà ÷è íîìåð ñëîòà äîñÿãíóâ ê³íöÿ áóôåðà
		brlo searchle1
		cpi reg5, low(501)
		brlo searchle1
		ldi reg5, 1			;ÿêùî òàê òî çàâàíòàæóºòüñÿ ¹1
		ldi reg6, 0
searchle1:sts lastevnuml, reg5
		sts lastevnumh, reg6
		rcall readevent
		lds reg5, memdata9	;ç÷èòóºòüñÿ öèêë³÷íèé íîìåð íàñòóïíîãî ñëîòà
		lds reg6, memdata8
		subi reg5, 1		;çìåíøóºòüñÿ íà 1
		sbci reg6, 0
		cp reg5, reg3		;ïîð³âíþºòüñÿ ç íîìåðîì ïîïåðåäíüîãî ñëîòà
		brne searchle2
		cp reg6, reg4
		brne searchle2
		lds reg1, lastevnuml	;ÿêùî ð³âí³ òî öèêë ïîâòîðþºòüñÿ, äàíí³ îñòàííüîãî ñëîòà ïðèéìàþòüñÿ ÿê îïîðí³
		lds reg2, lastevnumh
		lds reg3, memdata9	
		lds reg4, memdata8
		rjmp searchle3
searchle2:sts lastevnuml, reg1	;ÿêùî í³ òî ïîïåðåäí³é ñëîò áóâ îñòàíí³ì ³ éîãî äàíí³ ïðèéìàþòüñÿ ÿê îïîðí³
		sts lastevnumh, reg2
		sts lastevckll, reg3
		sts lastevcklh, reg4
		pop reg6
		pop reg5
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret

searchll:push reg1	;ïîøóê íîìåðà îñòàííîãî ëîãó òåìïååðàòóðè
		push reg2
		push reg3
		push reg4
		push reg5
		push reg6
		ldi tmp, 0		;çàâàíòàæåííÿ íîìåðà ñëîòà ç ÿêîãî ïî÷àòè ñêàíóâàííÿ
		sts wordadrh, tmp 
		ldi tmp, eelastlognuml
		sts wordadrl, tmp		
		call eeread
		lds reg1, i2cdata	
		ldi tmp, eelastlognumh
		sts wordadrl, tmp		
		call eeread
		lds reg2, i2cdata
		cpi reg2, high(745);ïåðåâ³ðêà ÷è á³ëüøå 745, ÿêùî òàê òî âñòàíîâëþºòüñÿ 1
		brlo searchll0
		cpi reg1, low(745)
		brlo searchll0
		ldi reg1, 1
		ldi reg2, 0		
searchll0:sts lastlognuml, reg1
		sts lastlognumh, reg2
		ldi tmp, 0
		sts logdispl, tmp	;çì³ùåííÿ çàäàºòüñÿ 0
		sts logdisph, tmp
		rcall readlog
		lds reg3, memdata7	;çàâàíòàæóþòüñÿ çíà÷åííÿ lastlogckll, ÿê îïîðíå
		lds reg4, memdata6	;çàâàíòàæóþòüñÿ çíà÷åííÿ lastlogcklh, ÿê îïîðíå
searchll3:mov reg5, reg1
		mov reg6, reg2
		ldi tmp, 1
		add reg5, tmp
		ldi tmp, 0
		adc reg6, tmp
		cpi reg6, high(745)	;ïåðåâ³ðêà ÷è íîìåð ñëîòà äîñÿãíóâ ê³íöÿ áóôåðà
		brlo searchll1
		cpi reg5, low(745)
		brlo searchll1
		ldi reg5, 1
		ldi reg6, 0
searchll1:sts lastlognuml, reg5
		sts lastlognumh, reg6
		rcall readlog
		lds reg5, memdata7
		lds reg6, memdata6
		subi reg5, 1
		sbci reg6, 0
		cp reg5, reg3
		brne searchll2
		cp reg6, reg4
		brne searchll2
		lds reg1, lastlognuml
		lds reg2, lastlognumh
		lds reg3, memdata7	
		lds reg4, memdata6
		rjmp searchll3
searchll2:sts lastlognuml, reg1
		sts lastlognumh, reg2
		sts lastlogckll, reg3
		sts lastlogcklh, reg4
		pop reg6
		pop reg5
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret

storeevent:push reg1	;çáåðåæåííÿ ïîä³¿
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastevnuml ;³íêðåìåíòóâàííÿ íîìåðà ñëîòà îñòàííüîãî çàïèñó
		lds reg2, lastevnumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		cpi reg2, high(501)	;ïåðåâ³ðêà ÷è íîìåð ñëîòà äîñÿãíóâ ê³íöÿ áóôåðà
		brlo storeeve1
		cpi reg1, low(501)
		brlo storeeve1
		ldi reg1, 1
		ldi reg2, 0
storeeve1:sts lastevnuml, reg1	;îíîâëåííÿ íîìåðà îñòàííüîãî çàïèñó
		sts lastevnumh, reg2
		lds reg3, lastevckll	;³íêðåìåíò òà çáåðåæåííÿ öèêë³÷íîãî íîìåðà
		lds reg4, lastevcklh
		ldi tmp, 1
		add reg3, tmp
		ldi tmp, 0
		adc reg4, tmp
		sts lastevckll, reg3
		sts memdata9, reg3
		sts lastevcklh, reg4
		sts memdata8, reg4
		ldi tmp, 9		;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 9 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		ldi reg3, 0		;çàïèñ â ïàìÿòü 9 áàéò³â ñëîòà
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)		
storeeve2:sts wordadrl, reg1
		sts wordadrh, reg2
		ld tmp, z+
		sts i2cdata, tmp
		rcall eewrite
		inc reg3
		cpi reg3, 9
		brsh storeeve3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp storeeve2
storeeve3:pop zl
		pop zh
		pop r0
		pop r1
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret

storelog:push reg1	;çáåðåæåííÿ ëîãó òåìïåðàòóðè
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastlognuml ;³íêðåìåíòóâàííÿ íîìåðà ñëîòà îñòàííüîãî çàïèñó
		lds reg2, lastlognumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		cpi reg2, high(745)	;ïåðåâ³ðêà ÷è íîìåð ñëîòà äîñÿãíóâ ê³íöÿ áóôåðà
		brlo storelog1
		cpi reg1, low(745)
		brlo storelog1
		ldi reg1, 1
		ldi reg2, 0
storelog1:sts lastlognuml, reg1	;îíîâëåííÿ íîìåðà îñòàííüîãî çàïèñó
		sts lastlognumh, reg2
		lds reg3, lastlogckll	;³íêðåìåíò òà çáåðåæåííÿ öèêë³÷íîãî íîìåðà
		lds reg4, lastlogcklh
		ldi tmp, 1
		add reg3, tmp
		ldi tmp, 0
		adc reg4, tmp
		sts lastlogckll, reg3
		sts memdata7, reg3
		sts lastlogcklh, reg4
		sts memdata6, reg4
		ldi tmp, 7		;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 7 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp
		ldi reg3, 0		;çàïèñ â ïàìÿòü 7 áàéò³â ñëîòà
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)		
storelog2:sts wordadrl, reg1
		sts wordadrh, reg2
		ld tmp, z+
		sts i2cdata, tmp
		rcall eewrite
		inc reg3
		cpi reg3, 7
		brsh storelog3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp storelog2
storelog3:pop zl
		pop zh
		pop r0
		pop r1
		pop reg4
		pop reg3
		pop reg2
		pop reg1
		ret

readevent:push reg1		;ç÷èòóâàííÿ çàïèñó ç ëîãó ïîä³é
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastevnuml 
		lds reg2, lastevnumh
		lds reg3, evdispl
		lds reg4, evdisph
		cp reg2, reg4		;îáðàõóâàííÿ çì³ùåííÿ
		brlo readeve11
		cp reg4, reg2
		brlo readeve15
		cp reg3, reg1
		brsh readeve11
readeve15:sub reg1, reg3	;ÿêùî íîìåð çàïèñó á³ëüøèé çà çì³ùåííÿ
		sbc reg2, reg4
		rjmp readeve2
readeve11:sub reg3, reg1	;ÿêùî íîìåð çàïèñó ìåíøèé çà çì³ùåííÿ
		sbc reg4, reg2
		ldi reg1, low(500)
		ldi reg2, high(500)
		sub reg1, reg3
		sbc reg2, reg4
readeve2:ldi tmp, 9		;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 9 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp	
		ldi reg3, 0		;ç÷èòóâàííÿ ç ïàìÿò³ 9 áàéò³â ñëîòà
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)
readeve21:sts wordadrl, reg1
		sts wordadrh, reg2
		rcall eeread
		lds tmp, i2cdata
		st z+, tmp
		inc reg3
		cpi reg3, 9
		brsh readeve3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp readeve21
readeve3:pop zl
		pop zh
		pop r0
		pop r1
		pop reg4
		pop reg3
		pop reg2
		pop reg1	
		ret

readlog:push reg1	;ç÷èòóâàííÿ çàïèñó ç ëîãó òåìïåðàòóðè
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastlognuml 
		lds reg2, lastlognumh
		lds reg3, logdispl
		lds reg4, logdisph
		cp reg2, reg4		;îáðàõóâàííÿ çì³ùåííÿ
		brlo readlog11
		cp reg4, reg2
		brlo readlog15
		cp reg3, reg1
		brsh readlog11
readlog15:sub reg1, reg3	;ÿêùî íîìåð çàïèñó á³ëüøèé çà çì³ùåííÿ
		sbc reg2, reg4
		rjmp readlog2
readlog11:sub reg3, reg1	;ÿêùî íîìåð çàïèñó ìåíøèé çà çì³ùåííÿ
		sbc reg4, reg2
		ldi reg1, low(744)
		ldi reg2, high(744)
		sub reg1, reg3
		sbc reg2, reg4
readlog2:ldi tmp, 7		;îáðàõóâàííÿ àáñîëþòíîãî àäðåñà â ïàìÿò³, äå 7 ðîçì³ð îäíîãî ñëîòà
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;äîäàâàííÿ çì³ùåííÿ
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp	
		ldi reg3, 0		;ç÷èòóâàííÿ ç ïàìÿò³ 7 áàéò³â ñëîòà
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)
readlog21:sts wordadrl, reg1
		sts wordadrh, reg2
		rcall eeread
		lds tmp, i2cdata
		st z+, tmp
		inc reg3
		cpi reg3, 7
		brsh readlog3
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		rjmp readlog21
readlog3:pop zl
		pop zh
		pop r0
		pop r1
		pop reg4
		pop reg3
		pop reg2
		pop reg1	
		ret
		
.equ	lastevnuml = $160
.equ	lastevnumh = $161
.equ	lastevckll = $162
.equ	lastevcklh = $163
.equ	evdispl = $164
.equ	evdisph = $165
.equ	lastlognuml = $166
.equ	lastlognumh = $167
.equ	lastlogckll = $168
.equ	lastlogcklh = $169
.equ	logdispl = $16a
.equ	logdisph = $16b
.equ	gmemadr = $16c	;àäðåñ äëÿ çàãàëüíèõ äàííèõ 0-199 EEPRON, 200 êîðåêòóþ÷à êîíñòàíòà RTC, 201-250 NVRAM
.equ	memdata1 = $16d ;ð³ê			/ð³ê			/çàãàëüí³ äàí³ EEPROM/NVRAM
.equ	memdata2 = $16e	;ì³ñÿöü			/ì³ñÿöü
.equ	memdata3 = $16f	;äåíü			/äåíü
.equ	memdata4 = $170	;ãîäèíà			/ãîäèíà	
.equ	memdata5 = $171	;õâèëèíà		/òåìïåðàòóðà
.equ	memdata6 = $172	;êîä ïîä³¿		/öèêë³÷íèé íîìåð
.equ	memdata7 = $173	;îïö³éí³ äàí³	/öèêë³÷íèé íîìåð
.equ	memdata8 = $174	;öèêë³÷íèé íîìåð
.equ	memdata9 = $175	;öèêë³÷íèé íîìåð

;_________________________________________________ RTC/Calendar ____________________________________________________________________________

gettime:push reg1		;îòðèìàòè ÷àñ â³ä RTC
		push zh
		push zl
		rcall i2cstart
		ldi tmp, 0b11010000
		sts i2cbuf, tmp
		rcall i2ctx
		ldi tmp, 0
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2cstart
		ldi tmp, 0b11010001
		sts i2cbuf, tmp
		rcall i2ctx
		ldi reg1, 0
		ldi zh, high(rtcbuf1)
		ldi zl, low(rtcbuf1)
gettime1:rcall i2crx
		lds tmp, i2cbuf
		st z+, tmp		
		inc reg1
		cpi reg1, 7
		brsh gettime2
		rcall i2cmack
		rjmp gettime1
gettime2:rcall i2cmnack
		rcall i2cstop
		rcall bcdtodec
		pop zl
		pop zh
		pop reg1
		ret

settime:push reg1		;çàïèñàòè ÷àñ â RTC
		push zh
		push zl
		rcall dectobcd
		rcall i2cstart
		ldi tmp, 0b11010000
		sts i2cbuf, tmp
		rcall i2ctx
		ldi tmp, 0
		sts i2cbuf, tmp		;âñòàíîâèòè àäðåñ 1 ÿ÷åéêè
		rcall i2ctx
		ldi reg1, 0
		ldi zh, high(rtcbuf1)
		ldi zl, low(rtcbuf1)
settime1:ld tmp, z+
		sts i2cbuf, tmp
		rcall i2ctx
		inc reg1
		cpi reg1, 7
		brne settime1	
		rcall i2cstop
		pop zl
		pop zh
		pop reg1	
		ret

bcdtodec:lds tmp, rtcbuf1		;Ïðîãðàììà äëÿ ïåðåòâîðåííÿ BCD äàííèõ â³ä RTC â DEC.
		andi tmp, 0b01111111
		rcall bcdtdsp
		sts timesec, tmp
		lds tmp, rtcbuf2
		andi tmp, 0b01111111
		rcall bcdtdsp
		sts timemin, tmp
		lds tmp, rtcbuf3
		andi tmp, 0b00111111
		rcall bcdtdsp
		sts timehour, tmp
		lds tmp, rtcbuf5
		andi tmp, 0b00111111
		rcall bcdtdsp
		sts timedate, tmp
		lds tmp, rtcbuf6
		andi tmp, 0b00011111
		rcall bcdtdsp
		sts timemonth, tmp
		lds tmp, rtcbuf7
		andi tmp, 0b01111111
		rcall bcdtdsp
		sts timeyear, tmp
		ret

bcdtdsp:push reg1				;Ñóáïðîãðàììà ïåðåòâîðåííÿ BCD ÷èñëà â äåñÿòêîâå
		push reg2				;âèêîðèñòîâóºòüñÿ ðåã³ñòð TMP
		push r0
		push r1
		mov reg2, tmp			
		andi tmp, 0b00001111
		swap reg2
		andi reg2, 0b00001111
		ldi reg1, 10
		mul reg2, reg1
		add tmp, r0		
		pop r1
		pop r0
		pop reg2
		pop reg1
		ret

dectobcd:lds tmp, timesec	;Ïðîãðàììà äëÿ ïåðåòâîðåííÿ DEC â BCD äëÿ íàñòðîéêè RTC
		rcall dectbsp
		sts rtcbuf1, tmp
		lds tmp, timemin		
		rcall dectbsp
		sts rtcbuf2, tmp
		lds tmp, timehour		
		rcall dectbsp
		sts rtcbuf3, tmp
		ldi tmp, 0
		sts rtcbuf4, tmp
		lds tmp, timedate		
		rcall dectbsp
		sts rtcbuf5, tmp
		lds tmp, timemonth		
		rcall dectbsp
		sts rtcbuf6, tmp
		lds tmp, timeyear		
		rcall dectbsp
		sts rtcbuf7, tmp		
		ret

dectbsp:push reg1				;Ñóáïðîãðàììà ïåðåòâîðåííÿ äåñÿòêîâîãî ÷èñëà â BCD
		ldi reg1, 0				;âèêîðèñòîâóºòüñÿ ðåã³ñòð TMP
dctbs_2:cpi tmp, 10
		brlo dctbs_1
		subi tmp, 10
		inc reg1
		rjmp dctbs_2
dctbs_1:swap reg1
		or tmp, reg1
		pop reg1
		ret

.equ	rtcbuf1 = $140
.equ	rtcbuf2 = $141
.equ	rtcbuf3 = $142
.equ	rtcbuf4 = $143
.equ	rtcbuf5 = $144
.equ	rtcbuf6 = $145
.equ	rtcbuf7 = $146
.equ	timeyear = $147
.equ	timemonth = $148
.equ	timedate = $149
.equ	timehour = $14a
.equ	timemin = $14b
.equ	timesec = $14c

;_____________________________________________ EEPROM/NVRAM ____________________________________________________________________________

eewrite:push reg1
		push reg2
		ldi reg1, 0	;ë³÷èëüíèê ñïðîá çâÿçêó
		ldi reg2, 0	;ë³÷èëüíèê ñïðîá çàïèñó		 
eewrite12:rcall i2cstart
		ldi tmp, 0b10100000
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, eefreg
		bst tmp, 0
		brtc eewrite2	;ïåðåâ³ðêà ÷è ååïðîì âèäàëà àöê
		rcall i2cstop	;ÿêùî í³ òî ñòîï
		inc reg1	;ÿêùî í³ òî ³íêðåìåíò ë³÷èëüíèêà ñïðîá çâÿçêó
		cpi reg1, 5		;ïåðåâ³ðêà ÷è äîñÿãíóòî ë³ì³òó ñïðîá çâÿçêó
		brlo eewrite11
		set
		bld gereg1, eecerr	;ÿêùî ë³ì³ò äîñÿãíóòî, òî âèñòàâëÿºòüñÿ á³ò ïîìèëêè
		rjmp eewrite9
eewrite11:rcall del1ms	;ÿêùî ë³ì³ò íå äîñÿãíóòî, çàòðèìêà 1 ìñ ³ ïîâòîðíà ñïðîáà
		rjmp eewrite12
eewrite2:ldi reg1, 0	;ñêèäàííÿ ë³÷èëüíèêà ñïðîá çâÿçêó
		clt
		bld gereg1, eecerr ;ñêèäàííÿ ïðàïîðöÿ ñïðîá çâÿçêó
		lds tmp, wordadrh
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, wordadrl
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, i2cdata
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2cstop
		rcall del6ms	;î÷³êóâàííÿ íà ïðîöåäóðó çàïèñó		
		lds reg1, i2cdata
		rcall eeread
		bst gereg1, eecerr ;ïåðåâ³ðêà ÷è ï³ñëÿ ç÷èòóâàííÿ âñòàíîâèâñÿ á³ò ïîìèëêè çâÿçêó
		brts eewrite13
		lds tmp, i2cdata
		cp tmp, reg1	
		brne eewrite13	;ÿêùî äàíí³ çàïèñàí³ ïðàâåëüíî òî âèõ³ä ç ïðîöåäóðè çàïèñó
		clt
		bld gereg1, eewerr	;ñêèäàííÿ á³òó ïîìèëêè çàïèñó
		rjmp eewrite9
eewrite13:inc reg2
		cpi reg2, 5
		brsh eewrite4	;ïåðåâ³ðêà ÷è äîñÿãíóòè ë³ì³ò ñïðîá çàïèñó
		rjmp eewrite12	;ÿêùî í³ òî ïîâòîðíà ñïðîáà		
eewrite4:set
		bld gereg1, eewerr	;ÿêùî òàê òî âñòàíîâëþºòüñÿ á³ò ïîìèëêè çàïèñó		
eewrite9:pop reg2
		pop reg1
		ret

eeread:	push reg1
		ldi reg1, 0	;ë³÷èëüíèê ñïðîá çâÿçêó		 
eeread12:rcall i2cstart
		ldi tmp, 0b10100000
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, eefreg
		bst tmp, 0
		brtc eeread2	;ïåðåâ³ðêà ÷è ååïðîì âèäàëà àöê
		rcall i2cstop
		inc reg1	;ÿêùî í³ òî ³íêðåìåíò ë³÷èëüíèêà ñïðîá çâÿçêó
		cpi reg1, 6		;ïåðåâ³ðêà ÷è äîñÿãíóòî ë³ì³òó ñïðîá çâÿçêó
		brlo eeread11
		set
		bld gereg1, eecerr	;ÿêùî ë³ì³ò äîñÿãíóòî, òî âèñòàâëÿºòüñÿ á³ò ïîìèëêè çâÿçêó
		rjmp eeread9
eeread11:rcall del1ms	;ÿêùî ë³ì³ò íå äîñÿãíóòî, çàòðèìêà 1 ìñ ³ ïîâòîðíà ñïðîáà
		rjmp eeread12
eeread2:clt
		bld gereg1, eecerr	;ñêèäàííÿ á³òó ïîìèëêè çâÿçêó
		lds tmp, wordadrh
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, wordadrl
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2cstart
		ldi tmp, 0b10100001
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2crx
		lds tmp, i2cbuf
		sts i2cdata, tmp
		rcall i2cmnack
		rcall i2cstop
eeread9:pop reg1
		ret

nvwrite:push reg1
		rcall i2cstart
		ldi tmp, 0b11010000
		sts i2cbuf, tmp
		rcall i2ctx	
		lds tmp, wordadrl
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, i2cdata
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2cstop		
		pop reg1
		ret

nvread:	push reg1
		rcall i2cstart
		ldi tmp, 0b11010000
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, wordadrl	
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2cstart
		ldi tmp, 0b11010001
		sts i2cbuf, tmp
		rcall i2ctx
		rcall i2crx
		lds tmp, i2cbuf
		sts i2cdata, tmp
		rcall i2cmnack
		rcall i2cstop
		pop reg1
		ret

del1ms:	push reg7
		push reg8
		ldi reg7, 20
del1ms2:ldi reg8, 100
del1ms1:dec reg8
		cpi reg8, 0
		brne del1ms1
		dec reg7
		cpi reg7, 0
		brne del1ms2
		pop reg8
		pop reg7
		ret

del6ms:	rcall del1ms
		rcall del1ms
		rcall del1ms
		rcall del1ms
		rcall del1ms
		rcall del1ms
		ret

starti2c:ldi tmp, 0
		sts eefreg, tmp
		ret

.equ	i2cbuf = $13a		
.equ	wordadrl = $13b
.equ	wordadrh = $13c
.equ	i2cdata = $13d
.equ	eefreg = $13e	;ðåã³ñòð ïðàïîðö³â øèíè I2C  , 0 - Àöê ñëåéâà

;_____________________________________________ I2C Protocol ____________________________________________________________________________

i2cstart:lds tmp, ddrg		;ïî÷àòêîâà êîíô³ãóðàö³ÿ ïîðòà/ñòàðò
		andi tmp, 0b11101111
		sts ddrg, tmp	;cbi ddrg, 4
		lds tmp, portg
		andi tmp, 0b11101111
		sts portg, tmp	;cbi portg, 4
		rcall deli2c
		lds tmp, portg
		ori tmp, 0b00001000
		sts portg, tmp	;sbi portg, 3
		lds tmp, ddrg
		ori tmp, 0b00001000
		sts ddrg, tmp	;sbi ddrg, 3	
		rcall deli2c
		rcall cbisda
		rcall deli2c
		rcall cbiscl
		rcall deli2c		
		ret

sbiscl:	lds tmp, portg
		ori tmp, 0b00001000
		sts portg, tmp
		ret

cbiscl:	lds tmp, portg
		andi tmp, 0b11110111
		sts portg, tmp
		ret

sbisda:	lds tmp, ddrg
		andi tmp, 0b11101111
		sts ddrg, tmp
		ret

cbisda:	lds tmp, ddrg
		ori tmp, 0b00010000
		sts ddrg, tmp
		ret


i2cstop:rcall sbiscl	;ñòîï
		rcall deli2c
		rcall sbisda
		rcall deli2c
		ret

i2ctx:	push reg6	;â³äïðàâêà îäíîãî áàéòà, îáì³í ÷åðåç TMP, ñòàí ACK â á³ò³ T
		push reg1
		ldi reg6, 8
		lds reg1, i2cbuf
i2ctx3:	lsl reg1
		brcs i2ctx1
		rcall cbisda
		rjmp i2ctx2
i2ctx1:	rcall sbisda
i2ctx2:	rcall deli2c
		rcall sbiscl
		rcall deli2c
		rcall cbiscl
		rcall deli2c
		dec reg6
		brne i2ctx3
		rcall i2csack
		pop reg1
		pop reg6
		ret

i2crx:	push reg6	;îòðèìàííÿ îäíîãî áàéòà, îáì³í ÷åðåç TMP, ACK íå âèêëèêàºòüñÿ
		push reg1
		ldi reg6, 8
		ldi reg1, 0
		rcall sbisda
i2crx3:	rcall sbiscl
		rcall deli2c
		lds tmp, ping
		bst tmp, 4
		brtc i2crx1
		sec
		rjmp i2crx2
i2crx1:	clc
i2crx2:	rol reg1
		rcall cbiscl
		rcall deli2c
		dec reg6
		brne i2crx3
		sts i2cbuf, reg1
		pop reg1
		pop reg6
		ret

i2csack:rcall sbisda	;ACK, â³äïîâ³äü ñëåéâà ìàñòåðó
		rcall deli2c
		rcall sbiscl
		rcall deli2c
		lds tmp, ping
		bst tmp, 4
		lds tmp, eefreg
		bld tmp, 0
		sts eefreg, tmp
		rcall cbiscl
		rcall deli2c
		rcall cbisda
		rcall deli2c
		ret

i2cmack:rcall cbisda	;ACK, â³äïîâ³äü ìàñòåðà ñëåéâó
		rcall deli2c
		rcall sbiscl
		rcall deli2c
		rcall cbiscl
		rcall deli2c
		ret

i2cmnack:rcall sbisda	;NACK, â³äïîâ³äü ìàñòåðà ñëåéâó
		rcall deli2c
		rcall sbiscl
		rcall deli2c
		rcall cbiscl
		rcall deli2c
		rcall cbisda
		rcall deli2c
		ret	

deli2c:	push reg8
		ldi reg8, 25		;çìåíøèâ ç 50 äî 25
deic1:	dec reg8
		brne deic1
		pop reg8
		ret
		
;_____________________________________________ Fast timer__________________________________________________________________________________

fasttimer:push tmp ;Timer2
		in tmp, sreg
		push tmp
		ldi tmp, fasttime
		out tcnt2, tmp

		rcall keyask	
		rcall dind	
		rcall beepctr
		rcall dscomm		

		pop tmp
		out sreg, tmp
		pop tmp
		reti

fasttmstart:ldi tmp, 0b00000100	;çàïóñê øâèäêîãî òàéìåðà
		out tccr2, tmp
		in tmp, timsk
		ori tmp, 0b11000000
		out timsk, tmp
		ldi tmp, fasttime
		out tcnt2, tmp
		sei
		ret

;__________________________________________________ DS18B20 ___________________________________________________________________________

dscomm:	push reg1		;OPOPOP.........|.......OPOP\end.....
		push reg2		;dscommsteph = 0|dscommsteph = 1
		push zl
		push zh
		push r0
		push r1

		lds reg1, dscommsteph
		lds reg2, dscommstepl
		cpi reg1, 255	;ÿêùî 255 âèêîíàííÿ çàáîðîíåíî, íà âèõ³ä
		brne dscomm1
		rjmp dscomme
dscomm1:cpi reg1, 1		;âèá³ð ìîëîäøî¿ ÷è ñòàðøî¿ ï³äïðîãðàìè
		brne dscomm11
		rjmp dscomm2

dscomm11:cpi reg2, 3	;ÿêùî dscommsteph = 0
		brlo dscomm12	;ÿêùî âñ³ îïåðàö³¿ ç ìîëîäøî¿ ãðóïè âèêîíàí³ òî ïðîïóñê òàêò³â äî ïåðåïîâíåííÿ dscommstepl
		rjmp dscomm1a
dscomm12:mov tmp, reg2
		lsl tmp
		ldi zh, high(2*dwdsdsopl) ;âèá³ð ïîòð³áíî¿ îïåðàö³¿ ìîëîäøî¿ ãðóïè
		ldi zl, low(2*dwdsdsopl)  ;îïåðàö³¿ ìîëîäøî¿ ãðóïè äàþòü êîìàíäó íà çàïóñê âèì³ðþâàííÿ
		add zl, tmp				  ;äàë³ ðåøòó ìîëîäøî¿ ãðóïè òà ÷àñòèíó ñòàðøî¿ ïðîïóñê òàêò³â (ùîá > 750ms)
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		icall		
dscomm1a:inc reg2		;³íêðåìåíò íîìåðà êðîêó, ÿêùî ïåðåïîâíåííÿ òî dscommsteph = 1
		cpi reg2, 255
		brsh dscomm1b
		rjmp dscomm3
dscomm1b:ldi reg2, 0
		ldi reg1, 1
		rjmp dscomm3

dscomm2:cpi reg2, 40	;ÿêùî dscommsteph = 1
		brsh dscomm21	;äîêè dscommstepl íå äîñÿãíå 40, ïðîïóê òàêò³â	
		rjmp dscomm2a
dscomm21:cpi reg2, 53	;ÿêùî á³ëüøå 52 òî ïðîïóñê òàêò³â, öå ïð³áíî äëÿ çá³ëüøåííÿ ïåð³îäà ì³æ âèì³ðþâàííÿìè (ñàìîðîç³ãð³â)
		brsh dscomm2a
		mov tmp, reg2
		subi tmp, 40	;â³äí³ìàºòüñÿ ÷èñëî çì³ùåííÿ - 40, öå ïîòð³áíî äëÿ àäðåñàö³¿ (òàêèì ÷èíîì ôîðìóºòüñÿ çàòðèìêà ì³æ ãðóïàìè (>750ms))
		lsl tmp
		ldi zh, high(2*dwdsdsoph) ;âèá³ð ïîòð³áíî¿ îïåðàö³¿ ñòàðøî¿ ãðóïè
		ldi zl, low(2*dwdsdsoph)  ;îïåðàö³¿ ñòàðøî¿ ãðóïè ç÷èòóþòü òà îáðîáëÿþòü ðåçóëüòàòè
		add zl, tmp
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		icall
dscomm2a:inc reg2	;³íêðåìåíò íîìåðà êðîêó, ÿêùî ïåðåïîâíåííÿ òî dscommsteph = 0
		cpi reg2, 255
		brlo dscomm3
		ldi reg2, 0
		ldi reg1, 0
dscomm3:sts dscommstepl, reg2
		sts dscommsteph, reg1
dscomme:pop r1
		pop r0
		pop zh
		pop zl
		pop reg2
		pop reg1
		ret

dwdsdsopl:
.dw		dsopstart,dsoptx_cc,dsoptx_44

dwdsdsoph:
.dw		dsopstart,dsoptx_cc,dsoptx_be,dsoprx_buf0,dsoprx_buf1,dsoprx_buf2,dsoprx_buf3
.dw		dsoprx_buf4,dsoprx_buf5,dsoprx_buf6,dsoprx_buf7,dsoprx_crc,dsopproces

dsopstart:rcall w1st
		ret
dsoptx_cc:ldi tmp, $cc
		sts w1buf, tmp
		rcall w1tx
		ret
dsoptx_44:ldi tmp, $44
		sts w1buf, tmp
		rcall w1tx
		ret
dsoptx_be:ldi tmp, $be
		sts w1buf, tmp
		rcall w1tx
		ret
dsoprx_buf0:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf0, tmp
		ret
dsoprx_buf1:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf1, tmp
		ret
dsoprx_buf2:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf2, tmp
		ret
dsoprx_buf3:rcall w1rx
		lds tmp, w1buf	
		sts dscommbuf3, tmp
		ret
dsoprx_buf4:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf4, tmp
		ret
dsoprx_buf5:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf5, tmp
		ret
dsoprx_buf6:rcall w1rx
		lds tmp, w1buf
		sts dscommbuf6, tmp
		ret
dsoprx_buf7:rcall w1rx
		lds tmp, w1buf		
		sts dscommbuf7, tmp
		ret
dsoprx_crc:rcall w1rx
		lds tmp, w1buf
		sts dscommcrc, tmp
		ret

dsopproces:push reg1
		push reg2
		rcall getcrc8
		lds tmp, dscommfreg
		cpi tmp, 0		
		breq dsproces11	;ïåðåâ³ðêà ÷è íå âñòàíîâëåí³ ïðàïîðö³ ïîìèëêè, ÿêùî í³ òî íîðìàëüíà îáðîáêà
		ldi tmp, 0
		sts w1dvcount, tmp ;ñêèäàííÿ ë³÷èëüíèêà ä³éñíèõ äàíèõ
		lds reg1, w1ercount
		cpi reg1, 3		;ïåðåâ³ðêà ÷è áóëî âæå 3 ïîìèëêè
		brsh dsproces12	
		inc reg1
		sts w1ercount, reg1
		cpi reg1, 3
		brsh dsproces12
		rjmp dsproces3	;ÿêùî í³ òî ïðîñòî âèõ³ä áåç îáðîáêè
dsproces12:lds tmp, dscommfreg
		bst tmp, 0	;ÿêùî òàê òî êîï³þâàííÿ á³ò³â ïîìèëîê â gereg
		bld gereg1, dscome
		bst tmp, 1
		bld gereg1, dscrce
		bst tmp, 2
		bld gereg1, dspwdn
		clt
		bld gereg1, dsdtv
		rjmp dsproces3
dsproces11:lds tmp, w1dvcount
		cpi tmp, 2		;ïåðøå âèì³ðþâàííÿ ³ãíîðóºòüñÿ
		brsh dsproces13	;öå ïîòð³áíî ùîá ðåçóëüòàòè ïåðøîãî âèì³ðó ï³ñëÿ ïîìèëêè àáî çàïóñêó ³ãíîðóâàëèñÿ
		inc tmp
		sts w1dvcount, tmp
		rjmp dsproces3
dsproces13:ldi tmp, 0
		sts w1ercount, tmp	;ñêèäàííÿ ë³÷èëüíèêà ïîìèëîê
		clt
		bld gereg1, dscome
		bld gereg1, dspwdn
		bld gereg1, dscrce	;ñêèäàííÿ ïðàïîðö³â ïîìèëîê
		set
		bld gereg1, dsdtv	;äàí³ ä³éñí³
		lds reg1, dscommbuf1 ;îáðîáêà äàííèõ
		swap reg1
		andi reg1, $f0
		lds tmp, dscommbuf0
		swap tmp
		andi tmp, $0f
		or reg1, tmp
		sts tempuni, reg1
		ldi tmp, 0
dsproces22:cpi reg1, 10
		brlo dsproces21
		subi reg1, 10
		inc tmp
		rjmp dsproces22
dsproces21:sts tempods, reg1
		sts tempdes, tmp
		lds tmp, dscommbuf0
		andi tmp, $0f
		ldi zh, high(2*dbteds)
		ldi zl, low(2*dbteds)
		add zl, tmp
		ldi tmp, 0
		adc zh, tmp
		lpm tmp, z
		sts temppar, tmp
		set
		bld toutreg, slot1tint	;âèêëèê ï³äïðîãðàìè ïåðåíîñó äàííèõ (ñëîò 1)

 dsproces3:	pop reg2
		pop reg1
		ret				

dbteds:	
.db		0,0,1,1,2,3,3,4,5,5,6,6,7,8,8,9

getcrc8:push xl			;ïðîãðàìà ðîçðàõóíêó CRC8
		push xh
		push zl
		push zh
		push reg1
		push reg2
		ldi reg1, 0
		ldi reg2, 0
		ldi xh, high(dscommbuf0)
		ldi xl, low(dscommbuf0)
getcrc81:ld tmp, x+			;áàéò äàííèõ ç áóôåðà
		eor reg1, tmp		;êñîðèì àêòóàëüíå çíà÷åííÿ CRC íà äàí³ ç áóôåðà
		ldi zh, high(2*dbcrc8)
		ldi zl, low(2*dbcrc8)
		add zl, reg1		;îòðèìàíå çíà÷åííÿ âèêîðèñòîâóºòüñÿ ÿê ³íäåêñ
		ldi tmp, 0
		adc zh, tmp
		lpm reg1, z			;ç òàáëèö³ îòðèìóºòüñÿ íîâå çíà÷åííÿ CRC
		inc reg2
		cpi reg2, 8
		brne getcrc81
		lds reg2, dscommfreg
		lds tmp, dscommcrc	
		cp tmp, reg1
		breq getcrc82
		set
		rjmp getcrc83
getcrc82:clt
getcrc83:bld reg2, 1	;âèñòàâëÿºòüñÿ â³äïîâ³äíèé á³ò (CRC ïðàâåëüíå/íåïðàâåëüíå)
		sts dscommfreg, reg2
		pop reg2
		pop reg1
		pop zh
		pop zl
		pop xh
		pop xl
		ret

dbcrc8:
.db		0,94,188,226,97,63,221,131,194,156,126,32,163,253,31,65	;òàáëèöÿ äëÿ CRC8
.db		157,195,33,127,252,162,64,30,95,1,227,189,62,96,130,220
.db		35,125,159,193,66,28,254,160,225,191,93,3,128,222,60,98
.db		190,224,2,92,223,129,99,61,124,34,192,158,29,67,161,255
.db		70,24,250,164,39,121,155,197,132,218,56,102,229,187,89,7
.db		219,133,103,57,186,228,6,88,25,71,165,251,120,38,196,154
.db		101,59,217,135,4,90,184,230,167,249,27,69,198,152,122,36
.db		248,166,68,26,153,199,37,123,58,100,134,216,91,5,231,185
.db		140,210,48,110,237,179,81,15,78,16,242,172,47,113,147,205
.db		17,79,173,243,112,46,204,146,211,141,111,49,178,236,14,80
.db		175,241,19,77,206,144,114,44,109,51,209,143,12,82,176,238
.db		50,108,142,208,83,13,239,177,240,174,76,18,145,207,45,115
.db		202,148,118,40,171,245,23,73,8,86,180,234,105,55,213,139
.db		87,9,235,181,54,104,138,212,149,203,41,119,244,170,72,22
.db		233,183,85,11,136,214,52,106,43,117,151,201,74,20,246,168
.db		116,42,200,150,21,75,169,247,182,232,10,84,215,137,107,53

w1st:	push reg7	;Ôðåéì ðåñåòó, ïðè â³äñóòíîñò³ â³äïîâ³ä³ â³ä äàò÷èêà âèñòàâëÿº 0 á³ò â sdcommfreg
		push reg8
		cbi ddrb, 6	;äëÿ êîíòðîëþ â³äïóñêàºòüñÿ ë³í³ÿ 1W
		rcall dlw4	;çàòðèìêà íà â³äíîâëåííÿ ë³í³¿
		in tmp, pinb	
		bst tmp, 6	;ÿêùî íà ï³í³ 0 - ë³í³ÿ çàêîðî÷åíà
		brts w1st2
		set
		rjmp w1st3		
w1st2:	clt		
w1st3:	lds tmp, dscommfreg	;âñòàíîâëþºòüñÿ àáî î÷èùàºòüñÿ á³ò ÊÇ äàò÷èêà
		bld tmp, 2
		sts dscommfreg, tmp
		cbi portb, 6 
		sbi ddrb, 6
		rcall dlw520
		cbi ddrb, 6
		rcall dlw70
		in tmp, pinb
		bst tmp,6
		brts w1st1
		clt
		rjmp w1stex		
w1st1:	set		
w1stex:	lds tmp, dscommfreg	;âñòàíîâëþºòüñÿ àáî î÷èùàºòüñÿ á³ò â³äïîâ³ä³ íà ðåñåò äàò÷èêà
		bld tmp, 0
		sts dscommfreg, tmp
		pop reg8
		pop reg7		
		ret

w1tx:	push reg5	;Ôðåéì â³äïðàâêè áàéòà, îáì³í ÷åðåç w1buf
		push reg6
		push reg7
		push reg8
		ldi reg6, 0
		lds reg5, w1buf
w1tx2:	cbi portb,6
		sbi ddrb, 6
		rcall dlw4
		lsr reg5
		brcc w1tx1
		cbi ddrb, 6
w1tx1:	rcall dlw70
		cbi ddrb, 6
		rcall dlw4
		inc reg6
		cpi reg6, 8
		brne w1tx2
		pop reg8
		pop reg7
		pop reg6
		pop reg5
		ret

w1rx:	push reg5	;Ôðåéì ïðèéîìó áàéòà, îáì³í ÷åðåç w1buf
		push reg6
		push reg7
		push reg8
		ldi reg6, 0
		ldi reg5, 0
w1rx3:	cbi portb,6
		sbi ddrb, 6
		rcall dlw4
		cbi ddrb, 6
		rcall dlw9
		in tmp, pinb
		bst tmp,6
		brts w1rx1
		clc
		ror reg5
		rjmp w1rx2
w1rx1:	sec
		ror reg5
w1rx2:	rcall dlw70
		inc reg6
		cpi reg6, 8
		brne w1rx3
		sts w1buf, reg5
		pop reg8
		pop reg7
		pop reg6
		pop reg5
		ret

dlw520:	ldi reg8, 70
dlw522:	ldi reg7, 19
dlw521:	dec reg7
		brne dlw521	
		dec reg8
		brne dlw522	
		ret
dlw70:	ldi reg8, 3
dlw702:	ldi reg7, 60
dlw701:	dec reg7
		brne dlw701	
		dec reg8
		brne dlw702	
		ret
dlw9:	ldi reg8, 20 ;22 çì³íåíî íà 20
dlw91:	dec reg8
		brne dlw91
		ret
dlw4:	ldi reg8, 8
dlw41:	dec reg8
		brne dlw41
		ret

startdscomm:ldi tmp, 0
		sts dscommstepl, tmp
		sts dscommsteph, tmp		
		sts dscommfreg, tmp	
		sts w1ercount, tmp
		sts w1dvcount, tmp
		ret

stopdscomm:ldi tmp, 255		;ÿêùî 255 òî ïðîãðàìà îáì³íó ç äàò÷èêîì áëîêóºòüñÿ
		sts dscommsteph, tmp
		cbi portb, 6
		cbi ddrb, 6
		clt
		bld gereg1, dsdtv	;ñêèíóòè á³ò ùî äàí³ â³ä äàò÷èêà ä³éñí³

		ret

.equ	dscommstepl = $125
.equ	dscommsteph = $126
.equ	dscommfreg = $127	;Ðåã³ñòð ïðàïîðö³â 0 - ïîìèëêà â³äïîâ³ä³ â³ä äàò÷èêà ï³ñëÿ ðåñåòó 1, 1 - ïîìèëêà CRC8, 2 - ÊÇ,
.equ	dscommbuf0 = $128
.equ	dscommbuf1 = $129
.equ	dscommbuf2 = $12a
.equ	dscommbuf3 = $12b
.equ	dscommbuf4 = $12c
.equ	dscommbuf5 = $12d
.equ	dscommbuf6 = $12e
.equ	dscommbuf7 = $12f
.equ	dscommcrc = $130
.equ	tempuni = $131	;ö³ë³ ãðàäóñ³â
.equ	temppar = $132	;äåñÿò³ ãðàäóñ³â
.equ	tempods = $133	;îäèíèö³ ãðàäóñ³â, ïîêè íå âèêîðèñòîâóºòüñÿ - çàðåçåðâîâàíî àäðåñ
.equ	tempdes = $134	;äåñÿòêè ãðàäóñ³â, ïîêè íå âèêîðèñòîâóºòüñÿ - çàðåçåðâîâàíî àäðåñ
.equ	w1buf = $135	;áóôåð 1wire
.equ	w1ercount = $136 ;ðàõóíîê ê³ëüêîñò³ ïîìèëîê ïåðåäà÷³ äàííèõ, ï³ñëÿ 3 â gereg1 âèñòàâëÿþòüñÿ á³òè ïîìèëîê
.equ	w1dvcount = $137 ;ðàõóíîê ïðàâåëüíèõ ç÷èòóâàíü, ï³ñëÿ äðóãîãî ïðàâåëüíîãî ç÷èòóâàííÿ äàí³ ââàæàþòüñÿ ä³éñèìè	

;_________________________________________ Beep'er (sound gen) Control___________________________________________________________________________

beepctr:push reg1
		push reg2
		push zl
		push zh
		push r0
		push r1

		lds tmp, beepftckl
		inc tmp
		cpi tmp, 4
		brsh beepctr1
		sts beepftckl, tmp
		rjmp beepctre		
beepctr1:ldi tmp, 0			;âèêîíàííÿ ïðîãðàìè êîæåí 4-é öèêë òàéìåðà
		sts beepftckl, tmp

		lds reg1, beepnck	;íåöèêë³÷í³ çâóêîâ³ ñèãíàëè
		lds tmp, beepncktemp
		cp reg1, tmp		;ïåðåâ³ðêà ÷è íå çì³íèâñÿ íîìåð ñèãíàëó
		breq beepctr11
		sts beepncktemp, reg1
		ldi tmp, 0
		sts beepnckstep, tmp
		sts beepnckcount, tmp
beepctr11:cpi reg1, 0		;ÿêùî íóëü, òî ñèãíàë âèìêíåíî
		brne beepctr12
		lds tmp, beepfreg
		clt
		bld tmp, 2
		bld tmp, 3
		sts beepfreg, tmp
		rjmp beepctr2		;ïåðåõ³ä äî ïðîãðàìè öèêë³÷íèõ çâóêîâèõ ñèãíàë³â
beepctr12:lds reg2, beepnckcount
		cpi reg2, 0			;ïåðåâ³ðêà ÷è âèêîíàíèé êðîê çâóêîâî¿ ïîñë³äîâíîñò³
		breq beepctr13
		dec reg2
		cpi reg2, 0			;ïåðåâ³ðêà ÷è âèêîíàíèé êðîê çâóêîâî¿ ïîñë³äîâíîñò³
		breq beepctr13
		sts beepnckcount, reg2
		rjmp beepctr2
beepctr13:dec reg1
		lsl reg1	;â reg1 çáåð³ãàºòüñÿ íîìåð ñèãíàëó *2		
		ldi zh, high(2*dwbeepnck) ;âèá³ð ïîòð³áíî¿ áàçè ïî íîìåðó ñèãíàëó
		ldi zl, low(2*dwbeepnck)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		lds reg1, beepnckstep	;àâòîìàòè÷íèé ³íêðåìåíò íîìåðà êðîêó
		inc reg1	
		sts beepnckstep, reg1			
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp, z
		cpi tmp, 255	;ïåðåâ³ðêà ÷è çâóêîâà ïîñë³äîâí³ñòü çàâåðøåíà
		brne beepctr14
		lds tmp, beepfreg
		clt 
		bld tmp, 2
		bld tmp, 3
		sts beepfreg, tmp
		clr tmp
		sts beepnck, tmp ;îñê³ëüêè çâóêîâà ïîñë³äîâí³òü â³äòâîðåíà - çàïèñóºòüñÿ 0
		sts beepnckstep, tmp
		sts beepnckcount, tmp
		rjmp beepctr2
beepctr14:cpi tmp, 100
		brlo beepctr15	;ÿêùî á³ëüøå 100 òî íà ïåð³îä ÷àñó äèíàì³ê ââ³ìêíåíî
		subi tmp, 100	;³íäèêàòîðíå ÷èñëî 100 â³äí³ìàºòüñÿ
		sts beepnckcount, tmp
		lds tmp, beepfreg
		set 
		bld tmp, 2
		bld tmp, 3
		sts beepfreg, tmp
		rjmp beepctr2
beepctr15:sts beepnckcount, tmp
		lds tmp, beepfreg
		set 
		bld tmp, 2
		clt
		bld tmp, 3
		sts beepfreg, tmp

beepctr2:lds reg1, beepckl	;öèêë³÷í³ çâóêîâ³ ñèãíàëè
		lds tmp, beepckltemp
		cp reg1, tmp		;ïåðåâ³ðêà ÷è íå çì³íèâñÿ íîìåð ñèãíàëó
		breq beepctr21
		sts beepckltemp, reg1
		ldi tmp, 0
		sts beepcklstep, tmp
		sts beepcklcount, tmp
beepctr21:cpi reg1, 0		;ÿêùî íóëü, òî ñèãíàë âèìêíåíî
		brne beepctr22
		lds tmp, beepfreg
		clt
		bld tmp, 4
		sts beepfreg, tmp
		rjmp beepctr3		;ïåðåõ³ä äî ïðîãðàìè çâåäåííÿ
beepctr22:lds reg2, beepcklcount
		cpi reg2, 0			;ïåðåâ³ðêà ÷è âèêîíàíèé êðîê çâóêîâî¿ ïîñë³äîâíîñò³
		breq beepctr23
		dec reg2
		cpi reg2, 0			;ïåðåâ³ðêà ÷è âèêîíàíèé êðîê çâóêîâî¿ ïîñë³äîâíîñò³
		breq beepctr23
		sts beepcklcount, reg2
		rjmp beepctr3
beepctr23:dec reg1
		lsl reg1	;â reg1 çáåð³ãàºòüñÿ íîìåð ñèãíàëó *2		
		ldi zh, high(2*dwbeepckl) ;âèá³ð ïîòð³áíî¿ áàçè ïî íîìåðó ñèãíàëó
		ldi zl, low(2*dwbeepckl)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		lds reg1, beepcklstep	;àâòîìàòè÷íèé ³íêðåìåíò íîìåðà êðîêó
		inc reg1	
		sts beepcklstep, reg1			
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp, z
		cpi tmp, 255	;ïåðåâ³ðêà ÷è çâóêîâà ïîñë³äîâí³ñòü çàâåðøåíà
		brne beepctr24
		clr tmp
		sts beepcklstep, tmp ;çâóêîâà ïîñë³äîâí³òü â³äòâîðþºòüñÿ ïîâòîðíî
		sts beepcklcount, tmp
		rjmp beepctr3
beepctr24:cpi tmp, 100
		brlo beepctr25	;ÿêùî á³ëüøå 100 òî íà ïåð³îä ÷àñó äèíàì³ê ââ³ìêíåíî
		subi tmp, 100	;³íäèêàòîðíå ÷èñëî 100 â³äí³ìàºòüñÿ
		sts beepcklcount, tmp
		lds tmp, beepfreg
		set 
		bld tmp, 4
		sts beepfreg, tmp
		rjmp beepctr3
beepctr25:sts beepcklcount, tmp
		lds tmp, beepfreg
		clt
		bld tmp, 4
		sts beepfreg, tmp

beepctr3:lds tmp, beepfreg
		bst tmp, 0
		brts beepctr35	;ÿêùî íåöèêë³÷í³ çâóêîâ³ ñèãíàëè ïðèãëóøåí³ òî çðàçó ïåðåõ³ä äî öèêë³÷íèõ
		bst tmp, 2
		brtc beepctr35	;ÿêùî ìîäóëÿòîð íåöèêë³÷íèõ çâóêîâ³ ñèãíàë³â âèìêíåíî òî çðàçó ïåðåõ³ä äî öèêë³÷íèõ
		bst tmp, 3
		brtc beepctr31	;ïåðåâ³ðêà ÷è äèíàì³ê ââ³ìêíåíî
		sbi porta, 1
		rjmp beepctre
beepctr31:cbi porta, 1
		rjmp beepctre
beepctr35:bst tmp, 1
		brts beepctr36	;ÿêùî öèêë³÷í³ çâóêîâ³ ñèãíàëè ïðèãëóøåí³ òî âèìêíåííÿ äèíàì³êà ³ âèõ³ä
		bst tmp, 4
		brtc beepctr37	;ïåðåâ³ðêà ÷è äèíàì³ê ââ³ìêíåíî
		sbi porta, 1
		rjmp beepctre
beepctr37:cbi porta, 1
		rjmp beepctre
beepctr36:cbi porta, 1

beepctre:pop r1
		pop r0
		pop zh
		pop zl
		pop reg2
		pop reg1
		ret
	
dwbeepnck:
.dw		2*dbbeepnck1,2*dbbeepnck2,2*dbbeepnck3,2*dbbeepnck4,2*dbbeepnck5,2*dbbeepnck6

dbbeepnck1:
.db		0,104,255,0

dbbeepnck2:
.db		0,104,6,104,255,0

dbbeepnck3:
.db		0,104,6,104,6,104,255,0

dbbeepnck4:
.db		0,104,6,104,6,104,6,104,6,120,255,0

dbbeepnck5:
.db		0,118,255,0

dbbeepnck6:
.db		0,115,6,115,255,0

dwbeepckl:
.dw		2*dbbeepckl1,2*dbbeepckl2,2*dbbeepckl3,2*dbbeepckl4

dbbeepckl1:
.db		0,104,6,104,99,99,99,99,99,99,99,99,255,0

dbbeepckl2:
.db		0,115,6,115,99,99,99,45,255,0

dbbeepckl3:
.db		0,140,40,255

dbbeepckl4:
.db		0,199,255,0


.equ	beepnck = $11a		;íåöèêë³÷í³ çâóêîâ³ ñèãíàëè @1 - 1 êîðîòêèé çâóê,		 ;âèùèé ïð³îðèòåò
							;@2 - 2 êîðîòêèõ çâóêè, @3 - 3 êîðîòêèõ çâóêè, 
							;@4 - 4 êîðîòêèõ çâóêè + 1 äîâãèé, @5 - 1 äîâãèé,
							;@6 - 2 äîâãèõ.
.equ	beepncktemp = $11b	;òèì÷àñîâèé ðåã³ñòð íåöèêë³÷íèõ çâóêîâèõ ñèãíàë³â
.equ	beepnckstep = $11c	;êðîê çâóêîâî¿ ïîñë³äîâíîñò³
.equ	beepnckcount = $122	;ðàõóíîê ÷àñó çâóêîâî¿ ïîñë³äîâíîñò³
.equ	beepckl = $11d		;öèêë³÷í³ çâóêîâ³ ñèãíàëè @1 - 1 ñåêóíäà íà 15 ñåêóíä,	 ;íèæ÷èé ïð³îðèòåò
							;@2 - 2 ñåêóíäè íà 10 ñåêóíä, @3 - 3 ñåêóíäè íà 3 ñåêóíä,
							;@4 - íåïðåðèâíèé çâóêîâèé ñèãíàë.
.equ	beepckltemp = $11e	;òèì÷àñîâèé ðåã³ñòð öèêë³÷íèõ çâóêîâèõ ñèãíàë³â
.equ	beepcklstep = $11f	;êðîê çâóêîâî¿ ïîñë³äîâíîñò³
.equ	beepcklcount = $123	;ðàõóíîê ÷àñó çâóêîâî¿ ïîñë³äîâíîñò³
.equ	beepfreg = $120		;ðåã³ñòð ïðàïîðö³â ìîäóëÿòîðà @0 - ïðèãëóøåííÿ íåöèêë³÷íèõ çâóêîâèõ ñèãíàë³â,
							;@1 - ïðèãëóøåííÿ öèêë³÷íèõ çâóêîâèõ ñèãíàë³â, @2 - ìîäóëÿòîð íöë. çâ. ñèã. ââ³ìêíåíèé
							;@3 - íöë. çâ. ñèã. äèíàì³ê - ââ³ìêíåíèé, @4 - öèêë³÷í. çâ. ñèã. äèíàì³ê - ââ³ìêíåíèé
.equ	beepftckl = $121	;ðåã³ñòð ðàõóíêó öèêë³â øâèäêîãî òàéìåðà (ïðîãðàìà ìîäóëÿòîðà âèêîíóºòüñÿ êîæåí 4-é öèêë)

beepstart:ldi tmp, 0
		sts beepnck, tmp
		sts beepncktemp, tmp
		sts beepnckstep, tmp
		sts beepnckcount, tmp
		sts beepckl, tmp
		sts beepckltemp, tmp
		sts beepcklstep, tmp
		sts beepcklcount, tmp		
		sts beepftckl, tmp
		lds tmp, beepfreg
		andi tmp, 0b00000001 
		sts beepfreg, tmp
		ret

beepstop:lds tmp, beepfreg
		set 
		bld tmp, 0
		bld tmp, 1
		sts beepfreg, tmp	
		clr tmp
		sts beepnck, tmp
		sts beepckl, tmp
		ret		

;_____________________________________________ Dinamic ind Control_______________________________________________________________________________

fpdimm:	sbi porta, 4 ;ä³ì³íã ïåðåäíüî¿ ïàíåë³
		sbi porta, 2
		sbi porta, 0
		sbi portd, 3
		reti

dind:	push reg1
		lds reg1, lednum
		cpi reg1, 255		;ÿêùî 255 - äèíàì³÷íà ³íäèêàö³ÿ âèìêíóòà
		brne dind8
		rjmp dinde
dind8:	inc reg1
		cpi reg1, 5
		brlo dind1
		ldi reg1, 1		
dind1:	sts lednum, reg1
		cpi reg1, 1
		brne dind2
		sbi portd, 3
		lds tmp, seg1buf
		rcall txreg
		cbi porta, 4
		rjmp dinde		
dind2:	cpi reg1, 2
		brne dind3
		sbi porta, 4
		lds tmp, seg2buf
		rcall txreg
		cbi porta, 2
		rjmp dinde		
dind3:	cpi reg1, 3
		brne dind4
		sbi porta, 2
		lds tmp, seg3buf
		rcall txreg
		cbi porta, 0
		rjmp dinde
dind4:	sbi porta, 0
		lds tmp, fpledbuf
		rcall txreg
		cbi portd, 3
		rjmp dinde	
dinde:	pop reg1
		ret
		
.equ	lednum = $115
.equ	seg1buf = $116
.equ	seg2buf = $117
.equ	seg3buf = $118
.equ	fpledbuf = $119
;.equ	fpdimmlevel = $10f;äàíà ïåðåì³ííà çàäàºòüñÿ çàäàºòüñÿ â MAIN


txreg:	push reg1
		push reg2
		ldi reg1, 0
txreg3:	lsl tmp
		brcs txreg1
		cbi porta, 6
		rjmp txreg2
txreg1:	sbi porta, 6
txreg2:	rcall txregdel
		sbi porta, 3
		rcall txregdel	
		cbi porta, 3
		rcall txregdel
		inc reg1
		cpi reg1, 8
		brne txreg3	
		sbi porta, 5
		rcall txregdel	
		cbi porta, 5
		rcall txregdel
		pop reg2
		pop reg1
		ret

txregdel:ldi reg2, 4	
txregdel1:dec reg2
		brne txregdel1
		ret		

startdind:ldi tmp, 1
		sts lednum, tmp
		ldi tmp, 255
		sts seg1buf, tmp		
		sts seg2buf, tmp		
		sts seg3buf, tmp
		ldi tmp, 0b11111101
		sts fpledbuf, tmp
		cbi portd, 6
fpdimmadj:push zl		;âñòàíîâëåííÿ ÿñêðàâîñò³ ïåðåäíüî¿ ïàíåë³ 0...5
		push zh
		lds tmp, fpdimmlevel
		ldi zh, high(2*dbfpdimm)
		ldi zl, low(2*dbfpdimm)
		add zl, tmp
		clr tmp
		adc zh, tmp
		lpm tmp, z
		out ocr2, tmp
		pop zh
		pop zl
		ret	

stopdind:ldi tmp, 255
		sts lednum, tmp
		sbi portd, 6
		cbi porta, 4
		cbi porta, 2
		cbi porta, 0
		cbi portd, 3
		cbi porta, 3
		cbi porta, 5
		cbi porta, 6
		ret

dbfpdimm:
.db		0,170,180,194,209,228,5,0

;_____________________________________________ Keyboard Control____________________________________________________________________________________________

keyask:	push reg1	;ï³äïðîãðàìà îïèòóâàííÿ êëàâ³àòóðè
		push reg2

		ldi reg1, 0
		in tmp, pinc
		sbrs tmp, 7
		ldi reg1, 1
		in tmp, pina
		sbrs tmp, 7
		ldi reg1, 2
		lds tmp, ping
		sbrs tmp, 2
		ldi reg1, 3
		in tmp, pinc
		sbrs tmp, 5
		ldi reg1, 4
		in tmp, pinc
		sbrs tmp, 6
		ldi reg1, 5
		in tmp, pinc
		sbrs tmp, 4
		ldi reg1, 6

		lds tmp, key
		cpi tmp, 0	;ÿêùî íóëü òî íà ïåðåâ³ðêó íàòèñêàííÿ
		breq keyask1
		cpi tmp, 100;ÿêùî 100 òî íà ïåðåâ³ðêó â³äïóñêàííÿ êëàâ³ø³ àáî îáðîáêó ìóëüòèïðåñó
		brsh keyask3
		rjmp keyaske;ÿêùî í³, çíà÷èòü íàòèñêàííÿ íå îáðîáëåíå - íà âèõ³ä

keyask3:cpi reg1, 0;ïåðåâ³ðêà ÷è íàòèñíóòà áóäü ÿêà êëàâ³øà
		breq keyask4
		cpi reg1, 5 ;ÿêùî íàòèñíóòà, òî ïåðåâ³ðêà ÷è äàíà êëàâ³øà ï³äïàëàº ï³ä ïåðåâ³ðêó ìóëüòèïðåñó
		brsh keyask31
		rjmp keyask5		
keyask31:lds tmp, keytmp
		cp reg1, tmp	;ïåðåâ³ðêà ÷è íàòèñíóòà êë â³äïîâ³äàº ïîïåðåäíüî íàòèñíóò³é
		brne keyask5	
		lds reg2, keymultip ;ÿêùîæ â³äïîâ³äàº, òî...
		inc reg2
		cpi reg2, 255
		brne keyask32
		ldi tmp, 0
		sts key, tmp
		sts keycountl, tmp
		ldi reg2, 210
keyask32:sts keymultip, reg2
		rjmp keyaske

keyask5:ldi tmp, 0 ;ÿêùî íàòèñíóòà íå ÌÏ êëàâ. òî îáíóëþºòüñÿ ë³÷èëüíèê ³ íà âèõ³ä
		sts keycountl, tmp
		rjmp keyaske

keyask4:sts keymultip, reg1;ÿêùî íåíàòèñíóòà òî ïåðåâ³ðêà 10 ðàç³â ³ îáíóëåííÿ
		lds reg2, keycountl
		inc reg2
		cpi reg2, 20
		brlo keyask41
		sts key, reg1
		sts keycountl, reg1
		rjmp keyaske
keyask41:sts keycountl, reg2
		rjmp keyaske

keyask1:cpi reg1, 0	;ïåðåâ³ðêà ÷è êëàâ³øà íå áóëà â³ääïóùåíà, ÿêùî òàê î÷èñòêà ë³÷èëüíèêà ìóëüòèïðåñó
		brne keyask11
		sts keymultip, reg1
keyask11:lds tmp, keytmp ;ïåðåâ³ðêà íà ôàêò íàòèñêàííÿ êëàâ³ø³
		cp reg1, tmp
		breq keyask2
		sts keytmp, reg1
		ldi tmp, 0
		sts keycountl, tmp
		sts keycounth, tmp
		rjmp keyaske
keyask2:lds reg1, keycountl
		lds reg2, keycounth
		inc reg1
		cpi tmp, 4
		breq keyask21
		cpi reg1, 20
		brne keyask22
		sts key, tmp
		ldi reg1, 0
		ldi reg2, 0		
		rjmp keyask22
keyask21:cpi reg1, 240
		brne keyask22
		ldi reg1, 0
		inc reg2
		cpi reg2, 3
		brne keyask22
		sts key, tmp
		ldi reg1, 0
		ldi reg2, 0		
keyask22:sts keycountl, reg1
		sts keycounth, reg2
keyaske:pop reg2
		pop reg1
		ret
		
.equ	key = $110
.equ	keytmp = $111
.equ	keycountl = $112
.equ	keycounth = $113
.equ	keymultip = $114
;1 - ok
;2 - back
;3 - info+
;4 - mode
;5 - up
;6 - down
startkey:ldi tmp, 0	;çàïóñê ïðîöåñó îïèòóâàííÿ êëàâ³àòóðè		
		sts keytmp, tmp
		sts keycountl, tmp
		sts keycounth, tmp
		sts keymultip, tmp
		sts key, tmp
		ret
;________________________________________________ LCD Control____________________________________________________________________________________________
;lcdblonint:sbi portb, 7		;Timer3 overflow
;		reti
;
;lcdbloffint:cbi portb, 7	;Timer3 compare match
;		reti

startlcd:cbi portd, 7 ;Ââ³ìêíåííÿ/ïåðåçàïóñê äèñïëåÿ
		rcall ini4b
		rcall lcdbias_startpwm
		ret

stoplcd:sbi portd, 7 ;Âèìêíåííÿ äèñïëåÿ
		ldi tmp, 0
		rcall lcdbit
		cbi portc, 3
		ret

lcdbias_startpwm:		;çàïóñê øèì ìîäóëÿòîðà ðåãóëþâàííÿ êîíòðàñíîñò³ äèñïëåÿ
		ldi tmp, 0b01101001
		out tccr0, tmp
lcdbiasadj:push zl		;âñòàíîâëåííÿ êîíòðàñíîñò³ äèñïëåÿ 1...9
		push zh
		lds tmp, lcdcontrast
		ldi zh, high(2*dblcdcont)
		ldi zl, low(2*dblcdcont)
		add zl, tmp
		clr tmp
		adc zh, tmp
		lpm tmp, z		
		out ocr0, tmp
		pop zh
		pop zl
		ret

dblcdcont:;1 2  3  4  5  6  7  8  9
.db		0,86,83,79,73,64,56,50,45,40

lcdblon:;ldi tmp, 0b0000001	;ââ³ìêíåííÿ ï³äñâ³òêè äèñïëåÿ			
		;sts tccr3b, tmp		
		;ldi tmp, 0b0011000
		;sts etimsk, tmp
;lcdbladj:push zl		;âñòàíîâëåííÿ ÿñêðàâîñò³ ï³äñâ³òêè 1...10
;		push zh
;		lds tmp, lcdbllevel
;		ldi zh, high(2*dblcdbl)
;		ldi zl, low(2*dblcdbl)
;		add zl, tmp
;		clr tmp
;		adc zh, tmp
;		lpm tmp, z		
;		sts ocr3ah, tmp
;		ldi tmp, 254
;		sts ocr3al, tmp
;		pop zh
;		pop zl
		sbi portb, 7
		ret
				
lcdbloff:;ldi tmp, 0b0000000	;âèìêíåííÿ ï³äñâ³òêè äèñïëåÿ			
		;sts tccr3b, tmp
		;nop
		;nop
		cbi portb, 7
		ret

;dblcdbl:
;.db		0,10,21,34,48,64,84,107,138,181,255,0
			
ini4b:	push reg7	;ï³äïðîãðàìà ³í³ö³àë³çàö³¿ äèñïëåÿ
		push reg8
		ldi tmp, 200
ini41:	rcall delcd2		
		dec tmp
		brne ini41

		ldi lcdbuf, 0b00000011
		mov tmp, lcdbuf
		rcall lcdbit
		cbi portc,3
		rcall delcd1		
		rcall strob
		rcall delcd2
		rcall delcd2
		rcall delcd2

		ldi lcdbuf, 0b00000011
		mov tmp, lcdbuf
		rcall lcdbit
		cbi portc,3
		rcall delcd1		
		rcall strob
		rcall delcd2

		ldi lcdbuf, 0b00000010
		mov tmp, lcdbuf
		rcall lcdbit
		cbi portc,3
		rcall delcd1		
		rcall strob
		rcall delcd2
		
		ldi lcdbuf, 0b00001100
		rcall lcdcm
		ldi lcdbuf, 0b00000001
		rcall lcdcm
		rcall delcd2
		rcall delcd2
		ldi lcdbuf, 0b00000110
		rcall lcdcm
		pop reg8
		pop reg7
		ret
				
lcdcm:	push reg7
		mov tmp, lcdbuf
		swap tmp
		andi tmp, 0b00001111
		rcall lcdbit
		cbi portc,3
		rcall delcd1		
		rcall strob
		mov tmp, lcdbuf
		andi tmp, 0b00001111
		rcall lcdbit
		cbi portc,3
		rcall delcd1
		rcall strob
		pop reg7
		ret

lcdda:	push reg7
		mov tmp, lcdbuf
		swap tmp
		andi tmp, 0b00001111
		rcall lcdbit
		sbi portc,3
		rcall delcd1
		rcall strob
		mov tmp, lcdbuf
		andi tmp, 0b00001111
		rcall lcdbit
		sbi portc,3
		rcall delcd1		
		rcall strob
		pop reg7
		ret 

lcdbit:	push reg7
		ror tmp		;Ïîá³òîâå âèâåäåííÿ ³íôîðìàö³¿ íà øèíó äèñïëåÿ
		brcs lcdbit1
		cbi portc, 1			
		rjmp lcdbit2
lcdbit1:sbi portc, 1
lcdbit2:ror tmp		;á³ò 2
		brcs lcdbit21
		cbi portc, 0
		rjmp lcdbit3
lcdbit21:sbi portc, 0
lcdbit3:lds reg7, portg		
		ror tmp		;á³ò 3
		brcs lcdbit31	
		clt
		bld reg7, 1				
		rjmp lcdbit4
lcdbit31:set
		bld reg7, 1	
lcdbit4:ror tmp		;á³ò 4
		brcs lcdbit41
		clt
		bld reg7, 0
		sts portg, reg7
		pop reg7
		ret
lcdbit41:set
		bld reg7, 0	
		sts portg, reg7
		pop reg7
		ret
		
strob:	sbi portc,2
		rcall delcd1
		cbi portc,2
		rcall delcd
		ret

delcd1:	ldi reg7, 12  ;4us
decd11:	dec reg7
		brne decd11
		ret 
delcd:	ldi reg7, 250  ;100us
decd1:	dec reg7
		brne decd1
		ret
delcd2:	ldi reg8, 32  ;2,1ms
decd22:	ldi reg7, 180
decd21:	dec reg7
		brne decd21
		dec reg8
		brne decd22
		ret

;.equ	lcdcontrast = $100 ;äàíà ïåðåì³ííà çàäàºòüñÿ çàäàºòüñÿ â MAIN
.equ	lcdbllevel = $101
