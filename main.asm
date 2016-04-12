/*
 * main.inc
 *
 *  Created: 05.03.2015 1:06:23
 *   Author: Lax-T
 */ 
 
 			
slot1:	lds tmp, tempuni	;підпрограма переносу данних температури, викликається програмою управління датчиком температури
		sts tempunib, tmp	;після завершення вимірювання, необхідна для уникнення помило якщо дані про одиниці/десятки будуть
		lds tmp, temppar	;зчитані під час модифікації.
		sts tempparb, tmp		
		ret

.equ	tempunib = $233	;буферизовані значення температури
.equ	tempparb = $234

							;слот2 - програма алгоритму запуску
slot2:	lds tmp, powerupstep
		cpi tmp, 0
		breq slot2_0  ;крок 0 - первинна провірка стану живлення	
		rjmp slot2_2
slot2_0:ldi tmp, 0
		mov gereg1, tmp			;конфігурація регістра помилок
		mov gereg2, tmp			;конфігурація регістра помилок 2
		mov eventreg, tmp		;конфігурація регістра подій	
		mov toutreg, tmp
		mov toutreg2, tmp
		ldi tmp, 0
		sts menusit, tmp
							
		in tmp, pine	
		bst tmp, 6
		brtc slot2_1 ;перевірка чи живлення стабілізувалося, якщо так то перехід до наступного етапу
		lds tmp, powerupcount ;якщо ні то інкремент лічильника запуску
		inc tmp
		sts powerupcount, tmp
		cpi tmp, 30 ;перевірка чи вже було 30 спроб
		brsh slot2_01 ;якщо було то примусовий перехід до етапу 5
		ldi tmp, 5	;якщо ні то то ще одна затримка 0,5 сек
		sts slotr2, tmp
		ret						
slot2_01:rjmp slot2_5  ;примусовий перехід до етапу 5		
		
slot2_1:					  ;крок 1 - тестування EEPROM
		call i2cstart ;ініціалізація шини i2c
		ldi reg1, 0
		ldi tmp, 0	;перевірка ідентифікаторів памяті
		sts wordadrh, tmp
		ldi tmp, eeind1adr
		sts wordadrl, tmp
		call eeread
		lds tmp, i2cdata
		cpi tmp, 10
		breq slot2_11
		ldi reg1, 1
slot2_11:ldi tmp, eeind2adr
		sts wordadrl, tmp
		call eeread
		lds tmp, i2cdata
		cpi tmp, 162
		breq slot2_12
		ldi reg1, 1
slot2_12:ldi tmp, eeind3adr
		sts wordadrl, tmp
		call eeread
		lds tmp, i2cdata
		cpi tmp, 247
		breq slot2_13
		ldi reg1, 1
slot2_13:bst gereg1, eecerr ;після перевірки ідентифікаторів, перев. біту помилки звязку з памяттю
		brtc slot2_14
		rjmp slot2_7 ;примусовий перехід до етапу 7 - помилка звязку з памяттю
slot2_14:cpi reg1, 0
		breq slot2_15 ;перевірка чи ідентифікатори памяті відповідають константам
		call fullerase ;якщо ні то повна очистка памяті
		call searchle
		call searchll
		call clearlog
		call clearevent
		ldi tmp, 2
		sts powerupevent, tmp ;відмітка що була подія повного форматування памяті
		rjmp slot2_3
slot2_15:rcall scankeysp ;перевірка першої комбінації кнопок
		andi reg1, 0b00111111
		cpi reg1, 0b00100110
		brne slot2_3 ; якщо комбінація невірна то перехід до Кроку 3
		ldi tmp, 2	;якщо вірна то ввімкнення динаміка, очікування 2 секунди на наступну комбінацію
		sts powerupstep, tmp
		ldi tmp, 40 ;затримка 4секунди
		sts slotr2, tmp
		sbi porta, 1 ;ввімкнення динаміка
		ret

slot2_2:cpi tmp, 2	;крок 2 - перевірка комбінації кнопок 2 етап
		breq slot2_20
		rjmp slot2_4
slot2_20:cbi porta, 1 ;вимкнення динаміка					
		rcall scankeysp ;перевірка другої комбінації кнопок
		andi reg1, 0b00111111
		cpi reg1, 0b00001101
		brne slot2_3 ; якщо комбінація невірна то перехід до Кроку 3
		call fullerase ;якщо так то повне скидання налаштувань
		ldi tmp, 1
		sts powerupevent, tmp ;відмітка що була подія повного скидання налаштувань
		
slot2_3:	;крок 3 - проміжний контроль живлення/завантаження налаштувань	
		in tmp, pine	;проміжний контроль живлення
		bst tmp, 6
		brtc slot2_31
		rjmp slot2_6 ;якщо живлення не в нормі то перезапуск		
slot2_31:call searchle	;завантаження налаштувань
		call searchll		
		call readsett									
		call fasttmstart ;старт процесів
		call startkey
		call startdind
		call beepstart
		call startdscomm		
		call lcdblon
		call lcdbias_startpwm
		call startlcd				
		call startpass
		call startfpcont
		call fanctrstart	
		call pumpctrstart	
		call lvlcntstart
		call eventlogstart
		call fpowerdnintst ;дозвіл периривання по падінню живлення
		in tmp, pine	;проміжний контроль живлення
		bst tmp, 6
		brtc slot2_32
		rjmp slot2_6 ;якщо живлення не в нормі то перезапуск		
slot2_32:ldi tmp, 226
		sts lcdsit, tmp
		call lcdren ;демонстрація першого повідомлення
		
		ldi tmp, 0 ;тестування NVRAM
		sts wordadrh, tmp
		ldi tmp, nvcheck1
		sts wordadrl, tmp
		call nvread
		lds tmp, i2cdata
		cpi tmp, 167
		brne slot2_33
		ldi tmp, nvcheck2
		sts wordadrl, tmp
		call nvread
		lds tmp, i2cdata	
		cpi tmp, 37
		breq slot2_34			
slot2_33:ldi tmp, nvcheck1	;запис констант
		sts wordadrl, tmp
		ldi tmp, 167
		sts i2cdata, tmp
		call nvwrite
		ldi tmp, nvcheck2
		sts wordadrl, tmp
		ldi tmp, 37
		sts i2cdata, tmp
		call nvwrite
		ldi tmp, 07
		sts wordadrl, tmp
		ldi tmp, 0 ;встановлення 0 в корекцію ходу
		sts i2cdata, tmp
		call nvwrite		
		set
		bld gereg1, rtcerr ;встановлення біту помилки RTC
slot2_34:ldi tmp, 4	;затримка на показ повідомлення і вихід, наступним буде крок 4
		sts powerupstep, tmp	
		ldi tmp, 26 ;затримка 2,6 секунди
		sts slotr2, tmp
		ret
		
