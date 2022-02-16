const { alice, bob, carol } = require("../../scripts/sandbox/accounts");

const { strictEqual } = require("assert");

const { InterestRate } = require("./interestRate");
const { SendRate } = require("./sendRate");
const { Utils } = require("./utils");
const { VIEW_LAMBDA } = require("@taquito/taquito");

const { confirmOperation } = require("../../scripts/confirmation");

describe("Interest tests", () => {
  let tezos;
  let interest;
  let sendRate;
  let lambda;

  before("setup Interest", async () => {
    tezos = await Utils.initTezos();
    interest = await InterestRate.originate(tezos);
    sendRate = await SendRate.originate(tezos);

    interestContractAddress = interest.contract.address;
    sendRateContractAddress = sendRate.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);

    let operation = await tezos.contract.transfer({
      to: carol.pkh,
      amount: 50000000,
      mutez: true,
    });
    await confirmOperation(tezos, operation.hash);

    await sendRate.setInterestRate(interestContractAddress);
    await sendRate.updateStorage();
    strictEqual(sendRate.storage.interestAddress, interestContractAddress);
    const op = await tezos.contract.originate({
      code: VIEW_LAMBDA.code,
      storage: VIEW_LAMBDA.storage,
    });
    await confirmOperation(tezos, op.hash);
    lambda = op.contractAddress;

    // await interest.updateYToken(sendRateContractAddress);
    // await interest.updateStorage();
    // strictEqual(interest.storage.yToken, sendRateContractAddress);
  });

  it("set InterestRate admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await interest.updateAdmin(bob.pkh);
    await interest.updateStorage();
    strictEqual(interest.storage.admin, bob.pkh);
  });

  it("set InterestRate coef", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await interest.setCoefficients(100, 200, 300, 400);
    await interest.updateStorage();

    strictEqual(await interest.storage.kinkF.toString(), "100");
    strictEqual(await interest.storage.baseRateF.toString(), "200");
    strictEqual(await interest.storage.multiplierF.toString(), "300");
    strictEqual(await interest.storage.jumpMultiplierF.toString(), "400");
  });

  it("send UtilizationRate", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    const precision = "1000000";
    var borrows = "100";
    var cash = "100000";
    var reserves = "10";
    var numerator = (cash + borrows - reserves) / borrows;
    const res = await interest.contract.views
      .getUtilizationRate([
        {
          tokenId: "0",
          borrowsF: borrows * precision,
          cashF: cash * precision,
          reservesF: reserves * precision,
          precision: precision,
          reserveFactorF: 1 * precision,
        },
      ])
      .read(lambda.toString());
    console.log(res)
    // await sendRate.sendUtil(0, borrows, cash, reserves);
    // await sendRate.updateStorage();

    strictEqual(
      res.amount.toString(),
      Math.floor(numerator).toString()
    );
  });

  it("send BorrowRate", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    var borrows = 100;
    var cash = 100000;
    var reserves = 10;

    var formula = 100 * 300 + 200 + (1000 - 100) * 400;

    await sendRate.sendBorrow(0, borrows, cash, reserves);
    await sendRate.updateStorage();

    strictEqual(
      await sendRate.storage.borrowRate.toString(),
      formula.toString()
    );
  });

  it("send SupplyRate", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    var borrows = 100;
    var cash = 100000;
    var reserves = 10;

    var borrowFormula = 100 * 300 + 200 + (1000 - 100) * 400;
    var utilFormula = (cash + borrows - reserves) / borrows;
    var formula =
      borrowFormula * Math.floor(utilFormula) * (1000000000000000000 - 250);

    await sendRate.sendSupply(0, borrows, cash, reserves);
    await sendRate.updateStorage();

    strictEqual(
      await Math.floor(sendRate.storage.supplyRate).toString(),
      Math.floor(formula).toString()
    );
  });
});
