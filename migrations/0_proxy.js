const { dev, alice } = require("../scripts/sandbox/accounts");
const { migrate } = require("../scripts/helpers");
const { MichelsonMap } = require("@taquito/michelson-encoder");
const { confirmOperation } = require("../scripts/confirmation");
const { InMemorySigner } = require("@taquito/signer");
const oracle = "KT1KBrn1udLLrGNbQ3n1mWgMVXkr26krj6Nj";

module.exports = async (tezos) => {
  const contractAddress = await migrate(tezos, "priceFeed", {
    admin: dev.pkh,
    oracle: oracle,
    yToken: alice.pkh,
    pairName: MichelsonMap.fromLiteral({}),
    pairId: MichelsonMap.fromLiteral({}),
    tokensDecimals: MichelsonMap.fromLiteral({}),
  });

  console.log(`Proxy contract: ${contractAddress}`);
  let contract = await tezos.contract.at(contractAddress);

  tezos.setProvider({
    signer: await InMemorySigner.fromSecretKey(dev.sk),
  });

  let op = await contract.methods
    .updatePair(0, "XTZ-USD", Math.pow(10, 6))
    .send();

  await confirmOperation(tezos, op.hash);

  op = await contract.methods.updatePair(1, "BTC-USD", Math.pow(10, 8)).send();
  await confirmOperation(tezos, op.hash);
};
