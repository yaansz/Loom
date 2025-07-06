unit Example.Complex.Main;

interface

uses
  Loom.Container;

type
  TMain = class(TObject)
  public
    class procedure Main;
  end;

implementation

uses
  Example.Complex.App,
  Example.Complex.Config,
  Example.Complex.DataService,
  Example.Complex.AuthService;

class procedure TMain.Main;
var
  Container : LoomContainer;
  App       : TApp;
begin
  Container := LoomContainer.Create;
  try
    Container.AutoRegister('Example.Complex.*');

    App := Container.Resolve<TApp>;
    App.Run;
  finally
    Container.Free;
  end;
end;

initialization
  LoomContainer.ForceReferenceToClass(TApp);
  LoomContainer.ForceReferenceToClass(TFileConfig);
  LoomContainer.ForceReferenceToClass(TAdvancedDataService);
  LoomContainer.ForceReferenceToClass(TAuthService);

end.
