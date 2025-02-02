unit uBMP;
{$MODE objfpc}{$H+}
{$modeswitch advancedrecords}
interface
uses classes,SysUtils,FPImage, FPWritePNG;

const
    MaxArrayNum=1024*1024*2*2;
type
    rgbColor=record b,g,r:byte; end;

    BMPArray=array of byte;
    BMPRecord=record
      bmpBodySize:longint;
      BMPWidth,BMPHeight:longint;
      bmpfileheader : packed array[0..14-1] of byte;
      bmpinfoheader : packed array[0..40-1] of byte;
      bmpBody:array of byte;
      procedure new(x,y:integer);
      procedure SetPixel(x,y:integer;col:rgbColor);
      procedure WriteBMPFile(FN:string);
      procedure WritePPM(FN:String);
      procedure WritePNG(FN:String);
      procedure LoadPPM(FN:String);
    end;
implementation
procedure BMPRecord.new(x,y:longint);
var
  headersize, bfSize : longint;
  bits_per_pixel, cmap_entries : integer;
  i:integer;
begin
   BMPWidth:=x;BMPHeight:=y;
   bits_per_pixel := 24;
   cmap_entries := 0;
   headersize:=14+40;
   bfsize:=headersize+longint(x*y)*3;
   bmpBodySize:=longint(x*y)*3;
   SetLength(bmpBody,bmpBodySize);
   for i:=0 to 14-1 do bmpfileheader[i]:=0;
   for i:=0 to 40-1 do bmpinfoheader[i]:=0;

  { Fill the file header }
   bmpfileheader[0] := $42;	{ first 2 bytes are ASCII 'B', 'M' }
   bmpfileheader[1] := $4D;
  {PUT_4B(bmpfileheader, 2, bfSize);} { bfSize }
   bmpfileheader[2] := byte ((bfSize) and $FF);
   bmpfileheader[2+1] := byte (((bfSize) shr 8) and $FF);
   bmpfileheader[2+2] := byte (((bfSize) shr 16) and $FF);
   bmpfileheader[2+3] := byte (((bfSize) shr 24) and $FF);
  { we leave bfReserved1 & bfReserved2 = 0 }
  {PUT_4B(bmpfileheader, 10, headersize);} { bfOffBits }
   bmpfileheader[10] := byte (headersize and $FF);
   bmpfileheader[10+1] := byte ((headersize shr 8) and $FF);
   bmpfileheader[10+2] := byte ((headersize shr 16) and $FF);
   bmpfileheader[10+3] := byte ((headersize shr 24) and $FF);

  { Fill the info header (Microsoft calls this a BITMAPINFOHEADER) }
  {PUT_2B(bmpinfoheader, 0, 40);}   { biSize }
   bmpinfoheader[0] := byte ((40) and $FF);
   bmpinfoheader[0+1] := byte (((40) shr 8) and $FF);

  {PUT_4B(bmpinfoheader, 4, cinfo^.output_width);} { biWidth }
   bmpinfoheader[4] := byte ((x) and $FF);
   bmpinfoheader[4+1] := byte ((x shr 8) and $FF);
   bmpinfoheader[4+2] := byte ((x shr 16) and $FF);
   bmpinfoheader[4+3] := byte ((x shr 24) and $FF);
  {PUT_4B(bmpinfoheader, 8, cinfo^.output_height);} { biHeight }
   bmpinfoheader[8] := byte (y and $FF);
   bmpinfoheader[8+1] := byte ((y shr 8) and $FF);
   bmpinfoheader[8+2] := byte ((y shr 16) and $FF);
   bmpinfoheader[8+3] := byte ((y shr 24) and $FF);
  {PUT_2B(bmpinfoheader, 12, 1);}	{ biPlanes - must be 1 }
   bmpinfoheader[12] := byte (1 and $FF);
   bmpinfoheader[12+1] := byte ((1 shr 8) and $FF);

  {PUT_2B(bmpinfoheader, 14, bits_per_pixel);} { biBitCount }
   bmpinfoheader[14] := byte (bits_per_pixel and $FF);
   bmpinfoheader[14+1] := byte ((bits_per_pixel shr 8) and $FF);
  { we leave biCompression = 0, for none }
  { we leave biSizeImage = 0; this is correct for uncompressed data }
  { we leave biClrImportant := 0 }

end;

procedure BMPRecord.SetPixel(x,y:integer;col:rgbColor);
begin
   bmpBody[(y*BMPWidth+x)*3  ]:=col.b;
   bmpBody[(y*BMPWidth+x)*3+1]:=col.g;
   bmpBody[(y*BMPWidth+x)*3+2]:=col.r;

end;

procedure BMPRecord.WriteBMPFile(FN:string);
var
   B : file;
begin
   Assign(B,FN);rewrite(B,1);
   BlockWrite(B,bmpfileheader,14);
   Blockwrite(B,bmpInfoheader,40);
   blockwrite(b,bmpBody[0],bmpBodySize);
   Close(b);
end;

procedure BMPRecord.WritePPM(FN:string);
var
   f:text;
   x,y:integer;
begin
   assign(f,FN);rewrite(f);
   SetTextLineEnding(f,#10);
   writeln(f, 'P3');
   writeln(f,bmpWidth,' ',bmpHeight);
   writeln(f,255);
   for y:=bmpHeight-1 downto 0 do begin
      for x:=0 to bmpWidth-1 do begin
        writeln(f,bmpBody[(y*bmpWidth+x)*3+2],' ',
                bmpBody[(y*bmpWidth+x)*3+1],' ',
                bmpBody[(y*bmpWidth+x)*3]);
      end;
   end;
   close(f);
end;

procedure BMPRecord.WritePNG(FN:string);
var
    image : TFPCustomImage;
    writer : TFPWriterPNG;
    x,y:integer;
begin
  image := TFPMemoryImage.Create (bmpWidth,bmpHeight);
  Writer := TFPWriterPNG.Create;
  Writer.WordSized:=false;
  for y:=0 to bmpHeight-1 do
    for x:=0 to bmpWidth-1 do 
      image.colors[x,bmpHeight-y-1]
        :=FPColor(bmpBody[(y*bmpWidth+x)*3+2]*255,
                  bmpBody[(y*bmpWidth+x)*3+1]*255,
                  bmpBody[(y*bmpWidth+x)*3  ]*255);
  image.SaveToFile (FN, writer);
  image.Free;
  writer.Free;
end;

procedure BMPRecord.LoadPPM(FN:string);
var
  f:text;
  w,h,bd,x,y:integer;
  r,g,b:byte;
  st:string;
  suf:integer;
begin
  assign(f,FN);reset(f);
  readln(f,st);if st<>'P3' then begin close(f);exit;end;
  readln(f,w,h);
  new(w,h);
  readln(f,bd);
  for y:=0 to h-1 do begin
    for x:=0 to w-1 do begin
      readln(f,r,g,b);
      suf:=( (h-y-1)*bmpWidth+x)*3;
      bmpBody[suf+2]:=r;
      bmpBody[suf+1]:=g;
      bmpBody[suf  ]:=b;
    end;
  end;
end;

begin
end.