slot2_4:cpi tmp, 4		;крок 4
		brne slot2_8
		ldi tmp, 227
		sts lcdsit, tmp
		call lcdren ;демонстрація другого повідомлення	
		ldi tmp, 8	;затримка на показ повідомлення і вихід, наступним буде крок 8
		sts powerupstep, tmp
		ldi tmp, 26 ;затримка 2,6 секунди
		sts slotr2, tmp
		ret
		
slot2_5:				;крок 5 - блокування з видачою повідомлення про несправність живлення
		call lcdblon		;ввімкнення дисплею
		call lcdbias_startpwm 
		call startlcd		;ініціалізація дисплею
		ldi tmp, 230
		sts lcdsit, tmp
		call lcdren			;видача повідомлення про несправність
slot2_51:rjmp slot2_51		;безкінечний цикл
		
slot2_6:			;крок 6 - пропажа живлення під час запуску, зупинка всіх процесів і перезап.				
		call stoplcd	;підпрограма зупинки роботи прибора
		call lcdbloff
		call stopdind
		call beepstop	
		call stopdscomm		
		ldi tmp, 0		;передача управління програмі запуску прибора
		sts powerupstep, tmp
		sts powerupcount, tmp
		sts powerupevent, tmp
		ldi tmp, 2
		sts slotr2, tmp
		ret

slot2_7:		;крок 7 - блокування з видачою повідомлення про несправність памяті
		call lcdblon		;ввімкнення дисплею
		call lcdbias_startpwm 
		call startlcd		;ініціалізація дисплею
		ldi tmp, 217
		sts lcdsit, tmp
		call lcdren			;видача повідомлення про несправність
slot2_71:rjmp slot2_71		;безкінечний цикл

slot2_8:cpi tmp, 8
		brne slot2_9		;крок 8 - показ 3 повідомлення/вихід
		lds reg1, powerupevent
		cpi reg1, 0 
		breq slot2_9 ;якщо непотрібно показувати ніяких повідомлень то перехід до кроку 9
		ldi tmp, 227
		add reg1, tmp
		sts lcdsit, reg1
		call lcdren ;демонстрація третього повідомлення	
		ldi tmp, 9	;затримка на показ повідомлення і вихід, наступним буде крок 9
		sts powerupstep, tmp
		ldi tmp, 40 ;затримка 4 секунди
		sts slotr2, tmp
		ret
							;крок 9 - старт процесів і вихід
slot2_9:ldi tmp, 1;запуск групи секундних функцій
		sts slotr12, tmp	
		ldi tmp, 2;запуск групи функцій управління передньою панеллю/дисплеєм
		sts slotr11, tmp	
		ldi tmp, 2;запуск підпрограми управління насосом
		sts slotr7, tmp
		ldi tmp, 2;запуск підпрограми управління вентилятором
		sts slotr6, tmp
		ldi tmp, 4;запуск підпрограми контролю порогів
		sts slotr8, tmp
		ldi tmp, 6;запуск підпрограми запису логу подій
		sts slotr10, tmp
		set
		bld eventreg, poweron ;встановлення біту події старту приладу, для запису в лог
		ldi tmp, 0 ;встановлення коду головного екрану
		sts lcdsit, tmp	
		set
		bld gereg1, sysrdy
		ldi tmp, 100
		sts key, tmp
		ret

.equ	powerupstep = $260 ;крок процедури запуску
.equ	powerupcount = $261 ;кількість спроб запуску, перевірок стану живлення (PE6)
.equ	powerupevent = $262 ;регістр прапорців підпрограми запуску 1 - виконано скидання налаштувань
							;2 - виконано повне форматування памяті

scankeysp:ldi reg1, 0	;підпрограма формування стану кнопок
		in tmp, pinc
		bst tmp, 7
		bld reg1, 0

		bst tmp, 5
		bld reg1, 3

		bst tmp, 6
		bld reg1, 4

		bst tmp, 4
		bld reg1, 5

		in tmp, pina
		bst tmp, 7
		bld reg1, 1

		lds tmp, ping
		bst tmp, 2
		bld reg1, 2

		ret

slot3:	call stoplcd	;підпрограма зупинки роботи прибора
		call lcdbloff
		call stopdind
		call beepstop	
		call stopdscomm
		rcall fanctrstop
		rcall pumpoff

		ldi tmp, 0;зупинка процесів
		sts slotr12, tmp			
		sts slotr11, tmp			
		sts slotr7, tmp		
		sts slotr6, tmp		
		sts slotr8, tmp		
		sts slotr10, tmp
		mov toutreg, tmp ;скидання всіх бітів переривань
		mov toutreg2, tmp

		lds tmp, timeyear	;підготовка данних для запису подї вимкнення
		sts memdata5, tmp
		lds tmp, timemonth
		sts memdata4, tmp
		lds tmp, timedate
		sts memdata3, tmp
		lds tmp, timemin
		sts memdata2, tmp
		lds tmp, timehour
		sts memdata1, tmp
		ldi tmp, 0 ;код події вимкнення живлення
		sts memdata6, tmp
		call storeevent ;запис події

		ldi tmp, 0		;передача управління програмі запуску прибора
		sts powerupstep, tmp
		sts powerupcount, tmp
		sts powerupevent, tmp
		ldi tmp, 10
		sts slotr2, tmp
		ret

slot4:	lds tmp, popupstep		;меню POPup
		cpi tmp, 0
		brne slot4_1
		ldi tmp, 2
		sts slotr4, tmp
		ldi tmp, 1	;перехід на етап 1 (блокування клавіш за 200мс до зміни вікна)		
		sts popupstep, tmp
		rjmp slot4_3		
slot4_1:cpi tmp, 1
		brne slot4_2
		ldi tmp, 1
		sts slotr4, tmp
		lds tmp, popuplsit
		sts lcdsit, tmp
		ldi tmp, 2 ;перехід на етап 2 (блокування кл. 100мс після зміни вікна)
		sts popupstep, tmp
		call lcdren
		rjmp slot4_3
slot4_2:lds tmp, popupmsit
		sts menusit, tmp	;вихід на потрібну підпрограму меню, завершення програми popup
slot4_3:ret

popupstart:ldi tmp, 0
		sts popupstep, tmp	;перший етап 0-показ вікна, 1-затримка перед зникненням вікна, 2-затримка після зникнення вікна
		ldi tmp, 18
		sts	slotr4, tmp	;затримка першого етапу POP up
		ldi tmp, 3
		sts menusit, tmp		
		ret		
.equ	popupstep = $230	;крок відпрацювання алгоритму спливаючого вікна
.equ	popupmsit = $231	;пункт меню після виходу з спливаючого вікна
.equ	popuplsit = $232	;код зображення після виходу з спливаючого вікна

