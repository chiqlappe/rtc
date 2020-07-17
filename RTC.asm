
;PC-8001 RTC-4543SA用 リアルタイムクロックドライバ

;2020/07/17	BCDデコード追加
;2020/01/13	V1.0

;https://support.epson.biz/td/api/doc_check.php?dl=app_RTC-4543SA&lang=ja
;http://akizukidenshi.com/catalog/g/gK-10722/

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
RS232BUF	EQU	0EDCEH		;RS-232Cバッファ


	ORG	RS232BUF

	JP	READ_RTC	;
	JP	WRITE_RTC	;

TMRDATA:			;日時情報をBCD形式でセットしてWRITE_RTCをコールすると登録される
	DB	00H,00H,00H	;SEC,MIN,HOUR
	DB	00H		;WEEK
	DB	00H,00H,00H	;DAY,MONTH,YEAR

;-----------------------------
;RTCに日時情報を登録する
;-----------------------------
WRITE_RTC:
	CALL	INIT_RTC_WR	;
	LD	A,HI		;
	CALL	RTC_SET_WR	;RTCをデータ入力状態にする
	LD	A,HI		;
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
;RTCの日時情報をタイマーICに登録する
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
	CALL	DECODE_BCD	;BCDをデコードする
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


;-----------------------------
;BCDをバイナリに変換する
;IN	A=BCD
;OUT	A=BINARY
;-----------------------------
DECODE_BCD:
	PUSH	BC
	LD	B,A
	AND	00001111B
	LD	C,A		;C<-1の位
	LD	A,B
	SRL	A
	SRL	A
	SRL	A
	SRL	A
	AND	A
	JR	NZ,.L2
	LD	A,C
	JR	.L3
.L2:	LD	B,A		;B<-10の位
	LD	A,C
.L1:	ADD	A,10
	DJNZ	.L1
.L3:	POP	BC
	RET

;------------------------------------
;指定ビット数を読み出す
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
;1クロック HI→LO
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
;WRピンの状態をセットする
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_WR:
	ADD	A,RTC_WR	;
	OUT	(PPI_CTL),A	;
	RET			;

;------------------------------------
;CEピンの状態をセットする
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_CE:
	ADD	A,RTC_CE	;
	OUT	(PPI_CTL),A	;
	RET			;

;------------------------------------
;PPIのポートをMMC用にリセットする
;------------------------------------
RTC2MMC:
	LD	A,PPI_MMC	;
	OUT	(PPI_CTL),A	;
	IN	A,(PPI_B)	;
	OR	00001000B	;LED信号を降ろす(負論理)
	OUT	(PPI_B),A	;
	RET			;

;------------------------------------
;DATAピンのポート(A)を入力にセットする
;------------------------------------
INIT_RTC_RD:
	LD	A,10000000B + PA_IN
	JR	INIT_RTC

;------------------------------------
;DATAピンのポート(A)を出力にセットする
;------------------------------------
INIT_RTC_WR:
	LD	A,10000000B

INIT_RTC:
	OUT	(PPI_CTL),A	;
	XOR	A		;
	CALL	RTC_SET_CE	;CE<-LO
	RET			;


	END
