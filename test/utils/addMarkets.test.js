const { MichelsonMap } = require("@taquito/michelson-encoder");

const {
  alice,
  bob,
  carol,
  peter,
  dev,
  dev2,
} = require("../../scripts/sandbox/accounts");

const { strictEqual, rejects, ok } = require("assert");

const { Proxy } = require("./proxy");
const { InterestRate } = require("./interestRate");
const { GetOracle } = require("./getOracle");
const { YToken } = require("./yToken");
const { FA12 } = require("./fa12");
const { FA2 } = require("./fa2");
const { Utils } = require("./utils");

// const tokenMetadatas = [
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST0").toString("hex"),
//     name: Buffer.from("TEST0").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST1").toString("hex"),
//     name: Buffer.from("TEST1").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST2").toString("hex"),
//     name: Buffer.from("TEST2").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST3").toString("hex"),
//     name: Buffer.from("TEST3").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST4").toString("hex"),
//     name: Buffer.from("TEST4").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST5").toString("hex"),
//     name: Buffer.from("TEST5").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST6").toString("hex"),
//     name: Buffer.from("TEST6").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST7").toString("hex"),
//     name: Buffer.from("TEST7").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST8").toString("hex"),
//     name: Buffer.from("TEST8").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST9").toString("hex"),
//     name: Buffer.from("TEST9").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST10").toString("hex"),
//     name: Buffer.from("TEST10").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST11").toString("hex"),
//     name: Buffer.from("TEST11").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST12").toString("hex"),
//     name: Buffer.from("TEST12").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST13").toString("hex"),
//     name: Buffer.from("TEST13").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST14").toString("hex"),
//     name: Buffer.from("TEST14").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST15").toString("hex"),
//     name: Buffer.from("TEST15").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST16").toString("hex"),
//     name: Buffer.from("TEST16").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST17").toString("hex"),
//     name: Buffer.from("TEST17").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST18").toString("hex"),
//     name: Buffer.from("TEST18").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST19").toString("hex"),
//     name: Buffer.from("TEST19").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST20").toString("hex"),
//     name: Buffer.from("TEST20").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
//   MichelsonMap.fromLiteral({
//     symbol: Buffer.from("TST21").toString("hex"),
//     name: Buffer.from("TEST21").toString("hex"),
//     decimals: Buffer.from("6").toString("hex"),
//     icon: Buffer.from("").toString("hex"),
//   }),
// ];

const pairs = [
  "COMP-USD",
  "COMP-XTZ",
  "COMP-BTC",
  "COMP-ETH",
  "XTZ-USD",
  "XTZ-ETH",
  "XTZ-BTC",
  "ETH-USD",
  "ETH-BTC",
  "BTC-USD",
  "AAA-USD",
  "AAA-XTZ",
  "AAA-BTC",
  "AAA-COMP",
  "AAA-BBB",
  "BBB-XTZ",
  "BBB-BTC",
  "BBB-ETH",
  "BBB-COMP",
  "CCC-USD",
  "CCC-XTZ",
  "BBB-CCC",
];

