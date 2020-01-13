
;���A���^�C���N���b�N

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

A8255		EQU 	0FCH		;8255 �|�[�g�A�h���X
PPI_A		EQU	A8255		;
PPI_B		EQU	A8255+1		;
PPI_C		EQU	A8255+2		;
PPI_CTL		EQU	A8255+3		;
PPI_MMC		EQU	10000000B + PCH_IN	;MMC�h���C�o�Ŏg�p����8255�̃|�[�g�ݒ�

RTC_CE		EQU	00000000B	;PC0
RTC_WR		EQU	00000010B	;PC1
RTC_CLK		EQU	00000100B	;PC2


TIME_WRT	EQU	01663H		;���[�N�̓��������^�C�}IC�ɏ�������
TMRWRK		EQU	0EA76H		;�^�C�}�̃��[�N�G���A


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
	CALL	RTC_SET_WR	;RTC���f�[�^���͏�Ԃɂ���
	LD	A,HI
	CALL	RTC_SET_CE	;

	LD	HL,TMRDATA	;

	CALL	WSUB		;�b�A���A��

	LD	A,(HL)		;A<-�j��
	INC	HL		;
	LD	B,4		;
	CALL	SEND_DATA.E1	;

	CALL	WSUB		;���A���A�N

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
	RRA			;CY<-A��LSB
	RL	B		;B��LSB<-CY
	OUT	(C),B		;
	PUSH	AF		;
	CALL	RTC_CLOCK	;
	POP	AF		;
	POP	BC		;
	DJNZ	.L1		;
	RET			;

;------------------------------------
;[RTC]RTC�̓��������^�C�}�[IC�ɓo�^����
;------------------------------------
READ_RTC:
	CALL	INIT_RTC_RD	;

	XOR	A		;RTC���f�[�^�o�͏�Ԃɂ���
	CALL	RTC_SET_WR	;WR<-LO
	LD	A,HI		;
	CALL	RTC_SET_CE	;CE<-HI

	LD	HL,TMRWRK	;=�������ރA�h���X

	CALL	RTC_RECV	;�b
;	BIT	7,A		;FDT�r�b�g���`�F�b�N
;	JP	NZ,FDT_ERROR	;�����Ă�����G���[�I��
	AND	01111111B	;�s�v�ȃr�b�g�𗎂Ƃ�
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;��
	AND	01111111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;��
	AND	00111111B	;
	LD	(HL),A		;
	INC	HL		;

	LD	B,4		;�j��
	CALL	RTC_RECV.E1	;��ǂ�

	CALL	RTC_RECV	;��
	AND	00111111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;��
	AND	00011111B	;
	LD	(HL),A		;
	INC	HL		;

	CALL	RTC_RECV	;�N
	LD	(HL),A		;
	INC	A		;�N��"FF"�Ȃ���������^�C�}�[IC�ɓo�^���Ȃ�
	JR	Z,.L1		;
	CALL	TIME_WRT	;
.L1:	XOR	A		;RTC�̃f�[�^�o�͂��I������
	CALL	RTC_SET_CE	;
	JP	RTC2MMC		;

;------------------------------------
;[RTC]�w��r�b�g����ǂݏo��
;IN	B=�r�b�g��
;OUT	A=�ǂݍ��܂ꂽ�f�[�^
;------------------------------------
RTC_RECV:
	LD	B,8		;=�r�b�g��
.E1:	LD	C,0		;=����
.L1:	CALL	RTC_CLOCK	;
	IN	A,(PPI_A)	;
	RRA			;�r�b�g0=�f�[�^�r�b�g���L�����[�ɑ���
	RR	C		;C���W�X�^���E��]����MSB�ɃL�����[���Z�b�g����
	DJNZ	.L1		;8��J��Ԃ����ƂŁAC���W�X�^��1�o�C�g�̃f�[�^���i�[�����
	LD	A,C		;
	RET			;

;------------------------------------
;[RTC]1�N���b�N HI��LO
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
;[RTC]WR�s���̏�Ԃ��Z�b�g����
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_WR:
	ADD	A,RTC_WR	;
	OUT	(PPI_CTL),A	;
	RET			;

;------------------------------------
;[RTC]CE�s���̏�Ԃ��Z�b�g����
;IN	A:1=HI,0=LO
;------------------------------------
RTC_SET_CE:
	ADD	A,RTC_CE	;
	OUT	(PPI_CTL),A	;
	RET			;


;------------------------------------
;[RTC]PPI�̃|�[�g��MMC�p�Ƀ��Z�b�g����
;------------------------------------
RTC2MMC:
	LD	A,PPI_MMC	;
	OUT	(PPI_CTL),A	;

	IN	A,(PPI_B)	;
	OR	00001000B	;LED�M�����~�낷(���_��)
	OUT	(PPI_B),A	;

	RET

;------------------------------------
;[RTC]DATA�s���̃|�[�g(A)����͂ɃZ�b�g����
;------------------------------------
INIT_RTC_RD:
	LD	A,10000000B + PA_IN
	JR	INIT_RTC

;------------------------------------
;[RTC]DATA�s���̃|�[�g(A)���o�͂ɃZ�b�g����
;------------------------------------
INIT_RTC_WR:
	LD	A,10000000B

INIT_RTC:
	OUT	(PPI_CTL),A	;
	XOR	A		;
	CALL	RTC_SET_CE	;CE<-LO
	RET			;


	END
