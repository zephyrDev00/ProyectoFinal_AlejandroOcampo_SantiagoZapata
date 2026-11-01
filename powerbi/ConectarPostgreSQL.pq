let
    Source = PostgreSQL.Database("localhost:5432", "vinilos_bi", [CreateNavigationProperties=false]),
    Dw = Source{[Schema="dw"]}[Data],
    FactProduction = Dw{[Name="fact_production"]}[Data]
in
    FactProduction
