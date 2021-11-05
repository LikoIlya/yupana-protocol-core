#include "./fa2Methods.ligo"
#include "./common.ligo"
#include "./adminMethods.ligo"

function ensureNotZero(
  const amt             : nat)
                        : unit is
    if amt = 0n
    then failwith("yToken/amount-is-zero");
    else unit

[@inline] function getBorrowRateContract(
  const rateAddress     : address)
                        : contract(rateParams) is
  case(
    Tezos.get_entrypoint_opt("%getBorrowRate", rateAddress)
                        : option(contract(rateParams))
  ) of
    Some(contr) -> contr
    | None -> (
      failwith("yToken/cant-get-interestRate-contract(getBorrowRate)")
        : contract(rateParams)
    )
  end;

[@inline] function ceil_div(
  const numerator       : nat;
  const denominator     : nat)
                        : nat is
  case ediv(numerator, denominator) of
    Some(result) -> if result.1 > 0n
      then result.0 + 1n
      else result.0
  | None -> failwith("ceil-div-error")
  end;

function verifyTokenUpdated(
    const token         : tokenInfo)
                        : unit is
    if token.interestUpdateTime < Tezos.now or token.priceUpdateTime < Tezos.now
    then failwith("yToken/need-update")
    else unit;


function calcMaxCollateralInCU(
  const userMarkets     : set(tokenId);
  const user            : address;
  const ledger          : big_map((address * tokenId), nat);
  const tokenInfo       : map(tokenId, tokenInfo))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      const tokenId     : tokenId)
                        : nat is
      block {
        const userBalanceInfo : nat = getBalanceByToken(user, tokenId, ledger);
        const token : tokenInfo = getTokenInfo(tokenId, tokenInfo);
        const numerator : nat =
          case is_nat(token.totalLiquidFloat + token.totalBorrowsFloat - token.totalReservesFloat) of
            | None -> (failwith("underflow/totalLiquidFloat+totalBorrowsFloat") : nat)
            | Some(value) -> value
          end;

        (* sum += collateralFactorFloat * exchangeRate * oraclePrice * balance *)
        acc := acc + ((userBalanceInfo * token.lastPrice
          * token.collateralFactorFloat) * (numerator / token.totalSupplyFloat) / precision);
      } with acc;
    const result : nat = Set.fold(
      oneToken,
      userMarkets,
      0n
    );
  } with result

type accountsMapType is big_map((address * tokenId), account);

function applyInterestToBorrows(
  const borrowedTokens      : set(tokenId);
  const user                : address;
  const accountsMap         : accountsMapType;
  const tokensMap           : map(tokenId, tokenInfo))
                            : accountsMapType is
  block {
    function oneToken(
      var userAccountsMap : accountsMapType;
      const tokenId       : tokenId)
                          : accountsMapType is
      block {
        var userAccount : account := getAccount(user, tokenId, accountsMap);
        const tokenInfo : tokenInfo = getTokenInfo(tokenId, tokensMap);

        if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
            tokenInfo.borrowIndex /
            userAccount.lastBorrowIndex;
          else skip;
      } with Map.update((user, tokenId), Some(userAccount), userAccountsMap);

    const result  = Set.fold(
      oneToken,
      borrowedTokens,
      accountsMap
    );
  } with (result)

function calcOutstandingBorrowInCU(
  const userBorrow      : set(tokenId);
  const user            : address;
  const accountInfo     : big_map((address * tokenId), account);
  const ledger          : big_map((address * tokenId), nat);
  const tokenInfo       : map(tokenId, tokenInfo))
                        : nat is
  block {
    function oneToken(
      var acc           : nat;
      var tokenId       : tokenId)
                        : nat is
      block {
        const userAccount : account = getAccount(user, tokenId, accountInfo);
        const userBalance : nat = getBalanceByToken(user, tokenId, ledger);
        var tokenInfo : tokenInfo := getTokenInfo(tokenId, tokenInfo);

        (* sum += oraclePrice * borrow *)
        if userBalance > 0n or userAccount.borrow > 0n
        then acc := acc + ((userAccount.borrow * tokenInfo.lastPrice));
        else skip;
      } with acc;
    const result : nat = Set.fold(
      oneToken,
      userBorrow,
      0n
    );
  } with result

