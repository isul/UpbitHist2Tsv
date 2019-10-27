unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation, System.StrUtils,
{$IFDEF MSWINDOWS}
  Winapi.ShellAPI, Winapi.Windows,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  FMX.Platform, REST.Types, REST.Client, Data.Bind.Components,
  Data.Bind.ObjectScope, System.JSON, System.Generics.Collections;

type
  TfrmMain = class(TForm)
    btnConvert: TButton;
    mmoHistory: TMemo;
    Label1: TLabel;
    lblWebsite: TLabel;
    rstclntMarket: TRESTClient;
    rstrqstMarket: TRESTRequest;
    rstrspnsMarekt: TRESTResponse;
    grpOption: TGroupBox;
    rbSpace: TRadioButton;
    rbTab: TRadioButton;
    rbNone: TRadioButton;
    rstclntVersion: TRESTClient;
    rstrqstVersion: TRESTRequest;
    rstrspnsVersion: TRESTResponse;
    procedure btnConvertClick(Sender: TObject);
    procedure lblWebsiteClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FCheckVersion: Boolean;
    function OccurrencesOfChar(const S: string; const C: char): Integer;
    procedure CheckVersion;
    procedure OpenUrl(Url: string);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

const
  ROW_COUNT_PER_HISTORY = 9;
  API_UPBIT_MARKET = 'https://api.upbit.com/v1/market/all';
  API_VERSION = 'https://com-isulnara-datastore.appspot.com/data/upbithist2tsv/convert/com.isulnara.upbithist2tsv.version';
  APP_VERSION = '1.0';
  APP_URL = 'https://isulnara.com/wp/archives/2290';
  MY_WEBSITE = 'https://isulnara.com/';

implementation

{$R *.fmx}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FCheckVersion := False;
end;


procedure TfrmMain.FormActivate(Sender: TObject);
begin
  CheckVersion;
end;


procedure TfrmMain.btnConvertClick(Sender: TObject);
var
  i, j: Integer;
  Row, CsvResult: string;
  Clp: IFMXClipboardService;
  JaRoot: TJSONArray;
  JoMarket: TJSONObject;
  Market, Currency: string;
  Dictionary: TDictionary<string, string>;
  Key: string;

  function TryGetClipboardService(out _clp: IFMXClipboardService): Boolean;
  begin
    Result := TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService);
    if Result then
      _clp := IFMXClipboardService(TPlatformServices.Current.GetPlatformService(IFMXClipboardService));
  end;
begin
  CsvResult := '';
  Row := '';
  for i := 0 to mmoHistory.Lines.Count - 1 do
    begin
      Row := Row + mmoHistory.Lines[i];
      if (Row[Length(Row)] <> #9) and (OccurrencesOfChar(Row, #9) = ROW_COUNT_PER_HISTORY) then
        begin
          CsvResult := CsvResult + Row + #13#10;
          Row := '';
        end;
    end;

  CsvResult := CsvResult + Row;

  // 코인명 앞에 공백/탭 붙이기
  if not rbNone.IsChecked then
    begin
      rstclntMarket.BaseURL := API_UPBIT_MARKET;
      rstrqstMarket.Execute;
      if rstrspnsMarekt.JSONValue is TJSONArray then
        begin
          Dictionary := TDictionary<string, string>.Create();
          try
            JaRoot := rstrspnsMarekt.JSONValue as TJSONArray;
            for j := 0 to JaRoot.Count - 1 do
              begin
                if JaRoot.Items[j] is TJSONObject then
                  begin
                    JoMarket := JaRoot.Items[j] as TJSONObject;
                    Market := Copy(JoMarket.GetValue('market').Value, 0, Pos('-', JoMarket.GetValue('market').Value) - 1);
                    Currency := JoMarket.GetValue('market').Value.Replace(Market + '-', '');
                    if not Dictionary.ContainsKey(Market) then
                      Dictionary.Add(Market, Market);
                    if not Dictionary.ContainsKey(Currency) then
                      Dictionary.Add(Currency, Currency);
                  end;
              end;

            for Key in Dictionary.Keys do
              CsvResult := CsvResult.Replace(Key, IfThen(rbSpace.IsChecked, ' ', #9) + Key);
          finally
            Dictionary.Free;
          end;
        end;
    end;

  // 결과 클립보드에 붙여넣기
  if TryGetClipboardService(Clp) then
    begin
      Clp.SetClipboard(CsvResult);
      ShowMessage('변환된 내용이 클립보드에 복사되었습니다.');
    end
  else
    ShowMessage('클립보드를 사용할 수 없습니다.');
end;


function TfrmMain.OccurrencesOfChar(const S: string; const C: char): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(S) do
    if S[i] = C then
      Inc(Result);
end;


procedure TfrmMain.OpenUrl(Url: string);
begin
  {$IFDEF MSWINDOWS}
    ShellExecute(0, 'OPEN', PWideChar(Url), '', '', SW_SHOWNORMAL);
  {$ENDIF MSWINDOWS}
  {$IFDEF POSIX}
    _system(PAnsiChar('open ' + AnsiString(Url)));
  {$ENDIF POSIX}
end;

procedure TfrmMain.CheckVersion;
var
  JoRoot: TJSONObject;
  JoData: TJSONObject;
  NewVersion: string;
begin
  if FCheckVersion then
    Exit;
  FCheckVersion := True;
  rstclntVersion.BaseURL := API_VERSION;
  rstrqstVersion.Execute;
  if rstrspnsVersion.JSONValue is TJSONObject then
    begin
      JoRoot := rstrspnsVersion.JSONValue as TJSONObject;
      if JoRoot.GetValue('success') is TJSONTrue then
        begin
          JoData := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(JoRoot.GetValue('extra').Value.Replace('\', '')), 0) as TJSONObject;
          NewVersion := JoData.GetValue('dataValue').Value;
          if APP_VERSION <> NewVersion then
            begin
              ShowMessage('새 버전이 출시되었습니다. 최신 버전으로 업데이트하세요.'#13#10
                          + StringOfChar('─', 27) + #13#10 + JoData.GetValue('dataDesc').Value);
              OpenUrl(APP_URL);
            end;
        end;
    end;
end;


procedure TfrmMain.lblWebsiteClick(Sender: TObject);
begin
  OpenUrl(MY_WEBSITE);
end;

end.
