unit Example.Complex.Config;

interface

uses
  Loom.Attributes;

type
  IConfig = interface
    ['{9114A1B1-BF33-488A-88AA-E57F2D468A50}']
    function GetValue(Key: string): string;
  end;

  [Service]
  [Implements(IConfig)]
  TFileConfig = class(TInterfacedObject, IConfig)
  public
    function GetValue(Key: string): string;
  end;

implementation

function TFileConfig.GetValue(Key: string): string;
begin
  if Key = 'API_KEY' then
    Result := 'SECRET-123'
  else
    Result := 'DEFAULT';
end;

end.