function updateInterest(
  const tokenId         : nat;
  var s                 : fullTokenStorage)
                        : fullReturn is
    block {
      var _token : tokenInfo := getTokenInfo(tokenId, s.storage.tokenInfo);
      var operations : list(operation) := list[];

      if tokenId < s.storage.lastTokenId
      then skip
      else failwith("yToken/yToken-undefined");

      if _token.totalBorrowsFloat = 0n
      then block {
        _token.interestUpdateTime := Tezos.now;
        s.storage.tokenInfo[tokenId] := _token;
      }
      else block {
        _token.isInterestUpdating := True;
        operations := list[
        Tezos.transaction(
          record[
            tokenId = tokenId;
            borrowsFloat = _token.totalBorrowsFloat;
            cashFloat = _token.totalLiquidFloat;
            reservesFloat = _token.totalReservesFloat;
            reserveFactorFloat = _token.reserveFactorFloat;
            precision = precision;
            callback = (Tezos.self("%accrueInterest") : contract(yAssetParams));
          ],
          0mutez,
          getBorrowRateContract(_token.interestRateModel)
        )];
        s.storage.tokenInfo[tokenId] := _token;
      }
    } with (operations, s)

function mint(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Mint(yAssetParams) -> {
          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var mintTokensFloat : nat := yAssetParams.amount * precision;
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          if token.totalSupplyFloat =/= 0n
          then {
            verifyTokenUpdated(token);

            const numerator : nat =
              case is_nat(token.totalLiquidFloat + token.totalBorrowsFloat - token.totalReservesFloat) of
                | None -> (failwith("underflow/totalLiquidFloat+totalBorrowsFloat") : nat)
                | Some(value) -> value
              end;

            mintTokensFloat := mintTokensFloat * token.totalSupplyFloat / numerator;
          } else skip;

          var userBalanceInfo : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);
          userBalanceInfo := userBalanceInfo + mintTokensFloat;

          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userBalanceInfo;
          token.totalSupplyFloat := token.totalSupplyFloat + mintTokensFloat;
          token.totalLiquidFloat := token.totalLiquidFloat
            + yAssetParams.amount * precision;
          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.sender, Tezos.self_address, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function redeem(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Redeem(yAssetParams) -> {
          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          verifyTokenUpdated(token);

          if Set.mem(yAssetParams.tokenId, getTokenIds(Tezos.sender, s.markets))
          then failwith("yToken/token-taken-as-collateral")
          else skip;

          var userBalanceInfo : nat := getBalanceByToken(Tezos.sender, yAssetParams.tokenId, s.ledger);

          const liquidityFloat : nat =
            case is_nat(token.totalLiquidFloat + token.totalBorrowsFloat - token.totalReservesFloat) of
              | None -> (failwith("underflow/totalLiquidFloat+totalBorrowsFloat") : nat)
              | Some(value) -> value
            end;

          const redeemAmount : nat = if yAssetParams.amount = 0n
          then userBalanceInfo * liquidityFloat / token.totalSupplyFloat / precision
          else yAssetParams.amount;

          if redeemAmount * precision > token.totalLiquidFloat
          then failwith("yToken/not-enough-liquid")
          else skip;

          var burnTokensFloat : nat := redeemAmount * precision *
            token.totalSupplyFloat / liquidityFloat;
          if userBalanceInfo < burnTokensFloat
          then failwith("yToken/not-enough-tokens-to-burn")
          else skip;

          userBalanceInfo :=
            case is_nat(userBalanceInfo - burnTokensFloat) of
              | None -> (failwith("underflow/userBalanceInfo") : nat)
              | Some(value) -> value
            end;

          s.ledger[(Tezos.sender, yAssetParams.tokenId)] := userBalanceInfo;
          token.totalSupplyFloat :=
            case is_nat(token.totalSupplyFloat - burnTokensFloat) of
              | None -> (failwith("underflow/totalSupplyFloat") : nat)
              | Some(value) -> value
            end;

          token.totalLiquidFloat :=
            case is_nat(token.totalLiquidFloat - redeemAmount * precision) of
              | None -> (failwith("underflow/totalLiquidFloat") : nat)
              | Some(value) -> value
            end;

          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.self_address, Tezos.sender, redeemAmount, token.mainToken);
        }
      | _               -> skip
      end
  } with (operations, s)

