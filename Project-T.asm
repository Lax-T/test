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
						;1 й регістр помилок/
.def	gereg1 = r5		;0 - DS18B20 помилка CRC, 1 - DS18B20 нема відповіді від датчика
						;2 - DS18B20 КЗ лінії датчика, 3 - (1) дані дійсні (без даного біту програми ігнорують температуру)
						;4 - помилка звязку з еепром, 5 - помилка запису еепром, 6 - розряд батареї RTC
						;7 - готовніть системи до роботи після запуску/перезапуску
.equ	dscrce = 0
.equ	dscome = 1		
.equ	dspwdn = 2
.equ	dsdtv = 3
.equ	eecerr = 4
.equ	eewerr = 5
.equ	rtcerr = 6
.equ	sysrdy = 7
						;2 й регістр помилок ()
.def	gereg2 = r8

.equ	triacer = 0		;0 - несправність симістора
.equ	fanproter = 1	;1 - несправність кола захисту вентилятора (запобіжник/перегрів котла)
.equ	tfaller = 6		;6 - попередження про падіння температури
.equ	triseer = 7		;7 - аварійний ріст температури

						;регістр подій
.def	eventreg = r9

.equ	tfrrestore = 0	;прапорець відновлення росту/падіння температури
.equ	erractive = 1	;на даний момент є активна несправність/попередження (визначає точку переходу кнопок ОК і I+)
.equ	gmodwork = 2	;перехід в режим розпалу котла
.equ	gmodstby = 3	;перехід в режим гасіння котла
.equ	passlock = 4	;блокування підбору пароля
.equ	logclear = 5	;очищення логу температури
.equ	poweron = 6		;старт приладу

.def	toutreg = r6	;Прапорці переривань слотів по таймауту
.equ	slot1tint = 0
.equ	slot2tint = 1
.equ	slot3tint = 2
.equ	slot4tint = 3
.equ	slot5tint = 4
.equ	slot6tint = 5
.equ	slot7tint = 6
.equ	slot8tint = 7

.def	toutreg2 = r7	;Прапорці переривань слотів по таймауту 2
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
		
									;конфігураційні константи
	
	;	ldi tmp, 0
	;	mov gereg1, tmp			;конфігурація регістра помилок
	;	mov gereg2, tmp			;конфігурація регістра помилок 2
	;	mov eventreg, tmp		;конфігурація регістра подій
	;	ldi tmp, 0
	;	sts lcdsit, tmp	
	;;	ldi tmp, 0
	;	sts menusit, tmp
		ldi tmp, 0				;конфігурація програми контролю запуску
		sts powerupstep, tmp
		sts powerupcount, tmp
		sts powerupevent, tmp		
		call starttik ;старт системного таймера
		sei

		ldi tmp, 2 ;через 200мс виклик підпрограми запуску
		sts slotr2, tmp

	;	call searchle	
	;	call searchll		
	;	call readsett				
								;старт процесів
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
					
	;	ldi tmp, 10;запуск групи секундних функцій
	;	sts slotr12, tmp		

	;	ldi tmp, 6;запуск групи функцій управління передньою панеллю/дисплеєм
	;	sts slotr11, tmp		

	;	ldi tmp, 5;запуск підпрограми управління насосом
	;	sts slotr7, tmp

	;	ldi tmp, 10;запуск підпрограми управління вентилятором
	;	sts slotr6, tmp

	;	ldi tmp, 7;запуск підпрограми контролю порогів
	;	sts slotr8, tmp

	;	ldi tmp, 12;запуск підпрограми запису логу подій
	;	sts slotr10, tmp
			
;_________________________________________________ SYSDISP ______________________________________________________________
								;Диспетчер виконання основного циклу
sysdisp:bst toutreg, slot1tint	;слот 1	
		brts sysdisp1_1
		rjmp sysdisp2
sysdisp1_1:rcall slot1
		clt
		bld toutreg, slot1tint
		rjmp sysdisp
sysdisp2:bst toutreg, slot2tint	;слот 2
		brts sysdisp21
		rjmp sysdisp3
sysdisp21:rcall slot2
		clt
		bld toutreg, slot2tint
		rjmp sysdisp		
sysdisp3:bst toutreg, slot3tint	;слот 3
		brts sysdisp31
		bst gereg1, sysrdy ;якщо не встановлено прапорець готовності системи виконуються тільки перші 3 слоти
		brtc sysdisp
		rjmp sysdisp4
sysdisp31:rcall slot3
		clt
		bld toutreg, slot3tint
		rjmp sysdisp		
sysdisp4:bst toutreg, slot4tint	;слот 4
		brts sysdisp41
		rjmp sysdisp5
sysdisp41:rcall slot4
		clt
		bld toutreg, slot4tint
		rjmp sysdisp		
sysdisp5:bst toutreg, slot5tint	;слот 5		меню
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
sysdisp6:bst toutreg, slot6tint	;слот 6
		brts sysdisp61
		rjmp sysdisp7
sysdisp61:rcall slot6
		clt
		bld toutreg, slot6tint
		rjmp sysdisp		
sysdisp7:bst toutreg, slot7tint	;слот 7
		brts sysdisp71
		rjmp sysdisp8
sysdisp71:rcall slot7
		clt
		bld toutreg, slot7tint
		rjmp sysdisp		
sysdisp8:bst toutreg, slot8tint	;слот 8
		brts sysdisp81
		rjmp sysdisp9
