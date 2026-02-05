unit uObjLoader;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uTexture,uShape,StrUtils,streamex,types;

type 
  Vec3array=array of vec3;

  VertexArray=record
    objtype:string;
    v3ary:Vec3array;
    procedure new;
    procedure add(v:Vec3);
  end;

  ObjRecord=record
    FileStream:TFileStream;
    StreamReader:TStreamReader;
    Vary,VNary:VertexArray;
    procedure new;
    procedure FileLoad(FN:String);
  end;
    

implementation

procedure VertexArray.new;
begin
  objtype:='';
  SetLength(v3ary,0);
end;

procedure VertexArray.add(v:Vec3);
begin
  Insert(v,v3ary,length(v3ary) );
end;

procedure ObjRecord.new;
begin
  Vary.new;
  VNary.new;
end;

procedure ObjRecord.FileLoad(FN: String);
var
  s: string;
  SList: TStringDynArray;
  v0: Vec3;
begin
  if not FileExists(FN) then begin
    Writeln('File Does Not Exist!: ', FN);
    Halt;
  end;

  try
    try
      FileStream := TFileStream.Create(FN, fmOpenRead);
      StreamReader := TStreamReader.Create(FileStream);

      while not StreamReader.EOF do begin
        s := StreamReader.ReadLine.Trim; // Trimで前後の空白を消去
        writeln('s=>',s);
        if s = '' then continue; // 空行をスキップ

        // 文字列の1文字目をチェック
        if s[1] = 'v' then begin
          // 複数の連続するスペースを考慮する場合、SplitStringより正規表現や
          // 独自のパース関数が望ましいですが、一旦そのままにします
           SList := SplitString(s, ' ');

          // 要素数が足りているか必ずチェック
          if Length(SList) >= 4 then begin
            if SList[0] = 'v' then begin
              v0.x := StrToFloatDef(SList[1], 0);
              v0.y := StrToFloatDef(SList[2], 0);
              v0.z := StrToFloatDef(SList[3], 0);
              Vary.Add(v0);
            end
            else if SList[0] = 'vn' then begin
              v0.x := StrToFloatDef(SList[1], 0);
              v0.y := StrToFloatDef(SList[2], 0);
              v0.z := StrToFloatDef(SList[3], 0);
              VNary.Add(v0); // 法線用配列など別にするのが一般的です
            end;
          end;
        end;
      end;
    finally
      // StreamReaderをFreeすれば、関連付けられたFileStreamも解放されます
      StreamReader.Free;
    end;
  except
    on E: Exception do begin
      Writeln('エラーが発生しました: ', E.Message);
    end;
  end;
end;

begin
end.
