[@inline] function verifyReserveFactor(
  const s               : rateStorage)
                        : unit is
  if s.lastUpdTime < Tezos.now
  then failwith("interestRate/need-update-reserveFactorFloat")
  else unit

[@inline] function mustBeAdmin(
  const s               : rateStorage)
                        : unit is
  if Tezos.sender =/= s.admin
  then failwith("interestRate/not-admin")
  else unit

[@inline] function calcUtilRate(
  const borrowsFloat    : nat;
  const cashFloat       : nat;
  const reservesFloat   : nat;
  const precision        : nat)
                        : nat is
  precision * borrowsFloat / abs(cashFloat + borrowsFloat - reservesFloat)

[@inline] function calcBorrowRate(
  const borrowsFloat    : nat;
  const cashFloat       : nat;
  const reservesFloat   : nat;
  const precision        : nat;
  const s               : rateStorage)
                        : nat is
  block {
    const utilizationRateFloat : nat = calcUtilRate(
      borrowsFloat,
      cashFloat,
      reservesFloat,
      precision
    );
    var borrowRateFloat : nat := 0n;

    if utilizationRateFloat < s.kickRateFloat
    then borrowRateFloat := (s.baseRateFloat + (utilizationRateFloat * s.multiplierFloat) / precision);
    else borrowRateFloat := ((s.kickRateFloat * s.multiplierFloat / precision + s.baseRateFloat) +
      (abs(utilizationRateFloat - s.kickRateFloat) * s.jumpMultiplierFloat) / precision);

  } with borrowRateFloat

function updateAdmin(
  const addr            : address;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.admin := addr;
  } with (noOperations, s)

function setYToken(
  const addr            : address;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.yToken := addr;
  } with (noOperations, s)

function setCoefficients(
  const param           : setCoeffParams;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    mustBeAdmin(s);
    s.kickRateFloat := param.kickRateFloat;
    s.baseRateFloat := param.baseRateFloat;
    s.multiplierFloat := param.multiplierFloat;
    s.jumpMultiplierFloat := param.jumpMultiplierFloat;
  } with (noOperations, s)

function getUtilizationRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const utilizationRateFloat : nat = calcUtilRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision
    );
    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = utilizationRateFloat;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function getBorrowRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    const borrowRateFloat : nat = calcBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision,
      s
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateFloat;
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function getSupplyRate(
  const param           : rateParams;
  const s               : rateStorage)
                        : rateReturn is
  block {
    verifyReserveFactor(s);

    const borrowRateFloat : nat = calcBorrowRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision,
      s
    );
    const utilizationRateFloat : nat = calcUtilRate(
      param.borrowsFloat,
      param.cashFloat,
      param.reservesFloat,
      param.precision
    );

    var operations : list(operation) := list[
      Tezos.transaction(record[
          tokenId = param.tokenId;
          amount = borrowRateFloat * utilizationRateFloat *
            abs(precision - s.reserveFactorFloat);
        ],
        0mutez,
        param.contract
      )
    ];
  } with (operations, s)

function updReserveFactor(
  const amt             : nat;
  var s                 : rateStorage)
                        : rateReturn is
  block {
    if Tezos.sender = s.yToken
    then block {
      s.reserveFactorFloat := amt;
      s.lastUpdTime := Tezos.now;
    }
    else failwith("interestRate/not-yToken")
  } with (noOperations, s)