sysdisp81:rcall slot8
		clt
		bld toutreg, slot8tint
		rjmp sysdisp

sysdisp9:bst toutreg2, slot9tint	;слот 9
		brts sysdisp91
		rjmp sysdisp10
sysdisp91:rcall slot9
		clt
		bld toutreg2, slot9tint
		rjmp sysdisp

sysdisp10:bst toutreg2, slot10tint	;слот 10
		brts sysdisp101
		rjmp sysdisp11
sysdisp101:rcall slot10
		clt
		bld toutreg2, slot10tint
		rjmp sysdisp

sysdisp11:bst toutreg2, slot11tint	;слот 11
		brts sysdisp111
		rjmp sysdisp12
sysdisp111:rcall slot11
		clt
		bld toutreg2, slot11tint
		rjmp sysdisp

sysdisp12:bst toutreg2, slot12tint	;слот 12
		brts sysdisp121
		rjmp sysdisp
sysdisp121:rcall slot12
		clt
		bld toutreg2, slot12tint
		rjmp sysdisp
		
.INCLUDE "main.inc"
.INCLUDE "menu.inc"
.INCLUDE "lcd.inc"

;_________________________________________ переривання пропажі живлення ___________________________________________________________________________

powerdnint:push tmp		
		call stoplcd	;негайне відключення споживачів
		call lcdbloff
		call stopdind
		call beepstop	
		call stopdscomm
		set
		bld toutreg, slot3tint	;встановлення прапорця для виклику підрограми завершення відключення
		ldi tmp, 0b00000000
		out eimsk, tmp
		pop tmp
		reti

fpowerdnintst:ldi tmp, 0b00110000 ;дозвіл переривань
		out eicrb, tmp
		ldi tmp, 0b01000000
		out eifr, tmp
		ldi tmp, 0b01000000
		out eimsk, tmp
		ret
		
.equ	powerdncount = $263
;_________________________________________________ SYSTIK ______________________________________________________________

tiktimer:push tmp			;Переривання таймера 1
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
		ldi xh, high(slotr1) ; Диспетчер часових інтервалів
		ldi xl, low(slotr1)
		ldi reg1, 0
tiktim2:ld reg2, x
		cpi reg2, 0
		breq tiktim1
		dec reg2
		cpi reg2, 0
		breq tiktim3
		rjmp tiktim1
tiktim3:ldi zh, high(tiktimxx) ; початковий адрес мітки множиться на номер слота і отримується адрес
		ldi zl, low(tiktimxx)	;потрібної інструкції BLD (встановлення потрібного біта переривання)
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

starttik:push reg1	;запуск системного таймера
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
readsett:push reg1	;завантаження налаштувань з пмяті
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
readsett1:lds tmp, soundmod;в якості виключення перенос біту викл. звуку в спец регістр BEEPFREG
		com tmp;інверсія біта
		bst tmp, 0
		lds tmp, beepfreg
		bld tmp, 0
		sts beepfreg, tmp
		pop zh
		pop zl
		pop reg1
		ret

clearevent:push reg1		;підпрограма очищення памяті подій
		push reg2
		push reg3
		push reg4
		push r0
		push r1
		ldi tmp, 0		;збереження в еепром номера останньої комірки старого циклу
		sts wordadrh, tmp ;ця комірка буде стартовою для нового циклу (з неї програма при старті починає сканування)
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
		lds tmp, timeyear	;підготовка данних першої події
		sts memdata5, tmp
		lds tmp, timemonth
		sts memdata4, tmp
		lds tmp, timedate
		sts memdata3, tmp
		lds tmp, timemin
		sts memdata2, tmp
		lds tmp, timehour
		sts memdata1, tmp
		ldi tmp, 6		;код події
		sts memdata6, tmp
		lds reg1, lastevckll	;циклічний номер старого логу інкрементаваний на 3 буде початковим для нового
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
		ldi reg4, 0		;лічильник записаних слотів - буде записано 2 слоти з однаковими данними і циклічним номером
clearevent4:ldi tmp, 9		;обрахування абсолютного адреса в памяті, де 9 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;додавання зміщення
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp					
		ldi reg3, 0		;лічильник записаних байтів
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)				
clearevent2:sts wordadrl, reg1	;запис в память 9 байтів, щоб сформувати 1й слот нового циклу і записати подію стирання
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
		lds reg1, lastevnuml	;інкремент номера слота і повторний запис тих самих данних (в рам залишається старий номер)
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
				
clearlog:push reg1		;підпрограма очищення логу температури
		push reg2
		push reg3
		push reg4
		push r0
		push r1
		ldi tmp, 0		;збереження в еепром номера останньої комірки старого циклу
		sts wordadrh, tmp ;ця комірка буде стартовою для нового циклу (з неї програма при старті починає сканування)
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
		lds tmp, timeyear	;підготовка данних першої події
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
clearlog02:sts memdata5, tmp ;темература, якщо недоступно то FF (-)
		lds reg1, lastlogckll	;циклічний номер старого логу інкрементаваний на 3 буде початковим для нового
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
		ldi reg4, 0		;лічильник записаних слотів - буде записано 2 слоти з однаковими данними і циклічним номером
clearlog4:ldi tmp, 7	;обрахування абсолютного адреса в памяті, де 7 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;додавання зміщення
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp					
		ldi reg3, 0		;лічильник записаних байтів
		ldi zh, high(memdata1)
		ldi zl, low(memdata1)				