function borrow(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Borrow(yAssetParams) -> {
          ensureNotZero(yAssetParams.amount);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accountInfo);
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrowInfo);

          verifyTokenUpdated(token);

          if token.borrowPause
          then failwith("yToken/forbidden-for-borrow");
          else skip;

          const borrowsFloat : nat = yAssetParams.amount * precision;

          if borrowsFloat > token.totalLiquidFloat
          then failwith("yToken/amount-too-big")
          else skip;

          // if userAccount.lastBorrowIndex =/= 0n
          // then userAccount.borrow := userAccount.borrow *
          //     token.borrowIndex / userAccount.lastBorrowIndex;
          // else skip;

          s.accountInfo := applyInterestToBorrows(borrowTokens, Tezos.sender, s.accountInfo, s.tokenInfo);
          borrowTokens := Set.add(yAssetParams.tokenId, borrowTokens);

          userAccount.lastBorrowIndex := token.borrowIndex;
          userAccount.borrow := userAccount.borrow + borrowsFloat;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          s.borrowInfo[Tezos.sender] := borrowTokens;

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            getTokenIds(Tezos.sender, s.markets),
            Tezos.sender,
            s.ledger,
            s.tokenInfo
          );

          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrowInfo),
            Tezos.sender,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then failwith("yToken/exceeds-the-permissible-debt");
          else skip;

          token.totalBorrowsFloat := token.totalBorrowsFloat + borrowsFloat;
          token.totalLiquidFloat :=
            case is_nat(token.totalLiquidFloat - borrowsFloat) of
              | None -> (failwith("underflow/totalLiquidFloat") : nat)
              | Some(value) -> value
            end;

          s.tokenInfo[yAssetParams.tokenId] := token;

          operations := transfer_token(Tezos.self_address, Tezos.sender, yAssetParams.amount, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function repay(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Repay(yAssetParams) -> {
          var token : tokenInfo := getTokenInfo(yAssetParams.tokenId, s.tokenInfo);

          if yAssetParams.tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          verifyTokenUpdated(token);

          var repayAmountFloat : nat := yAssetParams.amount * precision;

          var userAccount : account := getAccount(Tezos.sender, yAssetParams.tokenId, s.accountInfo);
          var borrowTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrowInfo);

          if userAccount.lastBorrowIndex =/= 0n
          then userAccount.borrow := userAccount.borrow *
            token.borrowIndex / userAccount.lastBorrowIndex;
          else skip;

          if repayAmountFloat = 0n
          then repayAmountFloat := userAccount.borrow;
          else skip;

          if repayAmountFloat > userAccount.borrow
          then failwith("yToken/amount-should-be-less-or-equal")
          else skip;

          userAccount.borrow :=
            case is_nat(userAccount.borrow - repayAmountFloat) of
              | None -> (failwith("underflow/userAccount.borrow") : nat)
              | Some(value) -> value
            end;

          if userAccount.borrow = 0n
          then borrowTokens := Set.remove(yAssetParams.tokenId, borrowTokens);
          else skip;

          userAccount.lastBorrowIndex := token.borrowIndex;
          s.accountInfo[(Tezos.sender, yAssetParams.tokenId)] := userAccount;
          token.totalBorrowsFloat :=
            case is_nat(token.totalBorrowsFloat - repayAmountFloat) of
              | None -> (failwith("underflow/totalBorrowsFloat") : nat)
              | Some(value) -> value
            end;

          token.totalLiquidFloat := token.totalLiquidFloat + repayAmountFloat;
          s.tokenInfo[yAssetParams.tokenId] := token;
          s.borrowInfo[Tezos.sender] := borrowTokens;

          const value : nat = ceil_div(repayAmountFloat, precision);
          operations := transfer_token(Tezos.sender, Tezos.self_address, value, token.mainToken);
        }
      | _                         -> skip
      end
  } with (operations, s)

