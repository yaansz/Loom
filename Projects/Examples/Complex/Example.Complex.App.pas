unit Example.Complex.App;

interface

uses
  Loom.Attributes,
  Example.Complex.Config,
  Example.Complex.DataService,
  Example.Complex.AuthService;

type
  [Component]
  TApp = class
  private
    FConfig      : IConfig;
    FAuthService : IAuthService;
    FDataService : IDataService;
  public
    constructor Create(Config: IConfig; AuthService: IAuthService; DataService: IDataService);
    procedure Run;
  end;

implementation

uses
  System.SysUtils;

{ TApp }

constructor TApp.Create(Config: IConfig; AuthService: IAuthService;
  DataService: IDataService);
begin
  FConfig := Config;
  FAuthService := AuthService;
  FDataService := DataService;
end;

procedure TApp.Run;
begin
  WriteLn('Application started');
  WriteLn('Config value: ' + FConfig.GetValue('API_KEY'));
  WriteLn('Authenticated: ' + BoolToStr(FAuthService.IsAuthenticated, True));
  WriteLn(FDataService.GetSecureData);
  WriteLn('Application completed');
end;

end.