clearlog2:sts wordadrl, reg1	;запис в память 7 байтів, щоб сформувати 1й слот нового циклу і записати подію стирання
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
		lds reg1, lastlognuml	;інкремент номера слота і повторний запис тих самих данних (в рам залишається старий номер)
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
		
clearsett:push reg1		;підпрограма скидання налаштувань на завод		
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

dbsett:								;набір заводських налаштувань
.db		10,162,247,75,70,75,5,0,1,0	;0-9
.db		1,60,45,1,1,0,5,90,1,0		;10-19
.db		5,65,0,15,7,4,2,5,5,7	;20-29

fullerase:push reg1		;підпрограма повної очистки памяті
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

dbfullerase:						;набір заводських налаштувань
.db		10,162,247,75,70,75,5,0,1,0	;0-9
.db		1,60,45,1,1,0,5,90,1,0		;10-19
.db		5,65,0,15,7,4,2,5,5,7	;20-29
.db		0,0,0,0,0,0,0,0,0,1		;30-39	
.db		0,1,0,0		;40-43	

searchle:push reg1	;пошук номера останньої записаної події
		push reg2
		push reg3
		push reg4
		push reg5
		push reg6
		ldi tmp, 0		;завантаження номера слота з якого почати сканування
		sts wordadrh, tmp 
		ldi tmp, eelastevenuml
		sts wordadrl, tmp		
		call eeread
		lds reg1, i2cdata	
		ldi tmp, eelastevenumh
		sts wordadrl, tmp		
		call eeread
		lds reg2, i2cdata
		cpi reg2, high(501);перевірка чи більше 500б якщо так то встановлюється 1
		brlo searchle0
		cpi reg1, low(501)
		brlo searchle0
		ldi reg1, 1
		ldi reg2, 0		
searchle0:sts lastevnuml, reg1
		sts lastevnumh, reg2
		ldi tmp, 0
		sts evdispl, tmp	;зміщення задається 0
		sts evdisph, tmp
		rcall readevent		;зчитується запис з №1
		lds reg3, memdata9	;завантажуються значення lastevckll, як опорне
		lds reg4, memdata8	;завантажуються значення lastevcklh, як опорне
searchle3:mov reg5, reg1	;номер слота копіюється
		mov reg6, reg2
		ldi tmp, 1
		add reg5, tmp		;інкрементується номер слота
		ldi tmp, 0
		adc reg6, tmp		
		cpi reg6, high(501)	;перевірка чи номер слота досягнув кінця буфера
		brlo searchle1
		cpi reg5, low(501)
		brlo searchle1
		ldi reg5, 1			;якщо так то завантажується №1
		ldi reg6, 0
searchle1:sts lastevnuml, reg5
		sts lastevnumh, reg6
		rcall readevent
		lds reg5, memdata9	;зчитується циклічний номер наступного слота
		lds reg6, memdata8
		subi reg5, 1		;зменшується на 1
		sbci reg6, 0
		cp reg5, reg3		;порівнюється з номером попереднього слота
		brne searchle2
		cp reg6, reg4
		brne searchle2
		lds reg1, lastevnuml	;якщо рівні то цикл повторюється, данні останнього слота приймаються як опорні
		lds reg2, lastevnumh
		lds reg3, memdata9	
		lds reg4, memdata8
		rjmp searchle3
searchle2:sts lastevnuml, reg1	;якщо ні то попередній слот був останнім і його данні приймаються як опорні
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

searchll:push reg1	;пошук номера останного логу темпеератури
		push reg2
		push reg3
		push reg4
		push reg5
		push reg6
		ldi tmp, 0		;завантаження номера слота з якого почати сканування
		sts wordadrh, tmp 
		ldi tmp, eelastlognuml
		sts wordadrl, tmp		
		call eeread
		lds reg1, i2cdata	
		ldi tmp, eelastlognumh
		sts wordadrl, tmp		
		call eeread
		lds reg2, i2cdata
		cpi reg2, high(745);перевірка чи більше 745, якщо так то встановлюється 1
		brlo searchll0
		cpi reg1, low(745)
		brlo searchll0
		ldi reg1, 1
		ldi reg2, 0		
searchll0:sts lastlognuml, reg1
		sts lastlognumh, reg2
		ldi tmp, 0
		sts logdispl, tmp	;зміщення задається 0
		sts logdisph, tmp
		rcall readlog
		lds reg3, memdata7	;завантажуються значення lastlogckll, як опорне
		lds reg4, memdata6	;завантажуються значення lastlogcklh, як опорне
searchll3:mov reg5, reg1
		mov reg6, reg2
		ldi tmp, 1
		add reg5, tmp
		ldi tmp, 0
		adc reg6, tmp
		cpi reg6, high(745)	;перевірка чи номер слота досягнув кінця буфера
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

storeevent:push reg1	;збереження події
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastevnuml ;інкрементування номера слота останнього запису
		lds reg2, lastevnumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		cpi reg2, high(501)	;перевірка чи номер слота досягнув кінця буфера
		brlo storeeve1
		cpi reg1, low(501)
		brlo storeeve1
		ldi reg1, 1
		ldi reg2, 0
storeeve1:sts lastevnuml, reg1	;оновлення номера останнього запису
		sts lastevnumh, reg2
		lds reg3, lastevckll	;інкремент та збереження циклічного номера
		lds reg4, lastevcklh
		ldi tmp, 1
		add reg3, tmp
		ldi tmp, 0
		adc reg4, tmp
		sts lastevckll, reg3
		sts memdata9, reg3
		sts lastevcklh, reg4
		sts memdata8, reg4
		ldi tmp, 9		;обрахування абсолютного адреса в памяті, де 9 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;додавання зміщення
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		ldi reg3, 0		;запис в память 9 байтів слота
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