slot5:	call menuop				;меню
		lds tmp, passfreg	;перевірка регістра прапорців підпрг захисту
		bst tmp, 4
		brtc slot5_1	
		andi tmp, 0b11101111	;повторний виклик меню якщо був встановлений відповідний біт
		sts passfreg, tmp
		rjmp slot5		
slot5_1:ldi tmp, 100
		sts key, tmp
		call lcdren
		call useraktion ;скидання таймера автовиходу з меню
		ret

slot6:	lds reg3, fanpcstep;завантаження номера етапу управління вентилятором 
		bst gereg1, dsdtv;перевірка чи дані з датчика температури дійсні
		brtc slot6_f
		lds tmp, tempunib
		cpi tmp, 89;Перевірка чи температура більша 89 градусів
		brsh slot6_f	
slot6_2:lds tmp, fanmod
		cpi tmp, 1;перевірка чи 1 - автоматичний режим
		breq slot6_3
		cpi tmp, 2;перерірка чи 2 - примусово ввімкнено
		breq slot6_n
		rjmp slot6_f
slot6_3:lds tmp, gmod	;якщо автоматичний режим то перевірка чи розпал, чи гасіння
		cpi tmp, 1	;якщо не розпал то примусово вимкнено
		brne slot6_f
		lds reg1, tempunib	;перевірка температури вимкнення вентилятора
		lds tmp, fantoff		
		cp reg1, tmp
		brlo slot6_4;якщо температура менша за поріг перехід до наступної підпрограми
		rjmp slot6_f;вимкнення вертилятора
slot6_4:lds reg2, tempparb;перевірка температури ввімкнення
		lds tmp, fanton		
		cp reg1, tmp
		brlo slot6_n;перевірка якщо температура менша за поріг то ввімкнення вентилятора
		cp tmp, reg1
		brlo slot6_5 ;перевірка якщо температура більша за поріг то вихід
		cpi reg2, 0 ;якщо знамення рівні то перевірка чи десяті рівні 0
		brne slot6_5

slot6_n:cpi reg3, 100 ;перевірка чи більше 100, це означає що вже виконується включення
		brsh slot6_5
		ldi reg3, 100 ;початок процедури ввімкнення
		rjmp slot6_5
slot6_f:cpi reg3, 2	;якщо 100 (вик ввімкнення) або 2 (вимкнення виконано) перезапуск вимкнення (для безпеки ця функція виконується циклічно)
		brlo slot6_5
		ldi reg3, 0 ;початок процедури вимкнення

slot6_5:cpi reg3, 100;якщо 100 і більше - перехід до процедури вімкнення
		brsh slot6_9
		cpi reg3, 0 ;процедура вимкнення
		brne slot6_6;1 етап
		cbi porte, 7;вимкнення симістора вентилятора
		cbi porte, 5;вимкнення навантаження симістора (тест)
		lds tmp, fpledbuf;вимкнення світодіода
		andi tmp, 0b10111111
		sts fpledbuf, tmp
		ldi reg3, 1 ;перехід на етап 2
		ldi reg1, 10 ;затримка до етапу 2 1сек
		rjmp slot6_e
slot6_6:cpi reg3, 1
		brne slot6_7;2 етап
		cbi portb, 0;вимкнення реле вентилятора
		ldi reg3, 2 ;перехід на етап 3
slot6_7:ldi reg1, 5 ;затримка 0,5сек (3 етап - нічо нероблення)
		rjmp slot6_e	
			
slot6_9:cpi reg3, 100
		brne slot6_10;1 етап
		sbi portb, 0;ввімкнення реле вентилятора
		sbi porte, 5;ввімкнення навантаження симістора (тест)
		ldi reg3, 101 ;перехід на етап 2
		ldi reg1, 10 ;затримка до етапу 2 1сек
		rjmp slot6_e		
slot6_10:cpi reg3, 101
		brne slot6_11;2 етап
		in tmp, pinb;перевірка чи є напруга при вимкненому симісторі
		bst tmp, 3
		brts slot6_12
		set	;є напруга, симістор пошкоджено
		rjmp slot6_13
slot6_12:clt ;норма
slot6_13:bld gereg2, triacer
		sbi porte, 7 ;ввімкнення симістора
		lds tmp, fpledbuf;ввімкнення світодіода
		ori tmp, 0b01000000
		sts fpledbuf, tmp
		ldi reg3, 102 ;перехід на етап 3
		ldi reg1, 10 ;затримка до етапу 3 1сек
		rjmp slot6_e
slot6_11:cpi reg3, 102
		brne slot6_14;3 етап
		in tmp, pinb;перевірка чи є напруга при ввімкненому симісторі
		bst tmp, 3
		brts slot6_15
		clt ;є напруга, норма
		rjmp slot6_16
slot6_15:set ;напруги нема, спрацював якийсь захист
slot6_16:bld gereg2, fanproter
		cbi porte, 5 ;вимкнення навантаження симістора (тест)
		ldi reg3, 103 ;перехід на етап 4
slot6_14:ldi reg1, 5 ;затримка 0,5сек (4 етап - нічо нероблення)
		
slot6_e:sts fanpcstep, reg3 		
		sts slotr6, reg1
		ret

fanctrstart:
		ldi tmp, 0
		sts fanpcstep, tmp
		ret

fanctrstop:
		cbi porte, 7;вимкнення симістора вентилятора
		cbi porte, 5;вимкнення навантаження симістора (тест)
		cbi portb, 0;вимкнення реле вентилятора
		ret

.equ	fanpcstep = $235 ;етап управління живленям вентилятора


slot7:	lds tmp, pumpmod	;підпрограма управління насосом
		lds reg3, pumpfreg  ;регістр 3 прапорці підрограми управління насосом
		cpi tmp, 1 ;перевірка чи 1 - автоматичний режим
		breq slot7_3
		cpi tmp, 0 ;перерірка чи 0 - примусово вимкнено
		brne slot7_1 ;примусово ввімкнено
								;Режим - примусово вимкнено
		lds tmp, pumpemer;перевірка чи ввімкнуто контроль аварійного ввімкнення насоса
		cpi tmp, 1
		brne slot7_a
		bst gereg1, dsdtv;Перевірка чи данні з датчика температури дійсні
		brtc slot7_a ;якщо ні, то примусово вимкнено
		lds tmp, tempunib
		cpi tmp, 85	;перевірка чи досягнутий критичний поріг
		brlo slot7_b;якщо ні 
		rcall pumpon;якщо так - ввімкнення насоса
		set
		bld reg3, pumpovt ; встановлення біту признаку перегріву
		rjmp slot7_ex;вихід							 
