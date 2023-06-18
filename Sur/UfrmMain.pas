unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  Menus, StdCtrls, Buttons, ADODB,
  ComCtrls, ToolWin, ExtCtrls,
  inifiles,Dialogs,
  StrUtils, DB, ComObj,Variants,CPort, CoolTrayIcon;

type
  TfrmMain = class(TForm)
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    ADOConnection1: TADOConnection;
    CoolBar1: TCoolBar;
    ToolBar1: TToolBar;
    ToolButton8: TToolButton;
    ToolButton2: TToolButton;
    Memo1: TMemo;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Button1: TButton;
    ToolButton5: TToolButton;
    ToolButton9: TToolButton;
    OpenDialog1: TOpenDialog;
    ComPort1: TComPort;
    ComDataPacket1: TComDataPacket;
    ToolButton7: TToolButton;
    SaveDialog1: TSaveDialog;
    LYTray1: TCoolTrayIcon;
    procedure N3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    //���Ӳ�����Ϣ���м�¼,���ظü�¼��Ψһ�����Ϊ�������������
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure N1Click(Sender: TObject);
    procedure ToolButton2Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ToolButton5Click(Sender: TObject);
    procedure ComDataPacket1Packet(Sender: TObject; const Str: String);
    procedure ToolButton7Click(Sender: TObject);
    procedure ComPort1AfterOpen(Sender: TObject);
  private
    { Private declarations }
    procedure UpdateConfig;{�����ļ���Ч}
    function MakeDBConn:boolean;
    function DIFF_decode(const Value:string):string;
    function GetSpecNo(const Value:string):string; //ȡ��������
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses ucommfunction;

const
  CR=#$D+#$A;
  STX=#$2;ETX=#$3;ACK=#$6;NAK=#$15;
  sCryptSeed='lc';//�ӽ�������
  //SEPARATOR=#$1C;
  sCONNECTDEVELOP='����!���뿪������ϵ!' ;
  IniSection='Setup';

var
  ConnectString:string;
  GroupName:string;//
  SpecType:string ;//
  SpecStatus:string ;//
  CombinID:string;//
  LisFormCaption:string;//
  QuaContSpecNoG:string;
  QuaContSpecNo:string;
  QuaContSpecNoD:string;
  EquipChar:string;
  H_DTR_RTS:boolean;//DTR/RTS�ߵ�λ
  EquipUnid:integer;//�豸Ψһ���

//  RFM:STRING;       //��������
  hnd:integer;
  bRegister:boolean;

{$R *.dfm}

function ifRegister:boolean;
var
  HDSn,RegisterNum,EnHDSn:string;
  configini:tinifile;
  pEnHDSn:Pchar;
begin
  result:=false;
  
  HDSn:=GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'');

  CONFIGINI:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));
  RegisterNum:=CONFIGINI.ReadString(IniSection,'RegisterNum','');
  CONFIGINI.Free;
  pEnHDSn:=EnCryptStr(Pchar(HDSn),sCryptSeed);
  EnHDSn:=StrPas(pEnHDSn);

  if Uppercase(EnHDSn)=Uppercase(RegisterNum) then result:=true;

  if not result then messagedlg('�Բ���,��û��ע���ע�������,��ע��!',mtinformation,[mbok],0);
end;

function GetConnectString:string;
var
  Ini:tinifile;
  userid, password, datasource, initialcatalog: string;
  ifIntegrated:boolean;//�Ƿ񼯳ɵ�¼ģʽ

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  result:='';
  
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.INI'));
  datasource := Ini.ReadString('�������ݿ�', '������', '');
  initialcatalog := Ini.ReadString('�������ݿ�', '���ݿ�', '');
  ifIntegrated:=ini.ReadBool('�������ݿ�','���ɵ�¼ģʽ',false);
  userid := Ini.ReadString('�������ݿ�', '�û�', '');
  password := Ini.ReadString('�������ݿ�', '����', '107DFC967CDCFAAF');
  Ini.Free;
  //======����password
  pInStr:=pchar(password);
  pDeStr:=DeCryptStr(pInStr,sCryptSeed);
  setlength(password,length(pDeStr));
  for i :=1  to length(pDeStr) do password[i]:=pDeStr[i-1];
  //==========

  result := result + 'user id=' + UserID + ';';
  result := result + 'password=' + Password + ';';
  result := result + 'data source=' + datasource + ';';
  result := result + 'Initial Catalog=' + initialcatalog + ';';
  result := result + 'provider=' + 'SQLOLEDB.1' + ';';
  //Persist Security Info,��ʾADO�����ݿ����ӳɹ����Ƿ񱣴�������Ϣ
  //ADOȱʡΪTrue,ADO.netȱʡΪFalse
  //�����лᴫADOConnection��Ϣ��TADOLYQuery,������ΪTrue
  result := result + 'Persist Security Info=True;';
  if ifIntegrated then
    result := result + 'Integrated Security=SSPI;';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ComDataPacket1.StartString:=STX;
  ComDataPacket1.StopString:=ETX;

  ConnectString:=GetConnectString;
  UpdateConfig;
  if ifRegister then bRegister:=true else bRegister:=false;  

  Caption:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
  lytray1.Hint:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  action:=caNone;
  LYTray1.HideMainForm;
