unit Loom.Container.Injector;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  Loom.Attributes;

type
  EContainerInvalidAutowire = class(Exception);

  TClassResolver = reference to function(AClass: TClass): TObject;
  TIntfResolver  = reference to function(const IID: TGUID; Qualifiers: TArray<QualifierAttribute>): IInterface;

  TPropertyInjector = class
  private
    FResolveClass: TClassResolver;
    FResolveIntf: TIntfResolver;
    FContext: TRttiContext;

    procedure InjectFields(Instance: TObject; RttiType: TRttiType);
    procedure InjectProperties(Instance: TObject; RttiType: TRttiType);
    procedure HandleFieldInjection(Instance: TObject; Field: TRttiField);
    procedure HandlePropertyInjection(Instance: TObject; Prop: TRttiProperty);
  public
    constructor Create(ResolveClass: TClassResolver; ResolveIntf: TIntfResolver; Context: TRttiContext);
    procedure Inject(Instance: TObject);
  end;

implementation

uses
  Loom.Container.Utils;

{ TPropertyInjector }

constructor TPropertyInjector.Create(ResolveClass: TClassResolver; ResolveIntf: TIntfResolver; Context: TRttiContext);
begin
  FResolveClass := ResolveClass;
  FResolveIntf  := ResolveIntf;
  FContext      := Context;
end;

procedure TPropertyInjector.Inject(Instance: TObject);
var
  RttiType: TRttiType;
begin
  RttiType := FContext.GetType(Instance.ClassType);
  InjectFields(Instance, RttiType);
  InjectProperties(Instance, RttiType);
end;

procedure TPropertyInjector.InjectFields(Instance: TObject;
  RttiType: TRttiType);
var
  Field: TRttiField;
begin
  for Field in RttiType.GetFields do
  begin
    if Field.GetAttribute<AutowiredAttribute> <> nil then
      HandleFieldInjection(Instance, Field);
  end;
end;

procedure TPropertyInjector.InjectProperties(Instance: TObject; RttiType: TRttiType);
var
  Prop: TRttiProperty;
begin
  for Prop in RttiType.GetProperties do
  begin
    if Prop.GetAttribute<AutowiredAttribute> <> nil then
      HandlePropertyInjection(Instance, Prop);
  end;
end;

procedure TPropertyInjector.HandleFieldInjection(Instance: TObject; Field: TRttiField);
var
  PropValue: TObject;
  PropIntf: IInterface;
  ValueIntf: TValue;
begin
  if Field.FieldType.IsInstance then
  begin
    PropValue := FResolveClass(Field.FieldType.AsInstance.MetaclassType);
    Field.SetValue(Instance, TValue.From<TObject>(PropValue));
  end
  else if Field.FieldType.TypeKind = tkInterface then
  begin
    PropIntf := FResolveIntf(TRttiInterfaceType(Field.FieldType).GUID, TLoomUtils.GetQualifiers(Field.GetAttributes));
    TValue.Make(@PropIntf, Field.FieldType.Handle, ValueIntf);
    Field.SetValue(Instance, ValueIntf);
  end
  else
    raise EContainerInvalidAutowire.CreateFmt
      ('Autowired field must be class or interface type: %s.%s',
      [Instance.ClassName, Field.Name]);
end;

procedure TPropertyInjector.HandlePropertyInjection(Instance: TObject;
  Prop: TRttiProperty);
var
  PropValue: TObject;
  PropIntf: IInterface;
  ValueIntf: TValue;
begin
  if Prop.PropertyType.IsInstance then
  begin
    PropValue := FResolveClass(Prop.PropertyType.AsInstance.MetaclassType);
    Prop.SetValue(Instance, TValue.From<TObject>(PropValue));
  end
  else if Prop.PropertyType.TypeKind = tkInterface then
  begin
    PropIntf := FResolveIntf(TRttiInterfaceType(Prop.PropertyType).GUID, TLoomUtils.GetQualifiers(Prop.GetAttributes));
    TValue.Make(@PropIntf, Prop.PropertyType.Handle, ValueIntf);
    Prop.SetValue(Instance, ValueIntf);
  end
  else
    raise EContainerInvalidAutowire.CreateFmt
      ('Autowired property must be class or interface type: %s.%s',
      [Instance.ClassName, Prop.Name]);
end;

end.
