flowchart LR
  Customer((Customer))
  Admin((Catalog Admin))
  Warehouse((Warehouse Staff))
  Analyst((Manager))
  PGW((Payment Gateway))

  subgraph System[Online Retail System]
    UC1(Browse Products)
    UC2(Place Order & Pay)
    UC3(Manage Catalog)
    UC4(Fulfill Order)
    UC5(Process Refund)
    UC6(View Sales Reports)
  end

  Customer -- browse/search --> UC1
  Customer -- place order --> UC2
  PGW -- process payment --> UC2
  Admin -- manage products --> UC3
  Warehouse -- ship orders --> UC4
  Admin -- issue refund --> UC5
  Analyst -- view reports --> UC6