slot7_b:bst reg3, pumpovt	;якщо встановлений біт признаку перегріву то виключити насос може тільки програма
							;контролю нижнього порогу
		brtc slot7_a		;якщо біт не встановлений то вимкнення
		lds reg2, tempparb	;перевірка температури вимкнення
		lds tmp, pumptoff		
		cp reg1, tmp	;перевірка чи температура однозначно менша за поріг
		brlo slot7_a
		cp tmp, reg1
		brlo slot7_c ;перевірка чи температура однозначно більша за поріг, якщо так то вихід
		cpi reg2, 0	;якщо знамення рівні то перевірка чи десяті рівні 0
		brne slot7_c
slot7_a:rcall pumpoff;вимкнення насоса
		ldi reg3, 0 ;скидання усіх бітів
slot7_c:rjmp slot7_ex;вихід		
								;Режим - примусово ввімкнено
slot7_1:rcall pumpon;ввімкнення насоса
		ldi reg3, 0 ;скидання усіх бітів
		rjmp slot7_ex;вихід		
								;Режим - автоматичний
slot7_3:bst gereg1, dsdtv;Перевірка чи данні з датчика температури дійсні
		brts slot7_4
		rcall pumpon;якщо ні то примусове ввімкнення насоса
		rjmp slot7_ex				
slot7_4:lds tmp, gmod
		bst tmp, 0
		brtc slot7_5 ;перевірку глобального режиму роботи котла, якщо гасіння то насос не включається
		lds reg1, tempunib	;перевірка температури ввімкнення
		lds tmp, pumpton		
		cp reg1, tmp
		brlo slot7_5 ;якщо температура менша за поріг перехід до наступної підпрограми
		rcall pumpon;ввімкнення насоса
		set
		bld reg3, pumpovt ; встановлення біту признаку перегріву
		rjmp slot7_ex		
slot7_5:cpi tmp, 85	;перевірка чи досягнутий критичний поріг
		brlo slot7_6;якщо ні 
		rcall pumpon;якщо так - ввімкнення насоса
		set
		bld reg3, pumpovt ; встановлення біту признаку перегріву
		rjmp slot7_ex
slot7_6:lds reg1, tempunib ;перевірка температури вимкнення
		lds reg2, tempparb 
		lds tmp, pumptoff		
		cp reg1, tmp	;перевірка чи температура однозначно менша за поріг
		brlo slot7_7
		cp tmp, reg1
		brlo slot7_8 ;перевірка чи температура однозначно більша за поріг, якщо так то вихід
		cpi reg2, 0	;якщо знамення рівні то перевірка чи десяті рівні 0
		brne slot7_8
slot7_7:rcall pumpoff	;вимкнення насоса
		ldi reg3, 0 ;скидання усіх бітів
		rjmp slot7_ex
slot7_8:bst reg3, pumpovt ;перевірка біту признаку перегріву
		brts slot7_ex ;якщо біт встановлений значить насос ввімкнено по перегріву а не по несправності
		rcall pumpoff ;якщо по несправності то вимкнення насоса
slot7_ex:ldi tmp, 5 ;вихід
		sts slotr7, tmp
		sts pumpfreg, reg3
		ret

pumpctrstart:ldi tmp, 0
		sts pumpfreg, tmp
		ret

.equ	pumpfreg = $265 ;прапорці підпрограми управління насосом
.equ	pumpovt = 0 ;признак ввімкнення насоса по температурі (вищий пріоритет ніж несправність)


pumpon:	sbi portb, 2
		lds tmp, fpledbuf;ввімкнення світодіода
		ori tmp, 0b00100000
		sts fpledbuf, tmp
		ret
pumpoff:cbi portb, 2
		lds tmp, fpledbuf;вимкнення світодіода
		andi tmp, 0b11011111
		sts fpledbuf, tmp
		ret

slot8:	lds tmp, gmod	;підрограма контролю верхнього і нижнього порогів попередження
		cpi tmp, 1		;перевірка чи котел працює і потрібно контролювати пороги
		breq slot8_00
		clt					;якщо ні то скидання бітів і вихід
		bld gereg2, triseer
		bld gereg2, tfaller		
		lds tmp, lvlcntfreg ;скидання біту виходу на робочий діапазон
		andi tmp, 0b11111110	
		sts lvlcntfreg, tmp
		rjmp slot8_02 
slot8_00:bst gereg1, dsdtv  ;перевірка чи дані температури дійсні 
		brts slot8_a1	;наступний код потрібен щоб несправність відновилася якщо д/т несправний а контроль вимкнено
		lds tmp, trisemod ;перевірка чи верхній поріг контролюєтьсяься
		cpi tmp, 1	
		breq slot8_c1
		clt					;очищення біту превищення температури
		bld gereg2, triseer
slot8_c1:lds tmp, tfallmod ;перевірка чи нижній поріг контролюється
		cpi tmp, 1
		breq slot8_c2		
		clt			;очищення біту падіння температури
		bld gereg2, tfaller
slot8_c2:rjmp slot8_02 ;якщо ні то вихід
slot8_a1:lds reg2, lvlcntfreg
		lds reg1, tempunib ;перевірка чи можливо встановити біт виходу на робочий діапазон
		lds tmp, fanton
		cp reg1, tmp ;перевірка чи температура більша рівна за температуру включення
		brlo slot8_b1
		lds tmp, fantoff
		cp reg1, tmp ;перевірка чи температура менша за температуру виключення
		brsh slot8_b1		
		ori reg2, 0b00000001 ;якщо умови виконалися то встановлення біту виходу на режим
		sts lvlcntfreg, reg2
slot8_b1:bst reg2, workmode ;перевірка чи біт робочого режиму встановлено
		brts slot8_01	;якщо так то перехід до підпрограм контролю
		rjmp slot8_02  ;якщо ні то вихід

slot8_01:lds tmp, trisemod ;перевірка чи верхній поріг контролюєтьсяься
		cpi tmp, 1
		brne slot8_11 
		lds reg2, tempunib
		lds reg1, fantoff	
		lds tmp, triserel
		add reg1, tmp ;до температури виключення вентилятора додається відносний поріг
		bst gereg2, triseer
		brtc slot8_12 ;якщо біт очищений то нормальний контроль
		dec reg1   ;якщо встановлений то для гістерезису поріг відновлення знижується на 1 градус
		cp reg2, reg1
		brlo slot8_14 ;якщо температура однозначно нижча за поріг то скидання біту
		cp reg1, reg2
		brlo slot8_13 ;якщо температура однозначно вища за поріг то встановлення біту
		lds tmp, tempparb
		cpi tmp, 0	;якщо значення рівні то перевіряється чи десяті рівні 0
		brne slot8_13 ;ні - встановлення біту
slot8_14:set
		bld eventreg, tfrrestore ;встановлення біту відновлення температури
		rjmp slot8_11					
slot8_12:cp reg2, reg1
		brlo slot8_11 ;якщо температура не перевищує поріг то скидання біта
slot8_13:set			;якщо перевищує то встановлення відповідного біту
		bld gereg2, triseer
		rjmp slot8_2
