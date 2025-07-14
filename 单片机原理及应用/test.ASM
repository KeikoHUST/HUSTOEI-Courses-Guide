$include (C8051F310.inc)

		;==========宏定义区域===============
ORG 0000H
LJMP START
ORG 0003H
LJMP EMERG								;INT0(P0.1,KINT)中断
ORG 001BH
LJMP DISPLAY							;T1中断显示数码管
		;==========用户主程序代码区==========
START:
	LCALL Init_Device
	MOV P3,#00H							;P3.1蜂鸣器关闭
	MOV P0,#0FFH						;P0.1中断,P0.6/P0.7位选择
	MOV P1,#60H							;数码管显示1
	MOV P2,#0FFH
	MOV IE,#8DH							;EA=EX1=ET1=EX0=1,ET0=0
	MOV TCON,#00H						;IT1=0
	MOV TMOD,#11H						;定时器T1,T0设为模式1
	MOV A,#60H
	MOV 4AH,#00H						;记录最终数据个数
	MOV R0,#60H
	MOV R4,#01H							;实际楼层
	MOV R6,#00H							;数码管显示控制(0:数码管0,以此类推)
	MOV R7,#01H
	MOV 2FH,#20							;记录楼层数目
	MOV DPTR,#SEGMENT_CODE				;数码管段码表
	MOV TH1,#0FCH
	MOV TL1,#02H

	MOV 60H,#0
	MOV 61H,#0
	MOV 62H,#0
	MOV 63H,#0
	MOV 64H,#0
	MOV 65H,#0
	MOV 66H,#0
	MOV 67H,#0
	MOV 68H,#0
	MOV 69H,#0
	MOV 6AH,#0
	MOV 6BH,#0
	MOV 6CH,#0
	MOV 6DH,#0
	MOV 6EH,#0
	MOV 6FH,#0
	MOV 70H,#0
	MOV 71H,#0
	MOV 72H,#0
	MOV 73H,#0

	SETB TR1

SCAN:
	LCALL KEYSCAN						;键盘扫描，必须多输入
	JZ SCAN								;A不能为00H	
	MOV R7,A
	MOV 4BH,@R0
	CJNE A,4BH,NO_REPEAT
	SJMP SCAN
NO_REPEAT:
	MOV @R0,A
	INC R0
	DJNZ 2FH,SCAN
	LCALL SORT
	MOV 2FH,#20
	MOV R0,#60H

LOOP:
	CLR 60H
	CLR 61H
	MOV A,@R0
	JZ FIN
	MOV R7,A
	MOV A,R7							;R7为目标楼层
	CJNE A,04H,RUN						;判断是否到达目标楼层
	SJMP FIN
RUN:
	MOV B,R7
	MOV A,R4
	CLR C
	SUBB A,B
	JC UP								;判断上楼/下楼
	DOWN:
		CLR 60H							;上升标志位置0
		SETB 61H						;下降标志位置1
		LCALL D2S						;延时2s
		DEC R4
		SJMP LOOP
	UP:
		CLR 61H							;下降标志位置0
		SETB 60H						;上升标志位置1
		LCALL D2S						;延时2s
		INC R4
		SJMP LOOP

FIN:
	SETB P3.1							;蜂鸣器响
	MOV R3,#10
	BARK:
	LCALL D10MS
	DJNZ R3,BARK
	CLR P3.1							;响0.5s
	LCALL JUDGE
	LCALL DOOR
	INC R0
	DJNZ 4AH,LOOP
	CLR P0.0
	
	MOV 60H,#0
	MOV 61H,#0
	MOV 62H,#0
	MOV 63H,#0
	MOV 64H,#0
	MOV 65H,#0
	MOV 66H,#0
	MOV 67H,#0
	MOV 68H,#0
	MOV 69H,#0
	MOV 6AH,#0
	MOV 6BH,#0
	MOV 6CH,#0
	MOV 6DH,#0
	MOV 6EH,#0
	MOV 6FH,#0
	MOV 70H,#0
	MOV 71H,#0
	MOV 72H,#0
	MOV 73H,#0
	
	MOV R0,#60H
	LJMP SCAN
	
		;==========用户子程序代码区==========
JUDGE:	
	MOV A,R7
	CLR C
	SUBB A,#01H
	JZ TB
	SUBB A,#07H
	JZ TB
	RET
TB:
	PUSH ACC
LOOP_LED:
	MOV A,#00000000B
	ACALL SEND_BYTE
	MOV 40H,#10
	FLASH1:LCALL D10MS
	DJNZ 40H,FLASH1
	MOV A,#11111111B
	ACALL SEND_BYTE
	MOV 40H,#10
	FLASH2:LCALL D10MS
	DJNZ 40H,FLASH2
	POP ACC
	RET
