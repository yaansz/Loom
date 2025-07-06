unit Loom.Container.AutoRegister.Tests;

interface

uses
  DUnitX.TestFramework,
  Loom.Container,
  Loom.Attributes,
  Loom.Container.AutoRegister.Classes;

type
  [TestFixture]
  TTestAutoRegister = class
  private
    FContainer: LoomContainer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_AutoRegister_MatchingUnit_RegistersComponents;
    [Test]
    procedure Test_AutoRegister_MatchingUnit_RegistersServices;
    [Test]
    procedure Test_AutoRegister_NonMatchingUnit_ExcludesComponents;
    [Test]
    procedure Test_AutoRegister_UnattributedClass_NotRegistered;
  end;

implementation

uses
  System.SysUtils,
  Loom.Container.Resolver;

{ TTestAutoRegister }

procedure TTestAutoRegister.Setup;
begin
  FContainer := LoomContainer.Create;
end;

procedure TTestAutoRegister.TearDown;
begin
  FreeAndNil(FContainer);
end;

procedure TTestAutoRegister.Test_AutoRegister_MatchingUnit_RegistersComponents;
begin
  // Act: Register classes in current unit (pattern matches)
  FContainer.AutoRegister('Loom.Container.AutoRegister.*');

  // Assert: Component should resolve successfully
  Assert.WillNotRaiseAny(
    procedure
    begin
      FContainer.Resolve(TAutoTestComponent);
    end,
    'TAutoTestComponent should be registered'
  );
end;

procedure TTestAutoRegister.Test_AutoRegister_MatchingUnit_RegistersServices;
begin
  // Act
  FContainer.AutoRegister('Loom.Container.AutoRegister.*');

  // Assert: Service should resolve
  Assert.WillNotRaiseAny(
    procedure
    begin
      FContainer.Resolve(TAutoTestService);
    end,
    'TAutoTestService should be registered'
  );
end;

procedure TTestAutoRegister.Test_AutoRegister_NonMatchingUnit_ExcludesComponents;
begin
  // Act
  FContainer.AutoRegister('Non.Matching.Pattern.*');

  // Assert: Excluded component should NOT be registered
  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TExcludedComponent);
    end,
    EContainerResolveException,
    'TExcludedComponent should not be registered'
  );
end;

procedure TTestAutoRegister.Test_AutoRegister_UnattributedClass_NotRegistered;
begin
  // Act
  FContainer.AutoRegister('Loom.Container.AutoRegister.*');

  // Assert: Unattributed class should NOT be registered
  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TUnattributedClass);
    end,
    EContainerResolveException,
    'Unattributed classes must not be auto-registered'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoRegister);
end.