storelog:push reg1	;збереження логу температури
		push reg2
		push reg3
		push reg4
		push r1
		push r0
		push zh
		push zl
		lds reg1, lastlognuml ;інкрементування номера слота останнього запису
		lds reg2, lastlognumh
		ldi tmp, 1
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp
		cpi reg2, high(745)	;перевірка чи номер слота досягнув кінця буфера
		brlo storelog1
		cpi reg1, low(745)
		brlo storelog1
		ldi reg1, 1
		ldi reg2, 0
storelog1:sts lastlognuml, reg1	;оновлення номера останнього запису
		sts lastlognumh, reg2
		lds reg3, lastlogckll	;інкремент та збереження циклічного номера
		lds reg4, lastlogcklh
		ldi tmp, 1
		add reg3, tmp
		ldi tmp, 0
		adc reg4, tmp
		sts lastlogckll, reg3
		sts memdata7, reg3
		sts lastlogcklh, reg4
		sts memdata6, reg4
		ldi tmp, 7		;обрахування абсолютного адреса в памяті, де 7 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;додавання зміщення
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp
		ldi reg3, 0		;запис в память 7 байтів слота
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

readevent:push reg1		;зчитування запису з логу подій
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
		cp reg2, reg4		;обрахування зміщення
		brlo readeve11
		cp reg4, reg2
		brlo readeve15
		cp reg3, reg1
		brsh readeve11
readeve15:sub reg1, reg3	;якщо номер запису більший за зміщення
		sbc reg2, reg4
		rjmp readeve2
readeve11:sub reg3, reg1	;якщо номер запису менший за зміщення
		sbc reg4, reg2
		ldi reg1, low(500)
		ldi reg2, high(500)
		sub reg1, reg3
		sbc reg2, reg4
readeve2:ldi tmp, 9		;обрахування абсолютного адреса в памяті, де 9 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, 200	;додавання зміщення
		add reg1, tmp
		ldi tmp, 0
		adc reg2, tmp	
		ldi reg3, 0		;зчитування з памяті 9 байтів слота
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

readlog:push reg1	;зчитування запису з логу температури
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
		cp reg2, reg4		;обрахування зміщення
		brlo readlog11
		cp reg4, reg2
		brlo readlog15
		cp reg3, reg1
		brsh readlog11
readlog15:sub reg1, reg3	;якщо номер запису більший за зміщення
		sbc reg2, reg4
		rjmp readlog2
readlog11:sub reg3, reg1	;якщо номер запису менший за зміщення
		sbc reg4, reg2
		ldi reg1, low(744)
		ldi reg2, high(744)
		sub reg1, reg3
		sbc reg2, reg4
readlog2:ldi tmp, 7		;обрахування абсолютного адреса в памяті, де 7 розмір одного слота
		mul reg2, tmp
		mov reg2, r0
		mul reg1, tmp
		mov reg1, r0
		add reg2, r1
		ldi tmp, low(4720)	;додавання зміщення
		add reg1, tmp
		ldi tmp, high(4720)
		adc reg2, tmp	
		ldi reg3, 0		;зчитування з памяті 7 байтів слота
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
.equ	gmemadr = $16c	;адрес для загальних данних 0-199 EEPRON, 200 коректуюча константа RTC, 201-250 NVRAM
.equ	memdata1 = $16d ;рік			/рік			/загальні дані EEPROM/NVRAM
.equ	memdata2 = $16e	;місяць			/місяць
.equ	memdata3 = $16f	;день			/день
.equ	memdata4 = $170	;година			/година	
.equ	memdata5 = $171	;хвилина		/температура
.equ	memdata6 = $172	;код події		/циклічний номер
.equ	memdata7 = $173	;опційні дані	/циклічний номер
.equ	memdata8 = $174	;циклічний номер
.equ	memdata9 = $175	;циклічний номер

;_________________________________________________ RTC/Calendar ____________________________________________________________________________

gettime:push reg1		;отримати час від RTC
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

settime:push reg1		;записати час в RTC
		push zh
		push zl
		rcall dectobcd
		rcall i2cstart
		ldi tmp, 0b11010000
		sts i2cbuf, tmp
		rcall i2ctx
		ldi tmp, 0
		sts i2cbuf, tmp		;встановити адрес 1 ячейки
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

bcdtodec:lds tmp, rtcbuf1		;Программа для перетворення BCD данних від RTC в DEC.
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

bcdtdsp:push reg1				;Субпрограмма перетворення BCD числа в десяткове
		push reg2				;використовується регістр TMP
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

dectobcd:lds tmp, timesec	;Программа для перетворення DEC в BCD для настройки RTC
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

dectbsp:push reg1				;Субпрограмма перетворення десяткового числа в BCD
		ldi reg1, 0				;використовується регістр TMP
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
		ldi reg1, 0	;лічильник спроб звязку
		ldi reg2, 0	;лічильник спроб запису		 