slot8_11:clt		;якщо ні то очищення біту превищення температури і перехід до нижн. порогу
		bld gereg2, triseer
		
slot8_2:lds tmp, tfallmod ;перевірка чи нижній поріг контролюється
		cpi tmp, 1
		brne slot8_21 
		lds reg2, tempunib
		lds reg1, fanton		
		lds tmp, tfallrel
		sub reg1, tmp	;від температури включення вентилятора віднімається поріг
		bst gereg2, tfaller
		brtc slot8_22 ;якщо біт очищений то нормальний контроль
		inc reg1 ;якщо встановлений то для гістерезису поріг відновлення збільшується на 1 градус
		cp reg2, reg1
		brsh slot8_24 ;якщо температура більша/рівна порогу то скидання біту
		rjmp slot8_23 ;ні встановлення
slot8_22:cp reg2, reg1
		brlo slot8_23 ;якщо температура однозначно нижча за поріг то встановленя біту
		cp reg1, reg2
		brlo slot8_21 ;якщо температура однозначно вища за поріг скидання біту
		lds tmp, tempparb
		cpi tmp, 0; якщо значення рівні то провіряється десяті рівні 0
		brne slot8_21 ;якщо не десяті не 0 то скидання біту
slot8_23:set
		bld gereg2, tfaller
		rjmp slot8_02
slot8_24:set
		bld eventreg, tfrrestore ;встановлення біту відновлення температури
slot8_21:clt	;якщо ні то очищення біту падіння температури і вихід
		bld gereg2, tfaller
slot8_02:ldi tmp, 5	;циклічний повторний виклик
		sts slotr8, tmp
		ret

workmodereset:lds tmp, lvlcntfreg ;скидання біту виходу на робочий діапазон після зміни температури або
		andi tmp, 0b11111110	;зміни режиму роботи котла
		sts lvlcntfreg, tmp
		ret
lvlcntstart:ldi tmp, 0
		sts lvlcntfreg, tmp
		ret

.equ	lvlcntfreg = $266 ;прапорці підпрограми контролю порогів
.equ	workmode = 0 ;признак виходу котла на робочий діапазон температур (між температурою включення 
						;і виключення вентилятора)
slot9:
		ret
							;Слот 10 - запис в лог подій
slot10: mov reg1, gereg1	;перший загальний регістр помилок
		andi reg1, 0b01110111 ;примусово скидаються непотрібні біти
		mov reg2, gereg2	;другий загальний регістр помилок
		andi reg2, 0b11000011 ;примусово скидаються непотрібні біти

		lds tmp, timeyear	;підготовка данних
		sts memdata5, tmp
		lds tmp, timemonth
		sts memdata4, tmp
		lds tmp, timedate
		sts memdata3, tmp
		lds tmp, timemin
		sts memdata2, tmp
		lds tmp, timehour
		sts memdata1, tmp

		lds tmp, errwritemask1	;оновлення переліку несправносей
		sts errwritemask1, reg1	;оновлення маски першого регістра
		com tmp
		and reg1, tmp	;маскування подій що були записані попередній раз
		lds tmp, errwritemask2
		sts errwritemask2, reg2	;оновлення маски другого регістра
		com tmp
		and reg2, tmp	;маскування подій що були записані попередній раз
		rcall errwriteform
		cpi reg3, 0	;перевірка чи є несправності для запису
		breq slot10v1
		ldi xh, high(errwriteslot1) ;встановлення адреси першого слота
		ldi xl, low(errwriteslot1)
slot10r1:ld tmp, x+		
		sts memdata6, tmp
		call storeevent
		dec reg3
		cpi reg3, 0
		brne slot10r1

slot10v1:mov reg1, eventreg
		andi reg1, 0b01111101 ;занулення непотрібних бітів
		rcall varwriteform
		cpi reg3, 0
		breq slot10e
		ldi xh, high(varnwriteslot1) ;встановлення адреси першого слота
		ldi xl, low(varnwriteslot1)
slot10v2:ld tmp, x+		
		sts memdata6, tmp
		call storeevent
		dec reg3
		cpi reg3, 0
		brne slot10v2
		mov reg1, eventreg
		andi reg1, 0b00000010 ;скидання бітів
		mov eventreg, reg1
slot10e:ldi tmp, 10	;циклічний повторний виклик
		sts slotr10, tmp		
		ret		
					;підпрограми формування списку подій для запису
errwriteform:ldi xh, high(errwriteslot1) ;завантаження адреси першого слота помилок
		ldi xl, low(errwriteslot1)
		ldi reg3, 0 ;лічильник загальної кількості несправностей/попереджень
		ldi reg4, 0
ewrtf3:	cpi reg4, 8 ;перевірити чи вже перевірено 8 бітів з 2го регістра якщо так то перенести дані з 1го
		brne ewrtf1
		mov reg2, reg1
ewrtf1:	lsl reg2	;перевірка виконується починаючи з старшого регістру і старшого біту
		brcc ewrtf2	;перевірка чи біт С (прапорець помилки) встановлений
		ldi zh, high(2*dberrwritecode) ;по номеру перевіреного біту витягується код події/несправності з таблиці
		ldi zl, low(2*dberrwritecode)
		add zl, reg4
		clr tmp
		adc zh, tmp
		lpm tmp, z
		st x+, tmp ;збереження коду події в слоті і інкремент адреси слота
		inc reg3 ;інкремент кількості несправностей/попереджень
ewrtf2:	inc reg4
		cpi reg4, 16 ;перевірка чи вже перевірено 16 бітів
		brne ewrtf3
		ret
		
dberrwritecode:		;коди несправностей логу подій
.db		3,2,0,0,0,0,21,15
.db		0,9,8,8,0,11,10,13

				;підпрограми формування списку подій для запису 2
varwriteform:ldi xh, high(varnwriteslot1) ;завантаження адреси першого слота помилок
		ldi xl, low(varnwriteslot1)
		ldi reg3, 0 ;лічильник загальної кількості несправностей/попереджень
		ldi reg4, 0
evawf1:	lsl reg1	;перевірка виконується починаючи з старшого регістру і старшого біту
		brcc evawf2	;перевірка чи біт С (прапорець помилки) встановлений
		ldi zh, high(2*dbevewritecode) ;по номеру перевіреного біту витягується код події/несправності з таблиці
		ldi zl, low(2*dbevewritecode)
		add zl, reg4
		clr tmp
		adc zh, tmp
		lpm tmp, z
		st x+, tmp ;збереження коду події в слоті і інкремент адреси слота
		inc reg3 ;інкремент кількості несправностей/попереджень
evawf2:	inc reg4
		cpi reg4, 8 ;перевірка чи вже перевірено 16 бітів
		brne evawf1
		ret

dbevewritecode:	 ;коди попередження логу подій
.db		0,1,7,5,17,16,0,4