SEND_BYTE:
	MOV 41H,#8
	SEND_LOOP:MOV C,ACC.7
	MOV P3.3,C
	CLR P3.4
	SETB P3.4
	RL A
	DJNZ 41H,SEND_LOOP
	RET

KEYSCAN:
	LCALL IFKEY
	JNZ S1								;A=0？
	LCALL D10MS							;无键按下
	SJMP KEYSCAN						;重复键扫描
S1:
	LCALL D10MS							;消抖
	LCALL IFKEY
	JNZ S2
	SJMP KEYSCAN						;重复键扫描
S2:
	MOV R2,#0FEH
	MOV R1,#0							;行
S3:
	MOV P2,R2							;P2.0设低电平
	JB P2.4,L1							;检测P2.4电平
	MOV A,#00H							;P2.4低电平,K0(0)
	SJMP CAL
L1:
	JB P2.5,L2							;不是KO(0),检测P2.5电平
	MOV A,#04H							;P2.5低电平,K1(1)
	SJMP CAL
L2:
	JB P2.6,L3							;检测P2.6电平
	MOV A,#08H							;P2.6低电平,K2(2)
	SJMP CAL
L3:
	JB P2.7,NEXT						;检测P2.7电平
	MOV A,#0CH							;P2.7低电平,K3(3)
	SJMP CAL
NEXT:
	INC R1								;行+1
	MOV A,R2
	JNB ACC.3,KEYSCAN					;如果第四行也没检测到，重复键扫描
	RL A								;依次有P2.1,P2.2,P2.3,P2.4设低电平
	MOV R2,A
	SJMP S3								;测试下一行

CAL:
	ADD A,R1							;键值=列*4+行
	JZ INPUTWARN
	CLR C
	SUBB A,#09H
	JNC INPUTWARN
	ADD A,#09H
	RET

IFKEY:
	MOV P2,#0F0H
	MOV A,P2
	XRL A,#0F0H							;判断是否有键按下
	RET
INPUTWARN:
	MOV R5,#3
CYCLA:
	SETB P3.1
	MOV 42H,#30
	RING:LCALL D10MS
	DJNZ 42H,RING
	CLR P3.1
	CLR P0.0
	MOV 43H,#10
	LIGHT:LCALL D10MS
	DJNZ 43H,LIGHT
	SETB P0.0
	DJNZ R5,CYCLA
	SJMP KEYSCAN

DOOR:
DOOR_BEGIN:
	MOV A,#11111111B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR1:LCALL D10MS
	DJNZ 43H,DOOR1
	MOV A,#11100111B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR2:LCALL D10MS
	DJNZ 43H,DOOR2
	MOV A,#11000011B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR3:LCALL D10MS
	DJNZ 43H,DOOR3
	MOV A,#10000001B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR4:LCALL D10MS
	DJNZ 43H,DOOR4
	MOV A,#00000000B
	ACALL SEND_BYTE_DOOR
	ACALL D2S
	ACALL D2S
	MOV A,#10000001B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR5:LCALL D10MS
	DJNZ 43H,DOOR5
	MOV A,#11000011B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR6:LCALL D10MS
	DJNZ 43H,DOOR6
	MOV A,#11100111B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR7:LCALL D10MS
	DJNZ 43H,DOOR7
	MOV A,#11111111B
	ACALL SEND_BYTE_DOOR
	MOV 43H,#10
	DOOR8:LCALL D10MS
	DJNZ 43H,DOOR8
	RET
SEND_BYTE_DOOR:
	MOV 2DH,#8
SEND_LOOP_DOOR:
	MOV C,ACC.7
	MOV P3.3,C
	CLR P3.4
	SETB P3.4
	RL A
	DJNZ 2DH,SEND_LOOP_DOOR
	RET
		;==========中断服务程序==============
DISPLAY:								;T1溢出中断，用于数码管显示
	MOV P1,#00H							;数码管全部熄灭
	CJNE R6,#00H,TUBE1
TUBE0:									;数码管0显示当前楼层
		INC R6
		CLR P0.7						;位选数码管0
		CLR P0.6
		MOV A,R4
		MOVC A,@A+DPTR
		MOV P1,A
		AJMP RETDIS
TUBE1:									;数码管1显示下降状态
	CJNE R6,#01H,TUBE2			
		INC R6
		CLR P0.7
		SETB P0.6
		JB 61H,TUBE1_L					;判断下降标志位
		AJMP RETDIS
		TUBE1_L:MOV A,#1CH				;字母L段码
		MOV P1,A
		AJMP RETDIS
TUBE2:									;数码管2显示上升状态
	CJNE R6,#02H,TUBE3			
		INC R6
		SETB P0.7
		CLR P0.6
		JB 60H,TUBE2_H					;判断上升标志位
		AJMP RETDIS
		TUBE2_H:MOV A,#6EH				;字母H段码
		MOV P1,A
		AJMP RETDIS
