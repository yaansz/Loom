unit Example.Complex.DataService;

interface

uses
  Loom.Attributes,
  Example.Complex.Config,
  Example.Complex.AuthService;

type
  IDataService = interface
    ['{3D3D87E9-DAF3-404F-ACA2-A92A87D54119}']
    function GetSecureData: string;
  end;

  [Service]
  [Implements(IDataService)]
  TAdvancedDataService = class(TInterfacedObject, IDataService)
  private
    FConfig: IConfig;
    FAuthService: IAuthService;
  public
    constructor Create(Config: IConfig; AuthService: IAuthService);
    function GetSecureData: string;
  end;

implementation

{ TAdvancedDataService }

constructor TAdvancedDataService.Create(Config: IConfig; AuthService: IAuthService);
begin
  FConfig := Config;
  FAuthService := AuthService;
end;

function TAdvancedDataService.GetSecureData: string;
begin
  if FAuthService.IsAuthenticated then
    Result := 'Sensitive Data: 42'
  else
    Result := 'Access Denied';
end;

end.
