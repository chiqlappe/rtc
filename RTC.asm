
;リアルタイムクロック

;--------------------------
;RTC	DIR	PPI	
;--------------------------
;DATA	IN	PA0
;CE	OUT	PC0 (PCL)
;WR	OUT	PC1 (PCL)
;CLK	OUT	PC2 (PCL)
;--------------------------

HI		EQU	1

PA_IN		EQU	00010000B
PB_IN		EQU	00000010B
PCL_IN		EQU	00000001B
PCH_IN		EQU	00001000B

A8255		EQU 	0FCH		;8255 ポートアドレス
PPI_A		EQU	A8255		;
PPI_B		EQU	A8255+1		;
PPI_C		EQU	A8255+2		;
PPI_CTL		EQU	A8255+3		;
PPI_MMC		EQU	10000000B + PCH_IN	;MMCドライバで使用する8255のポート設定

RTC_CE		EQU	00000000B	;PC0
RTC_WR		EQU	00000010B	;PC1
RTC_CLK		EQU	00000100B	;PC2


TIME_WRT	EQU	01663H		;ワークの日時情報をタイマICに書き込む
TMRWRK		EQU	0EA76H		;タイマのワークエリア


	ORG	0C000H

	JP	READ_RTC	;+00
	JP	WRITE_RTC	;+03

TMRDATA:			;+06
	DB	00H,00H,00H	;SEC(7),MIN(7),HOUR(6)
	DB	00H		;WEEK(3)
	DB	00H,00H,00H	;DAY(6),MONTH(5),YEAR(8)

;-----------------------------
;[RTC]
;-----------------------------
WRITE_RTC:
	CALL	INIT_RTC_WR	;
	LD	A,HI
	CALL	RTC_SET_WR	;RTCをデータ入力状態にする
	LD	A,HI
	CALL	RTC_SET_CE	;

	LD	HL,TMRDATA	;

	CALL	WSUB		;秒、分、時

	LD	A,(HL)		;A<-曜日
	INC	HL		;
	LD	B,4		;
	CALL	SEND_DATA.E1	;

	CALL	WSUB		;日、月、年

	XOR	A		;
	CALL	RTC_SET_CE	;
	JP	RTC2MMC		;

WSUB:	LD	B,3		;
.L1:	PUSH	BC		;
	LD	A,(HL)		;
	INC	HL		;
	CALL	SEND_DATA	;
	POP	BC		;
	DJNZ	.L1		;
	RET

SEND_DATA:
	LD	B,8		;
.E1:	LD	C,PPI_A		;
.L1:	PUSH	BC		;
	LD	B,0		;
	RRA			;CY<-AのLSB
	RL	B		;BのLSB<-CY
	OUT	(C),B		;
	PUSH	AF		;
	CALL	RTC_CLOCK	;
	POP	AF		;
	POP	BC		;
	DJNZ	.L1		;
	RET			;

;------------------------------------
;[RTC]RTCの日時情報をタイマーICに登録する
;------------------------------------
READ_RTC:
	CALL	INIT_RTC_RD	;

	XOR	A		;RTCをデータ出力状態にする
	CALL	RTC_SET_WR	;WR<-LO
	LD	A,HI		;
	CALL	RTC_SET_CE	;CE<-HI

	LD	HL,TMRWRK	;=書き込むアドレス

	CALL	RTC_RECV	;秒
;	BIT	7,A		;FDTビットをチェック
;	JP	NZ,FDT_ERROR	;立っていたらエラー終了
	AND	01111111B	;不要なビットを落とす
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;分
	AND	01111111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;時
	AND	00111111B	;
	LD	(HL),A		;
	INC	HL		;

	LD	B,4		;曜日
	CALL	RTC_RECV.E1	;空読み

	CALL	RTC_RECV	;日
	AND	00111111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;月
	AND	00011111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;年
	LD	(HL),A		;
	INC	A		;年が"FF"なら日時情報をタイマーICに登録しない
	JR	Z,.L1		;
	CALL	TIME_WRT	;
.L1:	XOR	A		;RTCのデータ出力を終了する
	CALL	RTC_SET_CE	;
	JP	RTC2MMC		;

;------------------------------------
;[RTC]指定ビット数を読み出す
;IN	B=ビット数
;OUT	A=読み込まれたデータ
;------------------------------------
RTC_RECV:
	LD	B,8		;=ビット数
.E1:	LD	C,0		;=結果
.L1:	CALL	RTC_CLOCK	;
	IN	A,(PPI_A)	;
	RRA			;ビット0=データビットをキャリーに送る
	RR	C		;Cレジスタを右回転してMSBにキャリーをセットする
	DJNZ	.L1		;8回繰り返すことで、Cレジスタに1バイトのデータが格納される
	LD	A,C		;
	RET			;

;------------------------------------
;[RTC]1クロック HI→LO
;------------------------------------
RTC_CLOCK:
	LD	A,RTC_CLK + HI	;
	OUT	(PPI_CTL),A	;
	NOP			;
	NOP			;
	NOP			;
	NOP			;
	LD	A,RTC_CLK	;
	OUT	(PPI_CTL),A	;
	NOP			;
	NOP			;
	NOP			;
	NOP			;
	RET			;

;------------------------------------
;[RTC]WRピンの状態をセットする
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_WR:
	ADD	A,RTC_WR	;
	OUT	(PPI_CTL),A	;
	RET			;

;------------------------------------
;[RTC]CEピンの状態をセットする
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_CE:
	ADD	A,RTC_CE	;
	OUT	(PPI_CTL),A	;
	RET			;


;------------------------------------
;[RTC]PPIのポートをMMC用にリセットする
;------------------------------------
RTC2MMC:
	LD	A,PPI_MMC	;
	OUT	(PPI_CTL),A	;

	IN	A,(PPI_B)	;
	OR	00001000B	;LED信号を降ろす(負論理)
	OUT	(PPI_B),A	;

	RET

;------------------------------------
;[RTC]DATAピンのポート(A)を入力にセットする
;------------------------------------
INIT_RTC_RD:
	LD	A,10000000B + PA_IN
	JR	INIT_RTC

;------------------------------------
;[RTC]DATAピンのポート(A)を出力にセットする
;------------------------------------
INIT_RTC_WR:
	LD	A,10000000B

INIT_RTC:
	OUT	(PPI_CTL),A	;
	XOR	A		;
	CALL	RTC_SET_CE	;CE<-LO
	RET			;


	END
