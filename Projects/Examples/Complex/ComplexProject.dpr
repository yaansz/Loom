program ComplexProject;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Example.Complex.Config in 'Example.Complex.Config.pas',
  Example.Complex.AuthService in 'Example.Complex.AuthService.pas',
  Example.Complex.DataService in 'Example.Complex.DataService.pas',
  Example.Complex.App in 'Example.Complex.App.pas',
  Example.Complex.Main in 'Example.Complex.Main.pas',
  Loom.Attributes in '..\..\..\Source\Loom.Attributes.pas',
  Loom.Container in '..\..\..\Source\Loom.Container.pas',
  Loom.Container.DataTypes in '..\..\..\Source\Loom.Container.DataTypes.pas',
  Loom.Container.Registry in '..\..\..\Source\Loom.Container.Registry.pas',
  Loom.Container.Resolver in '..\..\..\Source\Loom.Container.Resolver.pas',
  Loom.Container.Injector in '..\..\..\Source\Loom.Container.Injector.pas',
  Loom.Container.Utils in '..\..\..\Source\Loom.Container.Utils.pas';

begin
  try
    TMain.Main;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
  ReadLn;
end.