TUBE3:									;数码管3显示目标楼层
		MOV R6,#00H
		SETB P0.7
		SETB P0.6
		MOV A,R7
		MOVC A,@A+DPTR
		MOV P1,A
RETDIS:
	MOV TL1,#02H
	MOV TH1,#0FCH
	RETI
;-----------------------------------------------------------------------
EMERG:									;INT0(P0.1,KINT)中断
	JNB P0.1,EMERG
	CPL 06H
	SETB P3.1
	MOV 4FH,#0FFH
	LOOP00:
	MOV 4EH,#0FFH
	LOOP11:
	NOP
	NOP
	NOP
	DJNZ 4EH,LOOP11
	DJNZ 4FH,LOOP00
    CLR P3.1
    RETI
;-----------------------------------------------------------------------
D2S:
	JNB 06H,$
	MOV 44H,#20							;6.125MHz时钟,单次周期100ms,100ms*20=2s
	MOV TH0,#38H
	MOV TL0,#9EH
	SETB TR0
	LDL2:
		JNB TF0,$						;等待T0溢出中断
		CLR TF0
		MOV TH0,#38H
		MOV TL0,#9EH
		DJNZ 44H,LDL2
	CLR TR0
	RET
;-----------------------------------------------------------------------
D10MS:
	JNB 06H,$
	MOV TH0,#0ECH
	MOV TL0,#10H
	SETB TR0

	JNB TF0,$
	CLR TF0
	CLR TR0
	RET

		;==========电梯排序算法模块==========
