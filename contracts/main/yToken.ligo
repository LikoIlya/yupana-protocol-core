#include "../partial/MainTypes.ligo"
#include "../partial/yToken/LendingMethods.ligo"

function middleToken(
  const p               : tokenAction;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
    const idx : nat = case p of
      | ITransfer(_transferParams) -> 0n
      | IUpdateOperators(_updateOperatorParams) -> 1n
      | IBalanceOf(_balanceParams) -> 2n
      | IGetTotalSupply(_totalSupplyParams) -> 3n
    end;
    const res : return = case s.tokenLambdas[idx] of
      Some(f) -> f(p, s.storage)
      | None -> (
        failwith("yToken/middle-token-function-not-set") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

[@inline] function middleUse(
  const p               : useAction;
  var s                 : fullTokenStorage)
                        : fullReturn is
  block {
      const idx : nat = case p of
        | Mint(_mainParams) -> 0n
        | Redeem(_mainParams) -> 1n
        | Borrow(_mainParams) -> 2n
        | Repay(_mainParams) -> 4n
        | Liquidate(_liquidateParams) -> 5n
        | EnterMarket(_tokenId) -> 7n
        | ExitMarket(_tokenId) -> 8n
      end;
    const res : return = case s.useLambdas[idx] of
      Some(f) -> f(p, s.storage)
      | None -> (
        failwith("yToken/middle-function-not-set-in-middleUse") : return
      )
    end;
    s.storage := res.1;
  } with (res.0, s)

function main(
  const p               : entryAction;
  const s               : fullTokenStorage)
                        : fullReturn is
  case p of
    | Transfer(params)          -> middleToken(ITransfer(params), s)
    | UpdateOperators(params)   -> middleToken(IUpdateOperators(params), s)
    | BalanceOf(params)         -> middleToken(IBalanceOf(params), s)
    | GetTotalSupply(params)    -> middleToken(IGetTotalSupply(params), s)
    | UpdateInterest(params)   -> updateInterest(params, s)
    | EnsuredUpdateInterest(params) -> ensuredUpdateInterest(params, s)
    | UpdateBorrowRate(params) -> updateBorrowRate(params, s)
    | GetReserveFactor(params) -> getReserveFactor(params, s)
    | UpdatePrice(params) -> updatePrice(params, s)
    | SetAdmin(params) -> setAdmin(params, s)
    | WithdrawReserve(params) -> withdrawReserve(params, s)
    | AddMarket(params) -> addMarket(params, s)
    | SetTokenFactors(params) -> setTokenFactors(params, s)
    | SetGlobalFactors(params) -> setGlobalFactors(params, s)
    | Use(params)               -> middleUse(params, s)
  end