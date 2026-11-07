let
    Source = PostgreSQL.Database("localhost:5433", "vinilos_bi", [CreateNavigationProperties=false, HierarchicalNavigation=false]),
    FactProduction = Source{[Schema="dw", Item="fact_production"]}[Data]
in
    FactProduction