eewrite12:rcall i2cstart
		ldi tmp, 0b10100000
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, eefreg
		bst tmp, 0
		brtc eewrite2	;перевірка чи еепром видала ацк
		rcall i2cstop	;якщо ні то стоп
		inc reg1	;якщо ні то інкремент лічильника спроб звязку
		cpi reg1, 5		;перевірка чи досягнуто ліміту спроб звязку
		brlo eewrite11
		set
		bld gereg1, eecerr	;якщо ліміт досягнуто, то виставляється біт помилки
		rjmp eewrite9
eewrite11:rcall del1ms	;якщо ліміт не досягнуто, затримка 1 мс і повторна спроба
		rjmp eewrite12
eewrite2:ldi reg1, 0	;скидання лічильника спроб звязку
		clt
		bld gereg1, eecerr ;скидання прапорця спроб звязку
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
		rcall del6ms	;очікування на процедуру запису		
		lds reg1, i2cdata
		rcall eeread
		bst gereg1, eecerr ;перевірка чи після зчитування встановився біт помилки звязку
		brts eewrite13
		lds tmp, i2cdata
		cp tmp, reg1	
		brne eewrite13	;якщо данні записані правельно то вихід з процедури запису
		clt
		bld gereg1, eewerr	;скидання біту помилки запису
		rjmp eewrite9
eewrite13:inc reg2
		cpi reg2, 5
		brsh eewrite4	;перевірка чи досягнути ліміт спроб запису
		rjmp eewrite12	;якщо ні то повторна спроба		
eewrite4:set
		bld gereg1, eewerr	;якщо так то встановлюється біт помилки запису		
eewrite9:pop reg2
		pop reg1
		ret

eeread:	push reg1
		ldi reg1, 0	;лічильник спроб звязку		 
eeread12:rcall i2cstart
		ldi tmp, 0b10100000
		sts i2cbuf, tmp
		rcall i2ctx
		lds tmp, eefreg
		bst tmp, 0
		brtc eeread2	;перевірка чи еепром видала ацк
		rcall i2cstop
		inc reg1	;якщо ні то інкремент лічильника спроб звязку
		cpi reg1, 6		;перевірка чи досягнуто ліміту спроб звязку
		brlo eeread11
		set
		bld gereg1, eecerr	;якщо ліміт досягнуто, то виставляється біт помилки звязку
		rjmp eeread9
eeread11:rcall del1ms	;якщо ліміт не досягнуто, затримка 1 мс і повторна спроба
		rjmp eeread12
eeread2:clt
		bld gereg1, eecerr	;скидання біту помилки звязку
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
.equ	eefreg = $13e	;регістр прапорців шини I2C  , 0 - Ацк слейва

;_____________________________________________ I2C Protocol ____________________________________________________________________________

i2cstart:lds tmp, ddrg		;початкова конфігурація порта/старт
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


i2cstop:rcall sbiscl	;стоп
		rcall deli2c
		rcall sbisda
		rcall deli2c
		ret

i2ctx:	push reg6	;відправка одного байта, обмін через TMP, стан ACK в біті T
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

i2crx:	push reg6	;отримання одного байта, обмін через TMP, ACK не викликається
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

i2csack:rcall sbisda	;ACK, відповідь слейва мастеру
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

i2cmack:rcall cbisda	;ACK, відповідь мастера слейву
		rcall deli2c
		rcall sbiscl
		rcall deli2c
		rcall cbiscl
		rcall deli2c
		ret

i2cmnack:rcall sbisda	;NACK, відповідь мастера слейву
		rcall deli2c
		rcall sbiscl
		rcall deli2c
		rcall cbiscl
		rcall deli2c
		rcall cbisda
		rcall deli2c
		ret	

deli2c:	push reg8
		ldi reg8, 25		;зменшив з 50 до 25
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

fasttmstart:ldi tmp, 0b00000100	;запуск швидкого таймера
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
		cpi reg1, 255	;якщо 255 виконання заборонено, на вихід
		brne dscomm1
		rjmp dscomme
dscomm1:cpi reg1, 1		;вибір молодшої чи старшої підпрограми
		brne dscomm11
		rjmp dscomm2

dscomm11:cpi reg2, 3	;якщо dscommsteph = 0
		brlo dscomm12	;якщо всі операції з молодшої групи виконані то пропуск тактів до переповнення dscommstepl
		rjmp dscomm1a
dscomm12:mov tmp, reg2
		lsl tmp
		ldi zh, high(2*dwdsdsopl) ;вибір потрібної операції молодшої групи
		ldi zl, low(2*dwdsdsopl)  ;операції молодшої групи дають команду на запуск вимірювання
		add zl, tmp				  ;далі решту молодшої групи та частину старшої пропуск тактів (щоб > 750ms)
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		icall		
dscomm1a:inc reg2		;інкремент номера кроку, якщо переповнення то dscommsteph = 1
		cpi reg2, 255
		brsh dscomm1b
		rjmp dscomm3
dscomm1b:ldi reg2, 0
		ldi reg1, 1
		rjmp dscomm3

dscomm2:cpi reg2, 40	;якщо dscommsteph = 1
		brsh dscomm21	;доки dscommstepl не досягне 40, пропук тактів	
		rjmp dscomm2a