function liquidate(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    var operations : list(operation) := list[];
      case p of
        Liquidate(params) -> {
          ensureNotZero(params.amount);

          if params.borrowToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(borrowToken)");

          if params.collateralToken < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined(collateralToken)");

          var borrowerAccount : account := getAccount(params.borrower, params.borrowToken, s.accountInfo);
          var borrowToken : tokenInfo := getTokenInfo(params.borrowToken, s.tokenInfo);
          var userBorrowedTokens : set(tokenId) := getTokenIds(params.borrower, s.borrowInfo);

          verifyTokenUpdated(borrowToken);

          if Tezos.sender = params.borrower
          then failwith("yToken/borrower-cannot-be-liquidator")
          else skip;

          s.accountInfo := applyInterestToBorrows(userBorrowedTokens, params.borrower, s.accountInfo, s.tokenInfo);

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            getTokenIds(params.borrower, s.markets),
            params.borrower,
            s.ledger,
            s.tokenInfo
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(params.borrower, s.borrowInfo),
            params.borrower,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU > maxBorrowInCU
          then skip
          else failwith("yToken/liquidation-not-achieved");
          if borrowerAccount.borrow = 0n
          then failwith("yToken/debt-is-zero");
          else skip;

          var liqAmountFloat : nat := params.amount * precision;


          (* liquidate amount can't be more than allowed close factor *)
          const maxClose : nat = borrowerAccount.borrow * s.closeFactorFloat
            / precision;

          if liqAmountFloat <= maxClose
          then skip
          else failwith("yToken/too-much-repay");

          borrowerAccount.borrow :=
            case is_nat(borrowerAccount.borrow - liqAmountFloat) of
              | None -> (failwith("underflow/borrowerAccount.borrow") : nat)
              | Some(value) -> value
            end;

          if borrowerAccount.borrow = 0n
          then userBorrowedTokens := Set.remove(params.borrowToken, userBorrowedTokens);
          else skip;

          borrowerAccount.lastBorrowIndex := borrowToken.borrowIndex;
          borrowToken.totalBorrowsFloat :=
            case is_nat(borrowToken.totalBorrowsFloat - liqAmountFloat) of
              | None -> (failwith("underflow/totalBorrowsFloat") : nat)
              | Some(value) -> value
            end;

          borrowToken.totalLiquidFloat := borrowToken.totalLiquidFloat + liqAmountFloat;

          operations := transfer_token(Tezos.sender, Tezos.self_address, params.amount, borrowToken.mainToken);

          if getTokenIds(params.borrower, s.markets) contains params.collateralToken
          then skip
          else failwith("yToken/collateralToken-not-contains-in-borrow-market");

          var collateralToken : tokenInfo := getTokenInfo(params.collateralToken, s.tokenInfo);

          verifyTokenUpdated(collateralToken);

          (* seizeAmount = actualRepayAmount * liquidationIncentive
            * priceBorrowed / priceCollateral
            seizeTokens = seizeAmount / exchangeRate
          *)
          const seizeAmount : nat = liqAmountFloat * s.liqIncentiveFloat
            * borrowToken.lastPrice * collateralToken.totalSupplyFloat;

          const numerator : nat =
            case is_nat(collateralToken.totalLiquidFloat + collateralToken.totalBorrowsFloat
            - collateralToken.totalReservesFloat) of
              | None -> (failwith("underflow/totalLiquidFloat+totalBorrowsFloat") : nat)
              | Some(value) -> value
            end;

          const exchangeRateFloat : nat = numerator * precision * collateralToken.lastPrice;

          const seizeTokensFloat : nat = seizeAmount / exchangeRateFloat;

          var liquidatorAccount : account := getAccount(
            Tezos.sender,
            params.collateralToken,
            s.accountInfo
          );

          var borrowerBalanceInfo : nat := getBalanceByToken(params.borrower, params.collateralToken, s.ledger);

          if borrowerBalanceInfo < seizeTokensFloat
          then failwith("yToken/seize/not-enough-tokens")
          else skip;

          var liquidatorBalanceInfo : nat := getBalanceByToken(Tezos.sender, params.collateralToken, s.ledger);

          borrowerBalanceInfo :=
            case is_nat(borrowerBalanceInfo - seizeTokensFloat) of
              | None -> (failwith("underflow/borrowerBalanceInfo") : nat)
              | Some(value) -> value
            end;

          liquidatorBalanceInfo := liquidatorBalanceInfo + seizeTokensFloat;

          s.ledger[(params.borrower, params.collateralToken)] := borrowerBalanceInfo;
          s.ledger[(Tezos.sender, params.collateralToken)] := liquidatorBalanceInfo;
          s.accountInfo[(params.borrower, params.borrowToken)] := borrowerAccount;
          s.accountInfo[(Tezos.sender, params.collateralToken)] := liquidatorAccount;
          s.tokenInfo[params.collateralToken] := collateralToken;
          s.borrowInfo[params.borrower] := userBorrowedTokens;
        }
      | _                         -> skip
      end
  } with (operations, s)

function enterMarket(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
    case p of
      EnterMarket(tokenId) -> {
        var userAccount : account := getAccount(Tezos.sender, tokenId, s.accountInfo);
        var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);

        if tokenId < s.lastTokenId
        then skip
        else failwith("yToken/yToken-undefined");

        if Set.size(userMarkets) >= s.maxMarkets
        then failwith("yToken/max-market-limit");
        else skip;

        userMarkets := Set.add(tokenId, userMarkets);
        s.markets[Tezos.sender] := userMarkets;
        s.accountInfo[(Tezos.sender, tokenId)] := userAccount;
      }
    | _                         -> skip
    end
  } with (noOperations, s)