SORT:
    MOV R0, #60H
    MOV R1, #60H
    MOV A, @R0         					;读取第一个数据
    MOV @R1, A
    INC R1             					;目标指针后移
    MOV 5FH, #19        				;剩余19个数据需要处理（共20个）
    INC R0             					;源指针指向第二个数据

	PROCESS_LOOP:
    MOV A, @R0         					;读取当前源数据
    DEC R1             					;目标指针回退到前一个位置
    MOV B, @R1         					;获取前一个已存储的数据
    INC R1             					;恢复目标指针位置
    
    CJNE A, B, STORE_DATA  				;比较当前数据与前一个数据
    SJMP NEXT_DATA						;数据相同：跳过存储
	STORE_DATA:
    MOV @R1, A         					;存储新数据
    INC R1             					;目标指针后移
	NEXT_DATA:
    INC R0             					;移动到下一个源数据
    DJNZ 5FH, PROCESS_LOOP  			;处理所有数据
	ZEROO:
	CJNE R1,#74H,ZEROS
	SJMP FUN
	ZEROS:
    MOV @R1, #00H
	INC R1
	SJMP ZEROO

	FUN:
	MOV 45H,#0FFH						;L数据个数-1
	MOV 46H,#0FFH						;S数据个数-1
	MOV B,#0							;数据的个数(之后会被冲掉，但是存到R2了
	MOV R0,#60H							;数据首地址
	NUM:
	CJNE @R0,#0,NUM_NEXT
	SJMP BEGIN
	NUM_NEXT:
	INC R0
	INC B
	SJMP NUM
	BEGIN:
		MOV 4AH,B
		MOV A,B
		CJNE A,#1,NEEE
		RET
		NEEE:
		MOV A,60H
		MOV 29H,R4
	CJNE A,29H,SORT_JUDGE				;判断第一个数据和目标值大小，确定large/small两种模式
	SORT_JUDGE:							;大的数据放到50H首地址及之后，小的数据放到30H及之后
		MOV 05H,C
		MOV R0, #60H
		MOV R1, #30H
		MOV 47H, #50H
		MOV 48H, B
	SORT_LOOP:
		MOV A, @R0    
		MOV B, R4    
		CJNE A, B, COMPARE 
		JMP SORT_NEXT
	COMPARE:
		JC LESS
		INC 45H
		MOV R1, 47H
		MOV @R1, A
		INC 47H
		JMP SORT_NEXT
	LESS:
		INC 46H
		MOV @R1, A
		INC R1
	SORT_NEXT:
		INC R0
		DJNZ 48H, SORT_LOOP
		JB 05H,SMALL
	LARGE:								;先进行50H从小到大冒泡排序，再进行30H从大到小冒泡排序
		MOV 21H,45H
		MOV 22H,45H
		MOV R0,#50H
		LOP0L:
		MOV 21H,45H
		MOV R0,#50H
		LOP1L:MOV A,@R0
		INC R0
		MOV B,@R0
		CJNE A,B,COM1L
		COM1L:JC NEXT1L
		XCH A,B
		DEC R0
		MOV @R0,A
		INC R0
		MOV @R0,B
		JMP NEXT1L
		NEXT1L:DJNZ 21H,LOP1L
		DJNZ 22H,LOP0L
		MOV A,45H
		JZ LOCATELL
		INC A
		JZ LOCATELL
		MOV 26H,R0
		MOV 24H,46H
		MOV 25H,46H
		MOV R0,#30H
		LOP2L:
		MOV R0,#30H
		LOP3L:MOV A,@R0
		INC R0
		MOV B,@R0
		CJNE A,B,COM2L
		COM2L:JNC NEXT2L
		XCH A,B
		DEC R0
		MOV @R0,A
		INC R0
		MOV @R0,B
		JMP NEXT2L
		NEXT2L:DJNZ 24H,LOP2L
		DJNZ 25H,LOP3L
		MOV R0,26H

		LOCATELL:						;先存放大的数据，再存放小的数据
		INC 45H
		INC 46H
		MOV R0, #50H
		MOV R1, #60H
		MOV A, 45H
		JZ LOCATELL
		MOV 27H, A
		T_LOOPLL:
		MOV A, @R0
		MOV @R1, A
		INC R0
		INC R1
		DJNZ 27H, T_LOOPLL
	
		LOCATELS:
		MOV A,#60H
		ADD A,45H
		MOV R0,#30H
		MOV R1,A
		MOV A,46H
		JZ L_FIN
		MOV 28H, A
		T_LOOPLS:
		MOV A, @R0
		MOV @R1, A
		INC R0
		INC R1
		DJNZ 28H, T_LOOPLS
		L_FIN:
		RET

	SMALL:								;先进行30H从大到小冒泡排序，再进行50H从小到大冒泡排序
		MOV 21H,46H
		MOV 22H,46H
		MOV R0,#30H
		LOP0S:
		MOV 21H,46H
		MOV R0,#30H
		LOP1S:
		MOV A,@R0
		INC R0
		MOV B,@R0
		CJNE A,B,COM1S
		COM1S:JNC NEXT1S
		XCH A,B
		DEC R0
		MOV @R0,A
		INC R0
		MOV @R0,B
		JMP NEXT1S
		NEXT1S:DJNZ 21H,LOP1S
		DJNZ 22H,LOP0S

		MOV A,45H
		JZ LOCATESS
		INC A
		JZ LOCATESS
		MOV 26H,R0
		MOV 24H,45H
		MOV 25H,45H
		MOV R0,#50H
		LOP2S:
		MOV R0,#50H
		LOP3S:MOV A,@R0
		INC R0
		MOV B,@R0
		CJNE A,B,COM2S
		COM2S:JC NEXT2S
		XCH A,B
		DEC R0
		MOV @R0,A
		INC R0
		MOV @R0,B
		JMP NEXT2S
		NEXT2S:DJNZ 24H,LOP2S
		DJNZ 25H,LOP3S
		MOV R0,26H

		LOCATESS:					;先存放小的数据，再存放大的数据
		INC 45H
		INC 46H
		MOV R0, #30H
		MOV R1, #60H
		MOV A, 46H
		JZ LOCATESL
		MOV 27H, A
		T_LOOPSS:
		MOV A, @R0
		MOV @R1, A
		INC R0
		INC R1
		DJNZ 27H, T_LOOPSS

		LOCATESL:
		MOV A,#60H
		ADD A,46H
		MOV R0,#50H
		MOV R1,A
		MOV A,45H
		JZ S_FIN
		MOV 28H, A
		T_LOOPSL:
		MOV A, @R0
		MOV @R1, A
		INC R0
		INC R1
		DJNZ 28H, T_LOOPSL	
		S_FIN:RET
		;==========数码管段码表==============
SEGMENT_CODE:
    DB 0FCH 					;数字0段码
    DB 60H  					;数字1段码
    DB 0DAH 					;数字2段码
    DB 0F2H 					;数字3段码
    DB 66H  					;数字4段码
    DB 0B6H 					;数字5段码
    DB 0BEH 					;数字6段码
    DB 0E0H 					;数字7段码
    DB 0FEH 					;数字8段码
    DB 0F6H 					;数字9段码
		;==========配置向导生成的代码区======
PCA_Init:
    anl  PCA0MD,    #0BFh
    mov  PCA0MD,    #000h
	ret

Timer_Init:
    mov  TMOD,      #011h
    ret

Port_IO_Init:
    mov  P0MDOUT,   #0C0h
	mov  P1MDOUT,   #0FFh
	mov  P2MDOUT,   #00Fh
    mov  P3MDOUT,   #003h
    mov  XBR1,      #040h
    ret

Oscillator_Init:
    mov  OSCICN,    #081h
    ret

Init_Device:
    lcall PCA_Init
    lcall Timer_Init
    lcall Port_IO_Init
    lcall Oscillator_Init
    ret

END