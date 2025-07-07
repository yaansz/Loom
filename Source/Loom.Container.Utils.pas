unit Loom.Container.Utils;

interface

uses
  Loom.Attributes;

type
  TLoomUtils = class
  public
    class function GetQualifiers(Attributes : TArray<TCustomAttribute>) : TArray<QualifierAttribute>;
  end;

implementation

class function TLoomUtils.GetQualifiers(Attributes: TArray<TCustomAttribute>): TArray<QualifierAttribute>;
begin
  Result := [];

  for var Attr in Attributes do
    begin
      if Attr is QualifierAttribute then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := QualifierAttribute(Attr);
        end;
    end;
end;

end.