function exitMarket(
  const p               : useAction;
  var s                 : tokenStorage)
                        : return is
  block {
      case p of
        ExitMarket(tokenId) -> {
          var userMarkets : set(tokenId) := getTokenIds(Tezos.sender, s.markets);
          var userTokens : set(tokenId) := getTokenIds(Tezos.sender, s.borrowInfo);

          if tokenId < s.lastTokenId
          then skip
          else failwith("yToken/yToken-undefined");

          const token : tokenInfo = getTokenInfo(
            tokenId,
            s.tokenInfo
          );
          verifyTokenUpdated(token);

          userMarkets := Set.remove(tokenId, userMarkets);

          s.accountInfo := applyInterestToBorrows(userTokens, Tezos.sender, s.accountInfo, s.tokenInfo);

          const maxBorrowInCU : nat = calcMaxCollateralInCU(
            userMarkets,
            Tezos.sender,
            s.ledger,
            s.tokenInfo
          );
          const outstandingBorrowInCU : nat = calcOutstandingBorrowInCU(
            getTokenIds(Tezos.sender, s.borrowInfo),
            Tezos.sender,
            s.accountInfo,
            s.ledger,
            s.tokenInfo
          );

          if outstandingBorrowInCU <= maxBorrowInCU
          then s.markets[Tezos.sender] := userMarkets;
          else failwith("yToken/debt-not-repaid");
        }
      | _                         -> skip
      end
  } with (noOperations, s)

function returnPrice(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    if Tezos.sender =/= s.storage.priceFeedProxy
    then failwith("yToken/permition-error");
    else skip;

    var token : tokenInfo := getTokenInfo(
      params.tokenId,
      s.storage.tokenInfo
    );
    token.lastPrice := params.amount;
    token.priceUpdateTime := Tezos.now;
    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)

function accrueInterest(
  const params          : yAssetParams;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    var token : tokenInfo := getTokenInfo(params.tokenId, s.storage.tokenInfo);
    const borrowRate : nat = params.amount;

    if token.isInterestUpdating = False
    then failwith("yToken/interest-update-wrong-state");
    else token.isInterestUpdating := False;

    if Tezos.sender =/= token.interestRateModel
    then failwith("yToken/not-interest-rate-model-address")
    else skip;

    if borrowRate >= token.maxBorrowRate
    then failwith("yToken/borrow-rate-is-absurdly-high");
    else skip;

    //  Calculate the number of blocks elapsed since the last accrual
    const blockDelta : nat =
      case is_nat(Tezos.now - token.interestUpdateTime) of
        | None -> (failwith("underflow/Tezos.now") : nat)
        | Some(value) -> value
      end;

    const simpleInterestFactorFloat : nat = borrowRate * blockDelta;
    const interestAccumulatedFloat : nat = simpleInterestFactorFloat *
      token.totalBorrowsFloat / precision;

    token.totalBorrowsFloat := interestAccumulatedFloat + token.totalBorrowsFloat;
    // one mult operation with float require precision division
    token.totalReservesFloat := interestAccumulatedFloat * token.reserveFactorFloat /
      precision + token.totalReservesFloat;
    // one mult operation with float require precision division
    token.borrowIndex := simpleInterestFactorFloat * token.borrowIndex / precision + token.borrowIndex;
    token.interestUpdateTime := Tezos.now;

    s.storage.tokenInfo[params.tokenId] := token;
  } with (noOperations, s)
