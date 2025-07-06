unit Example.Medium.Main;

interface

type
  TMain = class(TObject)
  public
    class procedure Main;
  end;

implementation

uses
  System.SysUtils,
  Loom.Container,
  Example.Medium.App;

class procedure TMain.Main;
var
  Container : LoomContainer;
  App       : TApp;
begin
  try
    Container := LoomContainer.Create;
    Container.AutoRegister('Example.Medium.*');

    App := Container.Resolve<TApp>;
    App.Run;

    App.Free;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
  ReadLn;
end;

end.
