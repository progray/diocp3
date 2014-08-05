unit uDIOCPStreamCoder;

interface

uses
  uIocpCoder, uBuffer, Classes, SysUtils;

type
  TIOCPStreamDecoder = class(TIOCPDecoder)
  public
    /// <summary>
    ///   �����յ�������,����н��յ�����,���ø÷���,���н���
    /// </summary>
    /// <returns>
    ///   ���ؽ���õĶ���
    /// </returns>
    /// <param name="inBuf"> ���յ��������� </param>
    function Decode(const inBuf: TBufferLink): TObject; override;
  end;


  TIOCPStreamEncoder = class(TIOCPEncoder)
  public
    /// <summary>
    ///   ����Ҫ�����Ķ���
    /// </summary>
    /// <param name="pvDataObject"> Ҫ���б���Ķ��� </param>
    /// <param name="ouBuf"> ����õ����� </param>
    procedure Encode(pvDataObject:TObject; const ouBuf: TBufferLink); override;
  end;

implementation

uses
  uByteTools;

const
  PACK_FLAG = $D10;

  //PACK_FLAG  + STREAM_LEN + STREAM_DATA

  MAX_OBJECT_SIZE = 1024 * 1024 * 10;  //�������С 10M , ����10M �����Ϊ����İ���



function TIOCPStreamDecoder.Decode(const inBuf: TBufferLink): TObject;
var
  lvBytes, lvHeadBytes:SysUtils.TBytes;
  lvValidCount, lvReadL:Integer;
  lvPACK_FLAG:Word;
  lvDataLen: Integer;
  lvZiped:Byte;
begin
  Result := nil;

  //��������е����ݳ��Ȳ�����ͷ���ȣ�
  lvValidCount := inBuf.validCount;   //pack_flag + head_len + buf_len
  if (lvValidCount < SizeOf(Word) + SizeOf(Integer) + SizeOf(Integer)) then
  begin
    Exit;
  end;

  //��¼��ȡλ��
  inBuf.markReaderIndex;
  //setLength(lvBytes, 2);
  inBuf.readBuffer(@lvPACK_FLAG, 2);

  if lvPACK_FLAG <> PACK_FLAG then
  begin
    //����İ�����
    Result := TObject(-1);
    exit;
  end;

  //headlen
  inBuf.readBuffer(@lvReadL, SizeOf(lvReadL));
  lvDataLen := TByteTools.swap32(lvReadL);

  if lvDataLen > 0 then
  begin
    //�ļ�ͷ���ܹ���
    if lvDataLen > MAX_OBJECT_SIZE  then
    begin
      Result := TObject(-1);
      exit;
    end;

    if inBuf.validCount < lvDataLen then
    begin
      //����buf�Ķ�ȡλ��
      inBuf.restoreReaderIndex;
      exit;
    end;

    Result := TMemoryStream.Create;
    TMemoryStream(Result).SetSize(lvDataLen);
    inBuf.readBuffer(TMemoryStream(Result).Memory, lvDataLen);
    TMemoryStream(Result).Position := 0;
  end else
  begin
    Result := nil;
  end;
end;

{ TIOCPStreamEncoder }

procedure TIOCPStreamEncoder.Encode(pvDataObject: TObject;
  const ouBuf: TBufferLink);
var
  lvPACK_FLAG: WORD;
  lvDataLen, lvWriteIntValue: Integer;
  lvBuf: TBytes;
begin
  lvPACK_FLAG := PACK_FLAG;

  TStream(pvDataObject).Position := 0;

  if TStream(pvDataObject).Size > MAX_OBJECT_SIZE then
  begin
    if lvDataLen > MAX_OBJECT_SIZE then
      raise Exception.CreateFmt('���ݰ�̫��,����ҵ���ֲ���,������ݰ�[%d]!', [MAX_OBJECT_SIZE]);
  end;



  //pack_flag
  ouBuf.AddBuffer(@lvPACK_FLAG, 2);

  //
  lvDataLen := MAX_OBJECT_SIZE;
  lvWriteIntValue := TByteTools.swap32(lvDataLen);

  // stream len
  ouBuf.AddBuffer(@lvWriteIntValue, SizeOf(lvWriteIntValue));

  SetLength(lvBuf, lvDataLen);
  TStream(pvDataObject).Read(lvBuf[0], lvDataLen);

  // stream
  ouBuf.AddBuffer(@lvBuf[0], lvDataLen);  
end;

end.