dscomm21:cpi reg2, 53	;якщо більше 52 то пропуск тактів, це прібно для збільшення періода між вимірюваннями (саморозігрів)
		brsh dscomm2a
		mov tmp, reg2
		subi tmp, 40	;віднімається число зміщення - 40, це потрібно для адресації (таким чином формується затримка між групами (>750ms))
		lsl tmp
		ldi zh, high(2*dwdsdsoph) ;вибір потрібної операції старшої групи
		ldi zl, low(2*dwdsdsoph)  ;операції старшої групи зчитують та обробляють результати
		add zl, tmp
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		icall
dscomm2a:inc reg2	;інкремент номера кроку, якщо переповнення то dscommsteph = 0
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
		breq dsproces11	;перевірка чи не встановлені прапорці помилки, якщо ні то нормальна обробка
		ldi tmp, 0
		sts w1dvcount, tmp ;скидання лічильника дійсних даних
		lds reg1, w1ercount
		cpi reg1, 3		;перевірка чи було вже 3 помилки
		brsh dsproces12	
		inc reg1
		sts w1ercount, reg1
		cpi reg1, 3
		brsh dsproces12
		rjmp dsproces3	;якщо ні то просто вихід без обробки
dsproces12:lds tmp, dscommfreg
		bst tmp, 0	;якщо так то копіювання бітів помилок в gereg
		bld gereg1, dscome
		bst tmp, 1
		bld gereg1, dscrce
		bst tmp, 2
		bld gereg1, dspwdn
		clt
		bld gereg1, dsdtv
		rjmp dsproces3
dsproces11:lds tmp, w1dvcount
		cpi tmp, 2		;перше вимірювання ігнорується
		brsh dsproces13	;це потрібно щоб результати першого виміру після помилки або запуску ігнорувалися
		inc tmp
		sts w1dvcount, tmp
		rjmp dsproces3
dsproces13:ldi tmp, 0
		sts w1ercount, tmp	;скидання лічильника помилок
		clt
		bld gereg1, dscome
		bld gereg1, dspwdn
		bld gereg1, dscrce	;скидання прапорців помилок
		set
		bld gereg1, dsdtv	;дані дійсні
		lds reg1, dscommbuf1 ;обробка данних
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
		bld toutreg, slot1tint	;виклик підпрограми переносу данних (слот 1)

 dsproces3:	pop reg2
		pop reg1
		ret				

dbteds:	
.db		0,0,1,1,2,3,3,4,5,5,6,6,7,8,8,9

getcrc8:push xl			;програма розрахунку CRC8
		push xh
		push zl
		push zh
		push reg1
		push reg2
		ldi reg1, 0
		ldi reg2, 0
		ldi xh, high(dscommbuf0)
		ldi xl, low(dscommbuf0)
getcrc81:ld tmp, x+			;байт данних з буфера
		eor reg1, tmp		;ксорим актуальне значення CRC на дані з буфера
		ldi zh, high(2*dbcrc8)
		ldi zl, low(2*dbcrc8)
		add zl, reg1		;отримане значення використовується як індекс
		ldi tmp, 0
		adc zh, tmp
		lpm reg1, z			;з таблиці отримується нове значення CRC
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
getcrc83:bld reg2, 1	;виставляється відповідний біт (CRC правельне/неправельне)
		sts dscommfreg, reg2
		pop reg2
		pop reg1
		pop zh
		pop zl
		pop xh
		pop xl
		ret

dbcrc8:
.db		0,94,188,226,97,63,221,131,194,156,126,32,163,253,31,65	;таблиця для CRC8
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

w1st:	push reg7	;Фрейм ресету, при відсутності відповіді від датчика виставляє 0 біт в sdcommfreg
		push reg8
		cbi ddrb, 6	;для контролю відпускається лінія 1W
		rcall dlw4	;затримка на відновлення лінії
		in tmp, pinb	
		bst tmp, 6	;якщо на піні 0 - лінія закорочена
		brts w1st2
		set
		rjmp w1st3		
w1st2:	clt		
w1st3:	lds tmp, dscommfreg	;встановлюється або очищається біт КЗ датчика
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
w1stex:	lds tmp, dscommfreg	;встановлюється або очищається біт відповіді на ресет датчика
		bld tmp, 0
		sts dscommfreg, tmp
		pop reg8
		pop reg7		
		ret

w1tx:	push reg5	;Фрейм відправки байта, обмін через w1buf
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

w1rx:	push reg5	;Фрейм прийому байта, обмін через w1buf
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
dlw9:	ldi reg8, 20 ;22 змінено на 20
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

stopdscomm:ldi tmp, 255		;якщо 255 то програма обміну з датчиком блокується
		sts dscommsteph, tmp
		cbi portb, 6
		cbi ddrb, 6
		clt
		bld gereg1, dsdtv	;скинути біт що дані від датчика дійсні

		ret

.equ	dscommstepl = $125
.equ	dscommsteph = $126
.equ	dscommfreg = $127	;Регістр прапорців 0 - помилка відповіді від датчика після ресету 1, 1 - помилка CRC8, 2 - КЗ,
.equ	dscommbuf0 = $128
.equ	dscommbuf1 = $129
.equ	dscommbuf2 = $12a
.equ	dscommbuf3 = $12b
.equ	dscommbuf4 = $12c
.equ	dscommbuf5 = $12d
.equ	dscommbuf6 = $12e
.equ	dscommbuf7 = $12f
.equ	dscommcrc = $130
.equ	tempuni = $131	;цілі градусів
.equ	temppar = $132	;десяті градусів
.equ	tempods = $133	;одиниці градусів, поки не використовується - зарезервовано адрес
.equ	tempdes = $134	;десятки градусів, поки не використовується - зарезервовано адрес
.equ	w1buf = $135	;буфер 1wire
.equ	w1ercount = $136 ;рахунок кількості помилок передачі данних, після 3 в gereg1 виставляються біти помилок
.equ	w1dvcount = $137 ;рахунок правельних зчитувань, після другого правельного зчитування дані вважаються дійсими	

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
beepctr1:ldi tmp, 0			;виконання програми кожен 4-й цикл таймера
		sts beepftckl, tmp

		lds reg1, beepnck	;нециклічні звукові сигнали
		lds tmp, beepncktemp
		cp reg1, tmp		;перевірка чи не змінився номер сигналу
		breq beepctr11
		sts beepncktemp, reg1
		ldi tmp, 0
		sts beepnckstep, tmp
		sts beepnckcount, tmp