.equ	errwriteslot1 = $24c
.equ	errwriteslot2 = $24d
.equ	errwriteslot3 = $24e
.equ	errwriteslot4 = $24f
.equ	errwriteslot5 = $250
.equ	errwriteslot6 = $251
.equ	errwritemask1 = $252
.equ	errwritemask2 = $253
.equ	varnwriteslot1 = $254
.equ	varnwriteslot2 = $255
.equ	varnwriteslot3 = $256
.equ	varnwriteslot4 = $257
.equ	varnwriteslot5 = $258
.equ	varnwriteslot6 = $259

eventlogstart:ldi tmp, 0
		sts errwritemask1, tmp
		sts errwritemask2, tmp
		ret


slot11:				;слот11 - демонстрація несправностей/звук несправностей/світодіод статусу/св режиму
		mov reg5, gereg1	;перший загальний регістр помилок
		andi reg5, 0b01110111 ;примусово скидаються непотрібні біти
		mov reg6, gereg2	;другий загальний регістр помилок
		andi reg6, 0b11000011 ;примусово скидаються непотрібні біти
							;аналіз регістрів несправностей	без маскування
		mov reg1, reg5		;копіювання регістрів
		mov reg2, reg6
		rcall errpopupform ;виклик підпр. форм. списку кодів спливаючих вікон для несправностей/попереджень
		cpi reg3, 0		;в регістрі 3 кількість активних помилок
		breq slot11ld1	;управління світодіодом статусу
		rcall setledred		
		rjmp slot11ld2
slot11ld1:rcall setledgreen									
slot11ld2:mov reg1, reg5		;копіювання регістрів
		mov reg2, reg6
		lds tmp, errmask1	;регістр маскування помилок в регістрі 1
		and tmp, reg1 ;скидання бітів маскування для помилок що вже відновилися (0 в gereg)
		sts errmask1, tmp ;оновлення бітів маскування		
		com tmp ;інвертування бітів
		and reg1, tmp	;занулення бітів несправностей які замасковані				
		lds tmp, errmask2	;те саме для другого регістра помилок
		and tmp, reg2
		sts errmask2, tmp		
		andi tmp, 0b00111111 ;заборона маскування росту/падіння температури для дисплея
		com tmp 
		and reg2, tmp						
		rcall errpopupform  ;повторний аналіз регістрів несправностей з врахуванням маскування для дисплея
							;управління дисплеєм
slot11lc1:cpi reg3, 0
		brne slot11lc2 ;якщо помилок нема, то
		ldi tmp, 4
		sts errmsgtiming, tmp ;занесення в регістр таймінгу 3 щоб прискорити виведення при помилці
		lds tmp, eermsgdisplay
		cpi tmp, 1 ;перевірка чи на момент відновлення показувалося вікно помилки
		breq slot11lc3		
		rjmp slot11bp		;якщо ні, вихід з підпрограми управління дисплеєм		
slot11lc3:lds tmp, menusit	;якщо показувалося
		cpi tmp, 0 ;перевірка чи зараз в головному екрані/дежурному режимі
		brne slot11lc4
		sts lcdsit, tmp ;якщо так то занесення коду головного екрану
		call lcdren ;оновлення дисплею
slot11lc4:ldi tmp, 0
		sts eermsgdisplay, tmp ;вказується що вікно помилки вже не показується
		rjmp slot11bp	;вихід з підпрограми управління дисплеєм							
slot11lc2:lds tmp, eermsgdisplay ;якщо є помилки то робота циклу зміни зображення
		cpi tmp, 1		;перевірка стану біту виведення зображення
		breq slot11lc5
		lds reg1, errmsgtiming
		inc reg1
		cpi reg1, 6 ;час показу головного екрану
		brlo slot11lc6	
		ldi reg1, 0
		ldi tmp, 1
		sts eermsgdisplay, tmp
		lds tmp, lcdsit
		cpi tmp, 0 ;перевірка чи зараз головний екран, якщо ні то вихід
		brne slot11lc6
		lds tmp, errslot1 ;завантажується код з першого слота
		sts lcdsit, tmp
		call lcdren ;оновлення дисплея		
slot11lc6:sts errmsgtiming, reg1
		rjmp slot11bp ;вихід		
slot11lc5:lds reg1, errmsgtiming ;якщо один то зображення на даний момент повинно показуватися
		inc reg1
		cpi reg1, 8 ;час показу екрану помилки
		brlo slot11lc6	
		ldi reg1, 0
		ldi tmp, 0
		sts eermsgdisplay, tmp
		lds tmp, menusit
		cpi tmp, 0 ;перевірка чи зараз головний екран, якщо ні то вихід
		brne slot11lc7
		ldi tmp, 0 ;завантажується код головного екрану
		sts lcdsit, tmp
		call lcdren ;оновлення дисплея		
slot11lc7:sts errmsgtiming, reg1 ;вихід				 
					;підпрограма управління динаміком
slot11bp:mov reg1, reg5		;копіювання регістрів
		mov reg2, reg6
		lds tmp, errmask1	;регістр маскування помилок в регістрі 1		
		com tmp ;інвертування бітів
		and reg1, tmp	;занулення бітів несправностей які замасковані				
		lds tmp, errmask2	;те саме для другого регістра помилок		
		com tmp 
		and reg2, tmp						
		rcall errpopupform  ;повторний аналіз регістрів несправностей з повним маскуванням для динаміка
		cpi reg3, 0	
		brne slot11bp1 ;якщо нема несправностей/попередження, то вимкнення динаміка і вихід
		ldi tmp, 0
		sts beepckl, tmp
		clt
		bld eventreg, erractive ;скидання біту що динамік працює
		rjmp slot11di1
slot11bp1:set
		bld eventreg, erractive ;встановлення біту що динамік працює
		lds tmp, errslot1
		cpi tmp, 203 ;перевірка чи попередження про високу температуру
		brne slot11bp2
		ldi reg1, 4	;якщо так завантажую тональність 4
		rjmp slot11bp3
slot11bp2:cpi tmp, 202 ;перевірка чи попередження про низьку температуру
		brne slot11bp4 ;якщо ні то ні друге то перехід до аналізу несправностей
		ldi reg1, 2	;якщо так завантажую тональність 2
slot11bp3:lds tmp, soundmod ;перевірка чи звуки попередження дозволені
		bst tmp, 2
		brtc slot11bp5 ;якщо ні то перехід до аналізу несправностей
		sts beepckl, reg1 ;якщо так то зовантаження тональності і вихід
		rjmp slot11di1		
slot11bp4:ldi reg1, 3	;якщо не попередження про ріст або падіння температури - гарантовано несправність
		rjmp slot11bp9 ;вихід
					;якщо звук попереджень вимкнено то додатково аналіз чи ще є несправності