describe("AddMarkets tests", () => {
  let tezos;
  let yToken;
  let proxy;
  let oracle;

  let markets = [];

  let fa12s = [];
  let fa12ContractAddresses = [];

  let interests = [];
  let interestContractAddresses = [];

  let yTokenContractAddress;
  let proxyContractAddress;
  let oracleContractAddress;

  before("setup Proxy", async () => {
    tezos = await Utils.initTezos();
    yToken = await YToken.originate(tezos);
    for (let i = 0; i < 22; i++) {
      const interest = await InterestRate.originate(tezos);
      const fa12 = await FA12.originate(tezos);
      fa12s.push(fa12);
      fa12ContractAddresses.push(fa12.contract.address);
      if (i % 2 == 0) {
        await interest.setCoefficients(
          800000000000000000,
          634195839,
          7134703196,
          31709791983
        );
        await interest.updateStorage();
      } else {
        await interest.setCoefficients(
          800000000000000000,
          0,
          1585489599,
          34563673262
        );
      }
      await interest.updateStorage();
      interests.push(interest);
      interestContractAddresses.push(interest.contract.address);
      markets.push({
        fa12,
        fa12ContractAddress: fa12.contract.address,
        interest,
        interestContractAddress: interest.contract.address,
        pair: pairs[i],
        metadata: MichelsonMap.fromLiteral({
          symbol: Buffer.from(`TST${i}`).toString("hex"),
          name: Buffer.from(`TEST${i}`).toString("hex"),
          decimals: Buffer.from("6").toString("hex"),
          icon: Buffer.from("").toString("hex"),
        }),
      });
    }

    proxy = await Proxy.originate(tezos);
    oracle = await GetOracle.originate(tezos);

    yTokenContractAddress = yToken.contract.address;

    proxyContractAddress = proxy.contract.address;
    oracleContractAddress = oracle.contract.address;

    tezos = await Utils.setProvider(tezos, alice.sk);
    await Utils.trasferTo(tezos, carol.pkh, 50000000);
    await Utils.trasferTo(tezos, peter.pkh, 50000000);
    await Utils.trasferTo(tezos, dev.pkh, 50000000);
    await Utils.trasferTo(tezos, dev2.pkh, 50000000);

    await proxy.updateOracle(oracleContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.oracle, oracleContractAddress);

    await proxy.updateYToken(yTokenContractAddress);
    await proxy.updateStorage();
    strictEqual(proxy.storage.yToken, yTokenContractAddress);

    await yToken.setGlobalFactors(
      "500000000000000000",
      "1050000000000000000",
      proxyContractAddress,
      "2"
    );
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.priceFeedProxy, proxyContractAddress);
  });

  it("set proxy admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await proxy.updateAdmin(bob.pkh);
    await proxy.updateStorage();
    strictEqual(proxy.storage.admin, bob.pkh);
  });

  it("set yToken admin by admin", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await yToken.setAdmin(bob.pkh);
    await yToken.updateStorage();
    strictEqual(yToken.storage.storage.admin, bob.pkh);
  });
  it("Add 22 Markets tests", async () => {
    console.log(markets);
    const tests = markets.reduce((tests, market, index) => {
      tests.push(async () => {
        console.log(`add market ${index} (${market.pair})`)
        tezos = await Utils.setProvider(tezos, bob.sk);
        const params =
          index == 0
            ? [650000000000000000, 200000000000000000, 5000000000000]
            : [750000000000000000, 150000000000000000, 5000000000000];
        await yToken.addMarket(
          market.interestContractAddress,
          "fA12",
          market.fa12ContractAddress,
          0,
          ...params,
          market.metadata,
          500000000000000000
        );
        await yToken.updateStorage();

        await proxy.updatePair(index, market.pair);
        await proxy.updateStorage();
        strictEqual(await proxy.storage.pairName.get(index), market.pair);

        let pairId = await proxy.storage.pairId.get(market.pair);
        console.log(pairId);
        strictEqual(pairId.toNumber(), index);
      });
      return tests;
    }, []);
    await Promise.all(tests);
  });
  it("mint fa12[0] tokens by bob and peter", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await markets[0].fa12.mint(10000000000000000000);
    await markets[0].fa12.updateStorage();

    let res = await markets[0].fa12.storage.ledger.get(bob.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, peter.sk);
    await markets[0].fa12.mint(10000000000000000000);
    await markets[0].fa12.updateStorage();

    res = await markets[0].fa12.storage.ledger.get(peter.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint fa12[1] by alice and carol", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await markets[1].fa12.mint(10000000000000000000);
    await markets[1].fa12.updateStorage();

    res = await markets[1].fa12.storage.ledger.get(alice.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");

    tezos = await Utils.setProvider(tezos, carol.sk);
    await markets[1].fa12.mint(10000000000000000000);
    await markets[1].fa12.updateStorage();

    res = await markets[1].fa12.storage.ledger.get(carol.pkh);

    strictEqual(await res.balance.toString(), "10000000000000000000");
  });

  it("mint yTokens by alice", async () => {
    tezos = await Utils.setProvider(tezos, alice.sk);
    await markets[1].fa12.approve(yTokenContractAddress, 100000000000);
    await markets[1].fa12.updateStorage();

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let res = await markets[1].fa12.storage.ledger.get(alice.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([alice.pkh, 1]);

    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await markets[1].fa12.approve(yTokenContractAddress, 100000000000);
    await markets[1].fa12.updateStorage();

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let res = await markets[1].fa12.storage.ledger.get(carol.pkh);
    strictEqual(await res.balance.toString(), "9999999990000000000");

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    let ytokens = await yToken.storage.storage.tokens.get("1");
    console.log(ytokens.lastPrice.toString());

    strictEqual(
      await yTokenRes.toPrecision(40).split(".")[0],
      "10000000000000000000000000000"
    );
  });

  it("mint yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await markets[0].fa12.approve(yTokenContractAddress, 100000000000);
    await markets[0].fa12.updateStorage();

    await yToken.updateAndMint2(proxy, 0, 100000);
    await yToken.updateStorage();

    let res = await markets[0].fa12.storage.ledger.get(bob.pkh);
    strictEqual(await res.balance.toString(), "9999999999999900000");

    let yTokenRes = await yToken.storage.storage.ledger.get([bob.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "100000000000000000000000"
    );
  });

  it("mint yTokens by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);
    await markets[0].fa12.approve(yTokenContractAddress, 100000000000);
    await markets[0].fa12.updateStorage();

    await yToken.updateAndMint2(proxy, 0, 1000);
    await yToken.updateStorage();

    let res = await markets[0].fa12.storage.ledger.get(peter.pkh);
    strictEqual(await res.balance.toString(), "9999999999999999000");

    let yTokenRes = await yToken.storage.storage.ledger.get([peter.pkh, 0]);
    strictEqual(
      yTokenRes.toPrecision(40).split(".")[0],
      "1000000000000000000000"
    );
  });

  it("enterMarket [0] by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(res.toString(), "0");
  });

  it("enterMarket [0] by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);

    await yToken.enterMarket(0);
    await yToken.updateStorage();
    res = await yToken.storage.storage.markets.get(peter.pkh);
    strictEqual(res.toString(), "0");
  });

  it("borrow yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await yToken.updateAndBorrow(proxy, 1, 50000);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    strictEqual(
      res.borrow.toPrecision(40).split(".")[0],
      "50000000000000000000000"
    );
  });

  it("borrow yTokens by bob (2)", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);
    await Utils.bakeBlocks(tezos, 7);

    await yToken.updateAndBorrow(proxy, 1, 1000);
    await yToken.updateStorage();

    let res = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(res.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("redeem 0 by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);
    await yToken.updateAndRedeem(proxy, 1, 0);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]);
  });

  it("mint yTokens by carol", async () => {
    tezos = await Utils.setProvider(tezos, carol.sk);

    await yToken.updateAndMint(proxy, 1, 10000000000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.ledger.get([carol.pkh, 1]);
    console.log(yTokenRes.toPrecision(40).split(".")[0]);
  });

  it("borrow yTokens by peter", async () => {
    tezos = await Utils.setProvider(tezos, peter.sk);
    await yToken.updateAndBorrow(proxy, 1, 500);
    await yToken.updateStorage();

    res = await yToken.storage.storage.accounts.get([peter.pkh, 1]);

    strictEqual(
      res.borrow.toPrecision(40).split(".")[0],
      "500000000000000000000"
    );
  });

  it("repay yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await markets[1].fa12.approve(yTokenContractAddress, 100000);
    await markets[1].fa12.updateStorage();

    await yToken.updateAndRepay(proxy, 1, 40000);
    await yToken.updateStorage();

    let yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(yTokenRes.borrow.toPrecision(40).split(".")[0]); // not static result
  });

  it("repay 5 yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    await markets[2].fa12.mint(10000);
    await markets[2].fa12.updateStorage();

    let res = await markets[2].fa12.storage.ledger.get(bob.pkh);
    console.log(await res.balance.toString()); // not static result

    let yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    console.log(yTokenRes.borrow.toPrecision(40).split(".")[0]); // not static result

    await yToken.updateAndRepay(proxy, 1, 0);
    await yToken.updateStorage();

    yTokenRes = await yToken.storage.storage.accounts.get([bob.pkh, 1]);
    strictEqual(yTokenRes.borrow.toString(), "0");
  });

  it("exit market yTokens by bob", async () => {
    tezos = await Utils.setProvider(tezos, bob.sk);

    let res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(await res.toString(), "0");

    await yToken.updateAndExit(proxy, 0);
    await yToken.updateStorage();

    res = await yToken.storage.storage.markets.get(bob.pkh);
    strictEqual(await res.toString(), "");
  });
});