beepctr11:cpi reg1, 0		;якщо нуль, то сигнал вимкнено
		brne beepctr12
		lds tmp, beepfreg
		clt
		bld tmp, 2
		bld tmp, 3
		sts beepfreg, tmp
		rjmp beepctr2		;перехід до програми циклічних звукових сигналів
beepctr12:lds reg2, beepnckcount
		cpi reg2, 0			;перевірка чи виконаний крок звукової послідовності
		breq beepctr13
		dec reg2
		cpi reg2, 0			;перевірка чи виконаний крок звукової послідовності
		breq beepctr13
		sts beepnckcount, reg2
		rjmp beepctr2
beepctr13:dec reg1
		lsl reg1	;в reg1 зберігається номер сигналу *2		
		ldi zh, high(2*dwbeepnck) ;вибір потрібної бази по номеру сигналу
		ldi zl, low(2*dwbeepnck)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		lds reg1, beepnckstep	;автоматичний інкремент номера кроку
		inc reg1	
		sts beepnckstep, reg1			
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp, z
		cpi tmp, 255	;перевірка чи звукова послідовність завершена
		brne beepctr14
		lds tmp, beepfreg
		clt 
		bld tmp, 2
		bld tmp, 3
		sts beepfreg, tmp
		clr tmp
		sts beepnck, tmp ;оскільки звукова послідовніть відтворена - записується 0
		sts beepnckstep, tmp
		sts beepnckcount, tmp
		rjmp beepctr2
beepctr14:cpi tmp, 100
		brlo beepctr15	;якщо більше 100 то на період часу динамік ввімкнено
		subi tmp, 100	;індикаторне число 100 віднімається
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

beepctr2:lds reg1, beepckl	;циклічні звукові сигнали
		lds tmp, beepckltemp
		cp reg1, tmp		;перевірка чи не змінився номер сигналу
		breq beepctr21
		sts beepckltemp, reg1
		ldi tmp, 0
		sts beepcklstep, tmp
		sts beepcklcount, tmp
beepctr21:cpi reg1, 0		;якщо нуль, то сигнал вимкнено
		brne beepctr22
		lds tmp, beepfreg
		clt
		bld tmp, 4
		sts beepfreg, tmp
		rjmp beepctr3		;перехід до програми зведення
beepctr22:lds reg2, beepcklcount
		cpi reg2, 0			;перевірка чи виконаний крок звукової послідовності
		breq beepctr23
		dec reg2
		cpi reg2, 0			;перевірка чи виконаний крок звукової послідовності
		breq beepctr23
		sts beepcklcount, reg2
		rjmp beepctr3
beepctr23:dec reg1
		lsl reg1	;в reg1 зберігається номер сигналу *2		
		ldi zh, high(2*dwbeepckl) ;вибір потрібної бази по номеру сигналу
		ldi zl, low(2*dwbeepckl)
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm r0, z+
		lpm r1, z
		movw zh:zl,r1:r0
		lds reg1, beepcklstep	;автоматичний інкремент номера кроку
		inc reg1	
		sts beepcklstep, reg1			
		add zl, reg1
		clr tmp
		adc zh, tmp
		lpm tmp, z
		cpi tmp, 255	;перевірка чи звукова послідовність завершена
		brne beepctr24
		clr tmp
		sts beepcklstep, tmp ;звукова послідовніть відтворюється повторно
		sts beepcklcount, tmp
		rjmp beepctr3
beepctr24:cpi tmp, 100
		brlo beepctr25	;якщо більше 100 то на період часу динамік ввімкнено
		subi tmp, 100	;індикаторне число 100 віднімається
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
		brts beepctr35	;якщо нециклічні звукові сигнали приглушені то зразу перехід до циклічних
		bst tmp, 2
		brtc beepctr35	;якщо модулятор нециклічних звукові сигналів вимкнено то зразу перехід до циклічних
		bst tmp, 3
		brtc beepctr31	;перевірка чи динамік ввімкнено
		sbi porta, 1
		rjmp beepctre
beepctr31:cbi porta, 1
		rjmp beepctre
beepctr35:bst tmp, 1
		brts beepctr36	;якщо циклічні звукові сигнали приглушені то вимкнення динаміка і вихід
		bst tmp, 4
		brtc beepctr37	;перевірка чи динамік ввімкнено
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


.equ	beepnck = $11a		;нециклічні звукові сигнали @1 - 1 короткий звук,		 ;вищий пріоритет
							;@2 - 2 коротких звуки, @3 - 3 коротких звуки, 
							;@4 - 4 коротких звуки + 1 довгий, @5 - 1 довгий,
							;@6 - 2 довгих.
