unit Example.Complex.AuthService;

interface

uses
  Loom.Attributes,
  Example.Complex.Config;

type
  IAuthService = interface
    ['{83ACF6D4-458B-4648-95E3-E426C670EFAA}']
    function IsAuthenticated: Boolean;
  end;

  [Service]
  [Implements(IAuthService)]
  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FConfig: IConfig;
  public
    constructor Create(Config: IConfig);
    function IsAuthenticated: Boolean;
  end;

implementation

{ TAuthService }

constructor TAuthService.Create(Config: IConfig);
begin
  FConfig := Config;
end;

function TAuthService.IsAuthenticated: Boolean;
begin
  Result := FConfig.GetValue('API_KEY') = 'SECRET-123';
end;

end.