end;

procedure TfrmMain.N3Click(Sender: TObject);
begin
  if (MessageDlg('�˳��󽫲��ٽ����豸����,ȷ���˳���', mtWarning, [mbYes, mbNo], 0) <> mrYes) then exit;
  application.Terminate;
end;

procedure TfrmMain.N1Click(Sender: TObject);
begin
  LYTray1.ShowMainForm;
end;

procedure TfrmMain.UpdateConfig;
var
  INI:tinifile;
  CommName,BaudRate,DataBit,StopBit,ParityBit:string;
  autorun:boolean;
begin
  ini:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  CommName:=ini.ReadString(IniSection,'����ѡ��','COM1');
  BaudRate:=ini.ReadString(IniSection,'������','9600');
  DataBit:=ini.ReadString(IniSection,'����λ','8');
  StopBit:=ini.ReadString(IniSection,'ֹͣλ','1');
  ParityBit:=ini.ReadString(IniSection,'У��λ','None');
  H_DTR_RTS:=ini.readBool(IniSection,'DTR/RTS�ߵ�λ',false);
  autorun:=ini.readBool(IniSection,'�����Զ�����',false);

  GroupName:=trim(ini.ReadString(IniSection,'������',''));
  EquipChar:=trim(uppercase(ini.ReadString(IniSection,'������ĸ','')));//�������Ǵ�д������һʧ��
  SpecType:=ini.ReadString(IniSection,'Ĭ����������','');
  SpecStatus:=ini.ReadString(IniSection,'Ĭ������״̬','');
  CombinID:=ini.ReadString(IniSection,'�����Ŀ����','');

  LisFormCaption:=ini.ReadString(IniSection,'����ϵͳ�������','');
  EquipUnid:=ini.ReadInteger(IniSection,'�豸Ψһ���',-1);

  QuaContSpecNoG:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9999');
  QuaContSpecNo:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9998');
  QuaContSpecNoD:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9997');

  ini.Free;

  OperateLinkFile(application.ExeName,'\'+ChangeFileExt(ExtractFileName(Application.ExeName),'.lnk'),15,autorun);
  ComPort1.Close;
  ComPort1.Port:=CommName;
  if BaudRate='1200' then
    ComPort1.BaudRate:=br1200
    else if BaudRate='2400' then
      ComPort1.BaudRate:=br2400
    else if BaudRate='4800' then
      ComPort1.BaudRate:=br4800
      else if BaudRate='9600' then
        ComPort1.BaudRate:=br9600
        else if BaudRate='19200' then
          ComPort1.BaudRate:=br19200
          else ComPort1.BaudRate:=br9600;
  if DataBit='5' then
    ComPort1.DataBits:=dbFive
    else if DataBit='6' then
      ComPort1.DataBits:=dbSix
      else if DataBit='7' then
        ComPort1.DataBits:=dbSeven
        else if DataBit='8' then
          ComPort1.DataBits:=dbEight
          else ComPort1.DataBits:=dbEight;
  if StopBit='1' then
    ComPort1.StopBits:=sbOneStopBit
    else if StopBit='2' then
      ComPort1.StopBits:=sbTwoStopBits
      else if StopBit='1.5' then
        ComPort1.StopBits:=sbOne5StopBits
        else ComPort1.StopBits:=sbOneStopBit;
  if ParityBit='None' then
    ComPort1.Parity.Bits:=prNone
    else if ParityBit='Odd' then
      ComPort1.Parity.Bits:=prOdd
      else if ParityBit='Even' then
        ComPort1.Parity.Bits:=prEven
        else if ParityBit='Mark' then
          ComPort1.Parity.Bits:=prMark
          else if ParityBit='Space' then
            ComPort1.Parity.Bits:=prSpace
            else ComPort1.Parity.Bits:=prNone;
  try
    ComPort1.Open;
  except
    showmessage('����'+ComPort1.Port+'��ʧ��!');
  end;
end;

function TfrmMain.GetSpecNo(const Value:string):string; //ȡ��������
var
  ls:TStrings;
  i:integer;
begin
  ls:=TStringList.Create;
  ExtractStrings([#$D,#$A],[],Pchar(Value),ls);//��ÿ�е��뵽�ַ����б���

  for i :=0 to ls.Count-1 do
  begin
    if pos('���:',ls[i])>0 then
    begin
      result:=stringreplace(ls[i],'���:','',[rfReplaceAll,rfIgnoreCase]);
      result:='0000'+trim(result);
      result:=rightstr(result,4);
      break;
    end;
  end;
  ls.Free;
end;

function TfrmMain.DIFF_decode(const Value:string):string;
begin
  result:=stringreplace(Value,'#',' ',[rfReplaceAll,rfIgnoreCase]);
  result:=trim(result);
end;

function StrToList(const SourStr:string;const Separator:string):TStrings;
//����ָ���ķָ��ַ���(Separator)���ַ���(SourStr)���뵽�ַ����б���
var
  vSourStr,s:string;
  ll,lll:integer;
begin
  vSourStr:=SourStr;
  Result := TStringList.Create;
  lll:=length(Separator);

  while pos(Separator,vSourStr)<>0 do
  begin
    ll:=pos(Separator,vSourStr);
    Result.Add(copy(vSourStr,1,ll-1));
    delete(vSourStr,1,ll+lll-1);
  end;
  Result.Add(vSourStr);
  s:=vSourStr;
end;

function TListToVariant(AList:TList):OleVariant;
var
  P:Pointer;
begin
  Result:=VarArrayCreate([0,Sizeof(TList)],varByte);
  P:=VarArrayLock(Result);
  Move(AList,P^,Sizeof(TList));
  VarArrayUnLock(Result);
end;

function TfrmMain.MakeDBConn:boolean;
var
  newconnstr,ss: string;
  Label labReadIni;
begin
  result:=false;

  labReadIni:
  newconnstr := GetConnectString;
  try
    ADOConnection1.Connected := false;
    ADOConnection1.ConnectionString := newconnstr;
    ADOConnection1.Connected := true;
    result:=true;
  except
  end;
  if not result then
  begin
    ss:='������'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ݿ�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ɵ�¼ģʽ'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
        '�û�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '����'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('�������ݿ�','�������ݿ�',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

procedure TfrmMain.ToolButton2Click(Sender: TObject);
var
  ss:string;
begin
  ss:='����ѡ��'+#2+'Combobox'+#2+'COM1'+#13+'COM2'+#13+'COM3'+#13+'COM4'+#13+'COM5'+#13+'COM6'+#2+'0'+#2+#2+#3+
      '������'+#2+'Combobox'+#2+'19200'+#13+'9600'+#13+'4800'+#13+'2400'+#13+'1200'+#2+'0'+#2+#2+#3+
      '����λ'+#2+'Combobox'+#2+'8'+#13+'7'+#13+'6'+#13+'5'+#2+'0'+#2+#2+#3+
      'ֹͣλ'+#2+'Combobox'+#2+'1'+#13+'1.5'+#13+'2'+#2+'0'+#2+#2+#3+
      'У��λ'+#2+'Combobox'+#2+'None'+#13+'Even'+#13+'Odd'+#13+'Mark'+#13+'Space'+#2+'0'+#2+#2+#3+
      'DTR/RTS�ߵ�λ'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
      '������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '������ĸ'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '����ϵͳ�������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ����������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ������״̬'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Ŀ����'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Զ�����'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '�豸Ψһ���'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2;

  if ShowOptionForm('',Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  UpdateConfig;
end;

procedure TfrmMain.BitBtn2Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TfrmMain.BitBtn1Click(Sender: TObject);
begin
  SaveDialog1.DefaultExt := '.txt';
  SaveDialog1.Filter := 'txt (*.txt)|*.txt';
  if not SaveDialog1.Execute then exit;
  memo1.Lines.SaveToFile(SaveDialog1.FileName);
  showmessage('����ɹ�!');
end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  ls:Tstrings;
begin
  OpenDialog1.DefaultExt := '.txt';
  OpenDialog1.Filter := 'txt (*.txt)|*.txt';
  if not OpenDialog1.Execute then exit;
  ls:=Tstringlist.Create;
  ls.LoadFromFile(OpenDialog1.FileName);
  ComDataPacket1Packet(nil,ls.Text);
  ls.Free;
end;

procedure TfrmMain.ToolButton5Click(Sender: TObject);
var
  ss:string;
begin
  ss:='RegisterNum'+#2+'Edit'+#2+#2+'0'+#2+'���ô���������ϵ��ַ�������������,�Ի�ȡע����'+#2;
  if bRegister then exit;
  if ShowOptionForm(Pchar('ע��:'+GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'')),Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
    if ifRegister then bRegister:=true else bRegister:=false;
end;

procedure TfrmMain.ComDataPacket1Packet(Sender: TObject;
  const Str: String);
VAR
  SpecNo:string;
  ls,lsQXLD:TStrings;
  i,j:integer;
  dlttype:string;
  sValue:string;
  FInts:OleVariant;
  ReceiveItemInfo:OleVariant;
  QXLD:STRING;//ȫѪճ��,(1.00,21.68)(5.00,9.34)(50.00,5.38)(100.00,4.43)(200.00,3.99);(1.00,28.94)(2.00,18.60)(3.00,14.75)(4.00,12.67)(5.00,11.34)(6.00,10.41)(7.00,9.71)(8.00,9.16)(9.00,8.72)(10.00,8.36)(20.00,6.52)(30.00,5.78)(40.00,5.36)(50.00,5.08)(60.00,4.88)(70.00,4.73)(80.00,4.61)(90.00,4.51)(100.00,4.43)(150.00,4.15)(200.00,3.99)
begin
  if length(memo1.Lines.Text)>=60000 then memo1.Lines.Clear;//memoֻ�ܽ���64K���ַ�
  memo1.Lines.Add(Str);

  SpecNo:=GetSpecNo(Str);

  ls:=TStringList.Create;
  ExtractStrings([#$D,#$A],[],Pchar(Str),ls);//��ÿ�е��뵽�ַ����б���

  ReceiveItemInfo:=VarArrayCreate([0,ls.Count-1+5],varVariant);//+5:��ʾ5��ȫѪճ����Ŀ

  for i :=0 to ls.Count-1 do
  begin
    dlttype:=copy(ls[i],1,pos(':',ls[i])-1);
    sValue:=trim(copy(ls[i],pos(':',ls[i])+1,MaxInt));
    ReceiveItemInfo[i]:=VarArrayof([dlttype,sValue,'','']);

    if dlttype='ȫѪճ��' then QXLD:=copy(sValue,1,pos(';',sValue)-1);
  end;
  ls.Free;

  lsQXLD:=TStringList.Create;
  ExtractStrings(['(',')'],[],Pchar(QXLD),lsQXLD);
  for j :=0 to lsQXLD.Count-1 do
  begin
    if pos('1.00,',lsQXLD[j])>0 then ReceiveItemInfo[i]:=VarArrayof(['ȫѪճ��1',stringreplace(lsQXLD[j],'1.00,','',[]),'','']);
    if pos('5.00,',lsQXLD[j])>0 then ReceiveItemInfo[i+1]:=VarArrayof(['ȫѪճ��5',stringreplace(lsQXLD[j],'5.00,','',[]),'','']);
    if pos('50.00,',lsQXLD[j])>0 then ReceiveItemInfo[i+2]:=VarArrayof(['ȫѪճ��50',stringreplace(lsQXLD[j],'50.00,','',[]),'','']);
    if pos('100.00,',lsQXLD[j])>0 then ReceiveItemInfo[i+3]:=VarArrayof(['ȫѪճ��100',stringreplace(lsQXLD[j],'100.00,','',[]),'','']);
    if pos('200.00,',lsQXLD[j])>0 then ReceiveItemInfo[i+4]:=VarArrayof(['ȫѪճ��200',stringreplace(lsQXLD[j],'200.00,','',[]),'','']);
  end;
  lsQXLD.Free;
  
  if bRegister then
  begin
    FInts :=CreateOleObject('Data2LisSvr.Data2Lis');
    FInts.fData2Lis(ReceiveItemInfo,(SpecNo),'',
      (GroupName),(SpecType),(SpecStatus),(EquipChar),
      (CombinID),'',(LisFormCaption),(ConnectString),
      (QuaContSpecNoG),(QuaContSpecNo),(QuaContSpecNoD),'',
      false,true,'����',
      '',
      EquipUnid,
      '','','','',
      -1,-1,-1,-1,
      -1,-1,-1,-1,
      false,false,false,false);
    if not VarIsEmpty(FInts) then FInts:= unAssigned;
  end;
end;

procedure TfrmMain.ToolButton7Click(Sender: TObject);
begin
  if MakeDBConn then ConnectString:=GetConnectString;
end;

procedure TfrmMain.ComPort1AfterOpen(Sender: TObject);
begin
  if H_DTR_RTS then
  begin
    ComPort1.SetDTR(true);
    ComPort1.SetRTS(true);
  end;
end;

initialization
    hnd := CreateMutex(nil, True, Pchar(ExtractFileName(Application.ExeName)));
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        MessageBox(application.Handle,pchar('�ó������������У�'),
                    'ϵͳ��ʾ',MB_OK+MB_ICONinformation);   
        Halt;
    end;

finalization
    if hnd <> 0 then CloseHandle(hnd);

end.