slot11bp5:cpi reg3, 3	;якщо 3 і більше то гарантовано є несправності
		brlo slot11bp6
		ldi reg1, 3 ;завантаження коду тональності несправноті і вихід
		rjmp slot11bp9
slot11bp6:cpi reg3, 2 ;якщо 1 то значить попередження було єдиним (несправностей нема)
		brsh slot11bp7
		ldi reg1, 0 ;вимкненя динаміка і вихід
		rjmp slot11bp9
slot11bp7:lds tmp, errslot2 ;якщо 2 події то перевірка в слоті 2 попередження чи несправність
		cpi tmp, 202 ;оскільки слот 2 то може бути попередження тільки про низьку температуру
		brne slot11bp8
		ldi reg1, 0 ;якщо так, вимкненя динаміка і вихід
		rjmp slot11bp9
slot11bp8:ldi reg1, 3 ;в слоті 2 несправність, завантаження тональності
slot11bp9:lds tmp, soundmod ;перевірка чи звук несправнеостей включений
		bst tmp, 1 
		brts slot11bp10	;якщо включений то просто вивід значення в beepckl
		ldi reg1, 0 ;якщо виключено то виведення 0 - звук вимкнено
slot11bp10:sts beepckl, reg1
					;підпрограма управління динамічною індикацією
slot11di1:bst gereg1, dsdtv ;перевірка чи дані температури дійсні
		brts slot11di2
		ldi reg1, $0f ;якщо дані не дійсні то виводятся конcтанти (прочерки)
		ldi reg2, $0f
		ldi reg3, $0f
		rjmp slot11di3
slot11di2:lds reg3, tempparb ;якщо дійсні то температура з буферизованих регістрів
		lds reg2, tempunib
		ldi reg1, 0
slot11di4:cpi reg2, 10
		brlo slot11di3
		subi reg2, 10
		inc reg1
		rjmp slot11di4
slot11di3:mov tmp, reg3
		rcall getsegsp		
		sts seg3buf, tmp
		mov tmp, reg1
		rcall getsegsp
		sts seg1buf, tmp
		mov tmp, reg2
		rcall getsegsp
		ori tmp, 0b00010000
		sts seg2buf, tmp

		lds tmp, gmod	;оновлення стану світодіода режиму роботи
		bst tmp, 0
		lds tmp, fpledbuf
		bld tmp, 7
		sts fpledbuf, tmp

		ldi tmp, 5	;повторний (циклічний) виклик програми 
		sts slotr11, tmp
		ret

getsegsp:ldi zh, high(2*db7dig)
		ldi zl, low(2*db7dig)
		add zl, tmp
		ldi tmp, 0
		adc zh, tmp
		lpm tmp, z
		ret

db7dig:
.db		0b11101110,0b10000010,0b10101101,0b10101011  ;0, 1, 2, 3
.db		0b11000011,0b01101011,0b01101111,0b10100010	 ;4, 5, 6, 7
.db		0b11101111,0b11101011,0b01101101,0b00000101	 ;8, 9, E, r
.db		0b11000111,0b01001100,0b00001111,0b00000001  ;H, L, o, -

		
setledgreen: lds tmp, fpledbuf ;зміна кольру світодіода статусу на зелений
		andi tmp, 0b11111101
		ori tmp, 0b00000001
		sts fpledbuf, tmp
		ret

setledred:lds tmp, fpledbuf ;зміна кольру світодіода статусу на червоний
		andi tmp, 0b11111110
		ori tmp, 0b00000010
		sts fpledbuf, tmp
		ret
							;підпрограми формування списку тривог
errpopupform:ldi xh, high(errslot1) ;завантаження адреси першого слота помилок
		ldi xl, low(errslot1)
		ldi reg3, 0 ;лічильник загальної кількості несправностей/попереджень
		ldi reg4, 0
elsf3:	cpi reg4, 8 ;перевірити чи вже перевірено 8 бітів з 2го регістра якщо так то перенести дані з 1го
		brne elsf1
		mov reg2, reg1
elsf1:	lsl reg2	;перевірка виконується починаючи з старшого регістру і старшого біту
		brcc elsf2	;перевірка чи біт С (прапорець помилки) встановлений
		ldi zh, high(2*dberpopcode) ;по номеру перевіреного біту витягується код спливаючого вікна з таблиці
		ldi zl, low(2*dberpopcode)
		add zl, reg4
		clr tmp
		adc zh, tmp
		lpm tmp, z
		st x+, tmp ;збереження коду події в слоті і інкремент адреси слота
		inc reg3 ;інкремент кількості несправностей/попереджень
elsf2:	inc reg4
		cpi reg4, 16 ;перевірка чи вже перевірено 16 бітів
		brne elsf3
		ret

dberpopcode:							;номери спливаючих вікон відносно стану бітів в gereg
.db		203,202,200,200,200,200,223,216
.db		200,218,217,217,200,205,206,207

.equ	errmask1 = $236
.equ	errmask2 = $237
.equ	eermsgdisplay = $238 ;режим виведеня вікна помилки/попередження(1) або стандартне вікно(0)
.equ	errmsgtiming = $239 ;час виведення вікна помилки/головного вікна
.equ	errslot1 = $23a	;слот для коду n ної події/несправності
.equ	errslot2 = $23b
.equ	errslot3 = $23c
.equ	errslot4 = $23d
.equ	errslot5 = $23e
.equ	errslot6 = $23f
.equ	errslot7 = $241
.equ	errslot8 = $242

startfpcont:ldi tmp, 0 
		sts errmask1, tmp
		sts errmask2, tmp
		sts eermsgdisplay, tmp
		sts errmsgtiming, tmp
		ret
		
slot12:	lds reg3, passfreg	;слот 12 - щосекундні функції 
		lds tmp, passmod	;Підпрограма блокування/розблокування пароля 
		ori tmp, 0b11111000 ;пароль запит на який непотрбен позначається 0 нульом в passmod, відповідно біти паролів 0-2 в passfreg
		and reg3, tmp		;маскуються і програма вважає що вони скинуті хоча вони завжди встановлені			
		cpi reg3, 0			
		breq slot12p3	;перевірка чи впринципі потрібен рахунок часу
		lds reg1, passsec
		inc reg1
		cpi reg1, 60
		brlo slot12p1
		ldi reg1, 0
		lds reg2, passmin
		inc reg2
		cpi reg2, 1
		brlo slot12p2
		ldi reg3, 0			
		ldi tmp, 2
		sts beepnck, tmp	;попередження про блокування/розблокування
slot12p2:sts passmin, reg2
slot12p1:sts passsec, reg1	
slot12p3:lds tmp, passmod	;0 означає що запит на відповідний тип паролю вимкнено
		com tmp				;інвертування 0 стають 1
		andi tmp, 0b00000111;відсічення лишнього
		or reg3, tmp		;примусове встановлення бітів для яких запит паролю вимкнено
		sts passfreg, reg3