.equ	beepncktemp = $11b	;тимчасовий регістр нециклічних звукових сигналів
.equ	beepnckstep = $11c	;крок звукової послідовності
.equ	beepnckcount = $122	;рахунок часу звукової послідовності
.equ	beepckl = $11d		;циклічні звукові сигнали @1 - 1 секунда на 15 секунд,	 ;нижчий пріоритет
							;@2 - 2 секунди на 10 секунд, @3 - 3 секунди на 3 секунд,
							;@4 - непреривний звуковий сигнал.
.equ	beepckltemp = $11e	;тимчасовий регістр циклічних звукових сигналів
.equ	beepcklstep = $11f	;крок звукової послідовності
.equ	beepcklcount = $123	;рахунок часу звукової послідовності
.equ	beepfreg = $120		;регістр прапорців модулятора @0 - приглушення нециклічних звукових сигналів,
							;@1 - приглушення циклічних звукових сигналів, @2 - модулятор нцл. зв. сиг. ввімкнений
							;@3 - нцл. зв. сиг. динамік - ввімкнений, @4 - циклічн. зв. сиг. динамік - ввімкнений
.equ	beepftckl = $121	;регістр рахунку циклів швидкого таймера (програма модулятора виконується кожен 4-й цикл)

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

fpdimm:	sbi porta, 4 ;дімінг передньої панелі
		sbi porta, 2
		sbi porta, 0
		sbi portd, 3
		reti

dind:	push reg1
		lds reg1, lednum
		cpi reg1, 255		;якщо 255 - динамічна індикація вимкнута
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
;.equ	fpdimmlevel = $10f;дана перемінна задається задається в MAIN


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
fpdimmadj:push zl		;встановлення яскравості передньої панелі 0...5
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

keyask:	push reg1	;підпрограма опитування клавіатури
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
		cpi tmp, 0	;якщо нуль то на перевірку натискання
		breq keyask1
		cpi tmp, 100;якщо 100 то на перевірку відпускання клавіші або обробку мультипресу
		brsh keyask3
		rjmp keyaske;якщо ні, значить натискання не оброблене - на вихід

keyask3:cpi reg1, 0;перевірка чи натиснута будь яка клавіша
		breq keyask4
		cpi reg1, 5 ;якщо натиснута, то перевірка чи дана клавіша підпалає під перевірку мультипресу
		brsh keyask31
		rjmp keyask5		
keyask31:lds tmp, keytmp
		cp reg1, tmp	;перевірка чи натиснута кл відповідає попередньо натиснутій
		brne keyask5	
		lds reg2, keymultip ;якщож відповідає, то...
		inc reg2
		cpi reg2, 255
		brne keyask32
		ldi tmp, 0
		sts key, tmp
		sts keycountl, tmp
		ldi reg2, 210
keyask32:sts keymultip, reg2
		rjmp keyaske

keyask5:ldi tmp, 0 ;якщо натиснута не МП клав. то обнулюється лічильник і на вихід
		sts keycountl, tmp
		rjmp keyaske

keyask4:sts keymultip, reg1;якщо ненатиснута то перевірка 10 разів і обнулення
		lds reg2, keycountl
		inc reg2
		cpi reg2, 20
		brlo keyask41
		sts key, reg1
		sts keycountl, reg1
		rjmp keyaske
keyask41:sts keycountl, reg2
		rjmp keyaske

keyask1:cpi reg1, 0	;перевірка чи клавіша не була віддпущена, якщо так очистка лічильника мультипресу
		brne keyask11
		sts keymultip, reg1
keyask11:lds tmp, keytmp ;перевірка на факт натискання клавіші
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
startkey:ldi tmp, 0	;запуск процесу опитування клавіатури		
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

startlcd:cbi portd, 7 ;Ввімкнення/перезапуск дисплея
		rcall ini4b
		rcall lcdbias_startpwm
		ret

stoplcd:sbi portd, 7 ;Вимкнення дисплея
		ldi tmp, 0
		rcall lcdbit
		cbi portc, 3
		ret

lcdbias_startpwm:		;запуск шим модулятора регулювання контрасності дисплея
		ldi tmp, 0b01101001
		out tccr0, tmp
lcdbiasadj:push zl		;встановлення контрасності дисплея 1...9
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

lcdblon:;ldi tmp, 0b0000001	;ввімкнення підсвітки дисплея			
		;sts tccr3b, tmp		
		;ldi tmp, 0b0011000
		;sts etimsk, tmp
;lcdbladj:push zl		;встановлення яскравості підсвітки 1...10
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
				
lcdbloff:;ldi tmp, 0b0000000	;вимкнення підсвітки дисплея			
		;sts tccr3b, tmp
		;nop
		;nop
		cbi portb, 7
		ret

;dblcdbl:
;.db		0,10,21,34,48,64,84,107,138,181,255,0
			
ini4b:	push reg7	;підпрограма ініціалізації дисплея
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
		ror tmp		;Побітове виведення інформації на шину дисплея
		brcs lcdbit1
		cbi portc, 1			
		rjmp lcdbit2
lcdbit1:sbi portc, 1
lcdbit2:ror tmp		;біт 2
		brcs lcdbit21
		cbi portc, 0
		rjmp lcdbit3
lcdbit21:sbi portc, 0
lcdbit3:lds reg7, portg		
		ror tmp		;біт 3
		brcs lcdbit31	
		clt
		bld reg7, 1				
		rjmp lcdbit4
lcdbit31:set
		bld reg7, 1	
lcdbit4:ror tmp		;біт 4
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

;.equ	lcdcontrast = $100 ;дана перемінна задається задається в MAIN
.equ	lcdbllevel = $101
