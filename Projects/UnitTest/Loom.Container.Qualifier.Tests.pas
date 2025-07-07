unit Loom.Container.Qualifier.Tests;

interface

uses
  DUnitX.TestFramework,
  Loom.Container,
  Loom.Attributes;

type
  // Define qualifiers
  ProductionAttribute = class(QualifierAttribute);
  DevelopmentAttribute = class(QualifierAttribute);
  FastAttribute = class(QualifierAttribute);
  SecureAttribute = class(QualifierAttribute);
  NotValidAttribute = class(QUalifierAttribute);

  // Test interface
  IDatabase = interface
    ['{F7E57338-6A3C-45DE-906E-ED5C8A8A5D4F}']
    function GetType: string;
  end;

  // Implementations with qualifiers
  [Component]
  [Production]
  [Implements(IDatabase)]
  TProductionDatabase = class(TInterfacedObject, IDatabase)
  public
    function GetType: string;
  end;

  [Component]
  [Development]
  [Implements(IDatabase)]
  TDevelopmentDatabase = class(TInterfacedObject, IDatabase)
  public
    function GetType: string;
  end;

  [Component]
  [Fast]
  [Secure]
  [Implements(IDatabase)]
  TFastSecureDatabase = class(TInterfacedObject, IDatabase)
  public
    function GetType: string;
  end;

  // Test class with qualified injections
  [Component]
  TDataService = class
  private
    [Autowired]
    [Production]
    FProdDB: IDatabase;

    [Autowired]
    [Development]
    FDevDB: IDatabase;

    [Autowired]
    [Fast, Secure]
    FFastSecureDB: IDatabase;
  public
    property ProductionDB: IDatabase read FProdDB;
    property DevelopmentDB: IDatabase read FDevDB;
    property FastSecureDB: IDatabase read FFastSecureDB;
  end;

  [TestFixture]
  TQualifierTests = class
  private
    FContainer: LoomContainer;
  public
    [Setup]
    procedure Setup;
    [Teardown]
    procedure Teardown;

    [Test]
    procedure TestQualifiedInjection;

    [Test]
    procedure TestMultipleQualifiers;

    [Test]
    procedure TestAmbiguousResolution;

    [Test]
    procedure TestUnregisteredQualifier;

    [Test]
    procedure TestQualifiedConstructorInjection;
  end;

implementation

uses
  Loom.Container.Resolver;

{ TProductionDatabase }

function TProductionDatabase.GetType: string;
begin
  Result := 'Production';
end;

{ TDevelopmentDatabase }

function TDevelopmentDatabase.GetType: string;
begin
  Result := 'Development';
end;

{ TFastSecureDatabase }

function TFastSecureDatabase.GetType: string;
begin
  Result := 'FastSecure';
end;

{ TQualifierTests }

procedure TQualifierTests.Setup;
begin
  FContainer := LoomContainer.Create;
  // Auto-register components in this unit
  FContainer.AutoRegister('Loom.Container.Qualifier.Tests');
end;

procedure TQualifierTests.Teardown;
begin
  FContainer.Free;
end;

procedure TQualifierTests.TestQualifiedInjection;
var
  Service: TDataService;
begin
  Service := FContainer.Resolve<TDataService>;

  Assert.AreEqual('Production', Service.ProductionDB.GetType);
  Assert.AreEqual('Development', Service.DevelopmentDB.GetType);
end;

procedure TQualifierTests.TestMultipleQualifiers;
var
  Service: TDataService;
begin
  Service := FContainer.Resolve<TDataService>;

  Assert.AreEqual('FastSecure', Service.FastSecureDB.GetType);
end;

procedure TQualifierTests.TestAmbiguousResolution;
var
  Database: IDatabase;
begin
  Assert.WillRaise(
    procedure begin
      // Should fail - ambiguous without qualifier
      Database := FContainer.ResolveInterface<IDatabase>;
    end,
    EContainerResolveException
  );
end;

procedure TQualifierTests.TestUnregisteredQualifier;
var
  Database: IDatabase;
begin
  Assert.WillRaise(
    procedure begin
      // Try to resolve with unregistered qualifier
      Database := FContainer.ResolveQualifiedInterface<IDatabase>([NotValidAttribute.Create]);
    end,
    EContainerResolveException
  );
end;

procedure TQualifierTests.TestQualifiedConstructorInjection;
var
  Database: IDatabase;
begin
  // Resolve with specific qualifier
  Database := FContainer.ResolveQualifiedInterface<IDatabase>([DevelopmentAttribute.Create]);
  Assert.AreEqual('Development', Database.GetType);
end;

initialization
  TDUnitX.RegisterTestFixture(TQualifierTests);

  TDataService.ClassName;
  TFastSecureDatabase.ClassName;
  TDevelopmentDatabase.ClassName;
  TProductionDatabase.ClassName;

end.