slot12t:call gettime		;підпрограма опитування годинника, при потребі оновлення дисплея
		lds tmp, lcdsit
		cpi tmp, 0		
		brne slot12t1		;блокування оновлення якщо зараз не головний екран
		rcall refreshms	
		call lcdren
slot12t1:ldi tmp, 10
		sts slotr12, tmp

slot12l:bst gereg1, dsdtv	;підпрограма ведення логу температури
		brtc slot12m1 ;перевірка чи данні з датчика температури дійсні, якщо ні то вихід
		lds tmp, timemin
		cpi tmp, 13	;перевірка чи вже не більше 12 хвилин по годині, якщо більше то вихід
		brsh slot12m1
		ldi tmp, nvlastlogdateadr;зчитування з нврам даних про дату і час останнього запису в лог
		sts wordadrl, tmp
		call nvread
		lds reg1, i2cdata
		ldi tmp, nvlastlogtimeadr
		sts wordadrl, tmp
		call nvread
		lds reg2, i2cdata		
		lds reg3, timedate
		lds reg4, timehour
		cp reg3, reg1	;порівнювання дати останнього запису
		brne slo12l1		
		cp reg4, reg2	;порівнювання години останнього запису в лог
		breq slot12m1	;якщо рівно, то вихід				
slo12l1:lds tmp, timeyear	;запис в лог
		sts memdata4, tmp
		lds tmp, timemonth
		sts memdata3, tmp
		sts memdata2, reg3
		sts memdata1, reg4
		lds tmp, tempunib
		sts memdata5, tmp
		call storelog
		ldi tmp, nvlastlogdateadr;запис в нврам дати і часу останнього запису в лог
		sts wordadrl, tmp
		sts i2cdata, reg3
		call nvwrite
		ldi tmp, nvlastlogtimeadr
		sts wordadrl, tmp
		sts i2cdata, reg4
		call nvwrite

slot12m1:lds reg1, menuaectdn ;підпрограма автовиходу з меню в головний екран
		cpi reg1, 0			
		breq slot12m2
		dec reg1
		cpi reg1, 0
		brne slot12m2
		lds tmp, menusit
		cpi tmp, 0
		breq slot12m2
		ldi tmp, 0
		sts menusit, tmp
		sts lcdsit, tmp
slot12m2:sts menuaectdn, reg1

slot12ex:ret

useraktion:ldi tmp, 120 ;перезапуск таймера автовиходу з меню
		sts menuaectdn, tmp
		ret
refreshms:lds tmp, timeyear
		sts menuvar5, tmp
		lds tmp, timemonth
		sts menuvar4, tmp
		lds tmp, timedate
		sts menuvar3, tmp
		lds tmp, timemin
		sts menuvar2, tmp
		lds tmp, timehour
		sts menuvar1, tmp
		lds tmp, fantoff
		sts menuvar7, tmp
		lds tmp, fanton
		sts menuvar6, tmp
		ret	
			
.equ	menuaectdn = $267

;1 субпрограма переносу данних від програм які працюють у перериваннях/
;2 підпрограма алгоритму запуску
;3 контроль живлення, призупинення/відновлення виконання
;4 меню popup
;5 меню
;6 управління вентилятором/діагностика несправності
;7 управління насосом
;8 контроль поргових значень температури
;9 
;10запис в память подій
;11управління передньою панеллю/звуком
;12секундні функціЇ - опитування RTC/блокування та розблокування пароля/ведення логу/оновлення збраження 
					  ;перевірка порогових значень

						;Адреса байтів з налаштуваннями в EEPROM
.equ	eeind1adr = 0
.equ	eeind2adr = 1
.equ	eeind3adr = 2
.equ	eefantoffadr = 3
.equ	eefantonadr = 4
.equ	eetsetadr = 5
.equ	eetgistadr = 6
.equ	eegmodadr = 7
.equ	eefanmodadr = 8
.equ	eefansetmethodadr = 9
.equ	eepumpmodadr = 10
.equ	eepumptonadr = 11
.equ	eepumptoffadr = 12
.equ	eepumpemeradr = 13
.equ	eetrisemodadr = 14
.equ	eetrisemethodadr = 15
.equ	eetrisereladr = 16
.equ	eetriseabsadr = 17
.equ	eetfallmodadr = 18
.equ	eetfallmethodadr = 19
.equ	eetfallreladr = 20
.equ	eetfallabsadr = 21
.equ	eeloadalmadr = 22
.equ	eeloadtoutadr = 23
.equ	eesoundmodadr = 24
.equ	eefpbrieadr = 25
.equ	eelcdblmodadr = 26
.equ	eelcdbltoutadr = 27
.equ	eelcdcontadr = 28
.equ	eepassmodadr = 29
.equ	eepasstemp1adr = 30
.equ	eepasstemp2adr = 31
.equ	eepasstemp3adr = 32
.equ	eepassmod1adr = 33
.equ	eepassmod2adr = 34
.equ	eepassmod3adr = 35
.equ	eepassset1adr = 36
.equ	eepassset2adr = 37
.equ	eepassset3adr = 38
.equ	eelastevenuml = 39
.equ	eelastevenumh = 40
.equ	eelastlognuml = 41
.equ	eelastlognumh = 42

.equ	nvcorradr = 7	;регістр корекції
.equ	nvlastlogtimeadr = 8	;
.equ	nvlastlogdateadr = 9
.equ	nvcheck1 = 10 ;константа перевірки NVRAM 1 - 167
.equ	nvcheck2 = 11 ;константа перевірки NVRAM 2 - 37

.equ	fantoff = $180
.equ	fanton = $181
;.equ	;tsetadr = $182	;резерв
;.equ	;tgistadr = $183 ;резерв
.equ	gmod = $184
.equ	fanmod = $185
;.equ	;eefansetmethodadr = $186 ;резерв
.equ	pumpmod = $187
.equ	pumpton = $188
.equ	pumptoff = $189
.equ	pumpemer = $18a
.equ	trisemod = $18b
;.equ	;eetrisemethodadr = $18c ;резерв
.equ	triserel = $18d
;.equ	;eetriseabsadr = $18e ;резерв
.equ	tfallmod = $18f
;.equ	;eetfallmethodadr = $190 ;резерв
.equ	tfallrel = $191
;.equ	;eetfallabsadr = $192 ;резерв
.equ	loadalm = $193
.equ	loadtout = $194
.equ	soundmod = $195 ;біт 0 - звук клавіатури, біт 1 - звук несправностей, біт 2 - звук попереджень
.equ	fpdimmlevel = $196
.equ	lcdblmod = $197
.equ	lcdbltout = $198
.equ	lcdcontrast = $199
.equ	passmod = $19a

